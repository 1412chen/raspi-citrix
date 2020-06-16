#!/bin/bash

while true
do
  if [ -f ~/.config/chromium/Default/Preferences ]; then
    echo "found"
    sed -i 's/\"download\":{[^{]*},//' ~/.config/chromium/Default/Preferences
    sed -i 's/}$/,\"download\":{\"directory_upgrade\":true,\"extensions_to_open\":\"ica\"}}/' ~/.config/chromium/Default/Preferences
    sed -i 's/.*first_time_login_desktop.sh//' ~/.icewm/startup
    rm ~/first_time_login_desktop.sh
    break
  fi
done


