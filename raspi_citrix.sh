#!/bin/bash

USER=user
GROUP=user
PASSWD=raspberry
CITRIXSTOREFRONT=https://your.citrix.FQDN
CITRIXCERTFILE=yourca.pem
HDMIGROUP=2
HDMIMODE=28

HOME=/home/$USER

# boot environment
sed -i "/#hdmi_force_hotplug/c\hdmi_force_hotplug=1" /boot/config.txt
sed -i "/#hdmi_group/c\hdmi_group=$HDMIGROUP" /boot/config.txt
sed -i "/#hdmi_mode/c\hdmi_mode=$HDMIMODE" /boot/config.txt
echo "disable_splash=1
avoid_warnings=1" >> /boot/config.txt
sed -i "s/console=tty1/console=tty6/" /boot/cmdline.txt
sed -i "/^/s/$/ loglevel=3 quiet logo.nologo vt.global_cursor_default=0/" /boot/cmdline.txt

# update
apt-get update
apt-get -y dist-upgrade

# install packages
apt-get install -y --no-install-recommends xserver-xorg xinit icewm lightdm x11-xserver-utils
apt-get install -y --no-install-recommends chromium-browser numlockx fonts-wqy-microhei xfonts-wqy xterm
apt-get install -y pcsc-tools pcscd

# install Citrix ICA
dpkg -i *.deb
apt-get install -y -f --no-install-recommends

apt-get auto-remove -y
apt-get clean

# create user and disable pi
groupadd $GROUP
useradd $USER -g $GROUP
usermod -a -G adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi $USER
echo $USER:$PASSWD | chpasswd
mkdir $HOME
chown $USER:$GROUP $HOME
userdel pi
chmod +x first_time_login_desktop.sh
cp first_time_login_desktop.sh $HOME
chown $USER:$GROUP $HOME/*

# setting environment
## icewm environment
mkdir -p $HOME/.icewm
chown $USER:$GROUP $HOME/.icewm
echo "WorkspaceNames=\" 1 \"
ShowTaskBar=0
ShowSettingsMenu=0
ShowFocusModeMenu=0
ShowThemesMenu=0
ShowProgramsMenu=0
ShowHelp=0
ShowAbout=0
ShowRun=0
ShowLogoutMenu=0
ShowWindowList=0" > $HOME/.icewm/preferences
echo "#!/bin/bash
xset s off
xset -dpms
xmodmap ~/.Xmodmap
rm ~/Downloads/*.ica
chromium-browser ${CITRIXSTOREFRONT}
¬/first_time_login_desktop.sh" > $HOME/.icewm/startup
echo "Theme=\"icedesert/default.theme\"" > $HOME/.icewm/theme
echo "" > $HOME/.icewm/menu
echo "key \"Alt+Ctrl+t\"   x-terminal-emulator" > $HOME/.icewm/keys
chown $USER:$GROUP $HOME/.icewm/preferences
chown $USER:$GROUP $HOME/.icewm/theme
chown $USER:$GROUP $HOME/.icewm/menu
chown $USER:$GROUP $HOME/.icewm/startup
chmod +x $HOME/.icewm/startup
chown $USER:$GROUP $HOME/.icewm/keys

## chromium environment
echo "CHROMIUM_FLAGS=\"\${CHROMIUM_FLAGS} --kiosk --incognito --check-for-update-interval=604800\"" >> /etc/chromium-browser/customizations/01-customize-settings
echo "{
  \"TranslateEnable\":false
}" > /etc/chromium-browser/policies/managed/no-translate.json

## chromium ca
if [ -f "./${CITRIXCERTFILE}" ]; then
  cp ${CITRIXCERTFILE} /opt/Citrix/ICAClient/keystore/cacerts/
fi

## keyboard short key
echo "keycode 67 = F1 F1 F1 F1 F1 F1
keycode 68 = F2 F2 F2 F2 F2 F2
keycode 69 = F3 F3 F3 F3 F3 F3
keycode 70 = F4 F4 F4 F4 F4 F4
keycode 71 = F5 F5 F5 F5 F5 F5
keycode 72 = F6 F6 F6 F6 F6 F6
keycode 73 = F7 F7 F7 F7 F7 F7
keycode 74 = F8 F8 F8 F8 F8 F8
keycode 75 = F9 F9 F9 F9 F9 F9
keycode 76 = F10 F10 F10 F10 F10 F10
keycode 95 = F11 F11 F11 F11 F11 F11
keycode 96 = F12 F12 F12 F12 F12 F12" > $HOME/.Xmodmap
chown $USER:$GROUP $HOME/.Xmodmap

## sudoer
rm /etc/sudoers.d/010_pi-nopasswd

## auto login
systemctl set-default graphical.target
ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
echo "[Service]
ExecStart=
ExecStart=-/sbin/agetty --skip-login --noclear --noissue --login-options "-f $USER" %I \$TERM" > /etc/systemd/system/getty\@tty1.service.d/autologin.conf
sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)autologin-user=.*/autologin-user=$USER/"

## smart card service
systemctl enable pcscd

# prepare for next boot
if [ $USER != "pi" ]; then
  cp first_time_login_desktop.sh 
fi

# finalize
if [ $USER != pi ]; then 
  cp first_login_desktop.sh 
  rm -rf /home/pi
fi
reboot


# unfinish
#apt-get install ufw fail2ban
