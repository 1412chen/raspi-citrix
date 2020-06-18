#!/bin/bash

USER=user
GROUP=user
PASSWD=raspberry
CITRIXSTOREFRONT=https://your.citrix.FQDN
CITRIXCERTFILE=yourCA.pem
HDMIGROUP=2
HDMIMODE=28
TIMEZONE=Asia/Taipei
NTPServer=

###################################################
# scsript environment
HOME=/home/$USER
debCount=`ls -1 *.deb 2>/dev/null | wc -l`
if [ $debCount == 0 ]; then
  echo "check Workspace App install file exist"
  exit 1
fi
if [ "$USER" == "pi" ]; then
  GROUP=pi
fi
###################################################

# update
apt-get update
DONE=1
UPDATE_TIMES=0
while (( $DONE != 0 ))
do
  apt-get -y dist-upgrade
  DONE=$(echo $?)
  UPDATE_TIMES=$((UPDATE_TIMES+1))
  if (( $UPDATE_TIMES > 9 )); then
    echo "check newtwork"
    exit 1
  fi
done

# install packages
PACKAGES=(xserver-xorg xinit icewm lightdm x11-xserver-utils chromium-browser numlockx fonts-wqy-microhei xfonts-wqy xterm pcsc-tools pcscd fail2ban)
DONE=0
UPDATE_TIMES=0
while (( $DONE != ${#PACKAGES[@]} ))
do
  apt-get install -y --no-install-recommends $(echo "${PACKAGES[*]}")
  DONE=0
  for PACKAGE in ${PACKAGES[*]}; do
    STATE=$(dpkg-query -W -f='${Status}' ${PACKAGE} 2>/dev/null | grep -c "ok installed") 
    DONE=$((DONE + STATE))
  done
  UPDATE_TIMES=$((UPDATE_TIMES+1))
  if (( $UPDATE_TIMES > 9 )); then
    echo "check network"
    exit 1
  fi
done

# install Citrix ICA
dpkg -i *.deb
DONE=1
UPDATE_TIMES=0
while (( $DONE != 0 ))
do
  apt-get install -y -f --no-install-recommends
  DONE=$(echo $?)
  UPDATE_TIMES=$((UPDATE_TIMES+1))
  if (( $UPDATE_TIMES > 10 )); then
    echo "check network"
    exit 1
  fi 
done

apt-get auto-remove -y
apt-get clean

# create user and disable pi
if [ "$USER" != "pi" ]; then
  groupadd $GROUP
  useradd $USER -g $GROUP
  usermod -a -G adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi $USER
  mkdir $HOME
  chown $USER:$GROUP $HOME
fi
echo $USER:$PASSWD | chpasswd

# setting environment
## boot environment
sed -i "/[# ]*hdmi_force_hotplug/c\hdmi_force_hotplug=1" /boot/config.txt
sed -i "/[# ]*hdmi_group/c\hdmi_group=$HDMIGROUP" /boot/config.txt
sed -i "/[# ]*hdmi_mode/c\hdmi_mode=$HDMIMODE" /boot/config.txt
sed -i "/[# ]*disable_splash=./d" /boot/config.txt
sed -i "/[# ]*avoid_warnings=./d" /boot/config.txt
cat >> /boot/config.txt << EOF
disable_splash=1
avoid_warnings=1
EOF
sed -i "s/console=tty1/console=tty6/" /boot/cmdline.txt
sed -i "s/ loglevel=.//g" /boot/cmdline.txt
sed -i "s/ quiet//g" /boot/cmdline.txt
sed -i "s/ logo.nologo//g" /boot/cmdline.txt
sed -i "s/ vt.global_cursor_default=.//g" /boot/cmdline.txt
sed -i "/^/s/$/ loglevel=3 quiet logo.nologo vt.global_cursor_default=0/" /boot/cmdline.txt

## NTP server
if [ "${NTPServer}" != "" ]; then
  sed -i "/[#]NTP=/c\NTP=${NTPServer}" /etc/systemd/timesyncd.conf
fi

## keyboard
cat > /etc/default/keyboard << EOF
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

## timezone
if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
  rm /etc/localtime
  echo "$TIMEZONE" > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata
fi

## icewm environment
mkdir -p $HOME/.icewm
chown $USER:$GROUP $HOME/.icewm
cat > $HOME/.icewm/preferences << EOF
WorkspaceNames=" 1 "
ShowTaskBar=0
ShowSettingsMenu=0
ShowFocusModeMenu=0
ShowThemesMenu=0
ShowProgramsMenu=0
ShowHelp=0
ShowAbout=0
ShowRun=0
ShowLogoutMenu=0
ShowWindowList=0
EOF
cat > $HOME/.icewm/startup << EOF
#!/bin/bash
xset s off
xset -dpms
xmodmap ~/.Xmodmap
rm ~/Downloads/*.ica
~/first_time_login_desktop.sh
chromium-browser ${CITRIXSTOREFRONT}
EOF
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
cat > /etc/chromium-browser/policies/managed/no-translate.json << EOF
{
  "TranslateEnabled":false
}
EOF

## citrix ca
if [ -f "./${CITRIXCERTFILE}" ]; then
  cp ${CITRIXCERTFILE} /opt/Citrix/ICAClient/keystore/cacerts/
fi

## citrix ica env
sed -i "/^MultiMedia=/c\MultiMedia=On" /opt/Citrix/ICAClient/config/module.ini
tar zxf icaclient.tgz -C $HOME/.ICAClient
#LINK=$(awk '/WFClient/{ print NR; exit }' $HOME/.ICAClient/wfclient.ini)
#sed -i "$((LINE+1))iEnableAudioInput=True" $HOME/.ICAClient/wfclient.ini
#sed -i "$((LINE+2))iAllowAudioInput=True" $HOME/.ICAClient/wfclient.ini

## keyboard short key
cat >  $HOME/.Xmodmap << EOF
keycode 67 = F1 F1 F1 F1 F1 F1
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
keycode 96 = F12 F12 F12 F12 F12 F12
EOF
chown $USER:$GROUP $HOME/.Xmodmap

## sudoer
rm /etc/sudoers.d/010_pi-nopasswd

## auto login
systemctl set-default graphical.target
ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
cat > /etc/systemd/system/getty\@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --skip-login --noclear --noissue --login-options "-f $USER" %I \$TERM
EOF
sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)autologin-user=.*/autologin-user=$USER/"

## smart card service
systemctl enable pcscd

# finalize, prepare for next boot
chmod +x first_time_login_desktop.sh
if [ $(echo '${PWD}') != $HOME ]; then
  mv first_time_login_desktop.sh $HOME
fi
chown $USER:$GROUP $HOME/*
rm *.deb
rm raspi_citrix.sh
rm $CITRIXCERTFILE
if [ "$USER" != "pi" ]; then
  pkill -KILL -u pi && deluser --remove-home -f pi
fi
reboot


# unfinish
#apt-get install ufw
#chromium CA
