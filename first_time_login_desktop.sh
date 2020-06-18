#!/bin/bash

chromium-browser &
sleep 2
pkill -f chromium-browser
sleep 2
if [ -f ~/.config/chromium/Default/Preferences ]; then
  sed -i 's/\"download\":{[^{]*},//' ~/.config/chromium/Default/Preferences
  sed -i 's/}$/,\"download\":{\"directory_upgrade\":true,\"extensions_to_open\":\"ica\"}}/' ~/.config/chromium/Default/Preferences
  sed -i '/.*first_time_login_desktop.sh/d' ~/.icewm/startup
  rm ~/first_time_login_desktop.sh
fi

