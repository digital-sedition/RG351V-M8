#!/bin/bash

# Modified from multiple files within https://github.com/jasonporritt/rg351_m8c
# Also uses https://github.com/stevelittlefish/auto_midi_connect

set -e



# Check for root/sudo...
tRoot=$(id -u)
if [ "$tRoot" == "0" ]; then
  echo "DO NOT RUN THIS AS ROOT/SUDO!"
  exit 1
fi

sudo chmod 666 /dev/tty1
echo "== PREPARING TO START M8C" | tee /dev/tty1

#
# Is the current user in the dialout group - used by libserialport and required by m8c - if not, add them but warn them.
if id -nG "$USER" | grep -qw "dialout"; then
    echo "-- NOT OUR FIRST RODEO: USER ALREADY ADDED TO DIALOUT" | tee /dev/tty1
else
	echo "-- USER NOT PART OF DIALOUT, AND WILL BE ADDED NOW" | tee /dev/tty1
	echo "-- IF M8C DOESN'T START, YOU NEED TO REBOOT FOR IT TO APPLY" | tee /dev/tty1
	sudo adduser $USER dialout
fi

#
# Can we find ourselves?
vPTH=""
[[ -d "/roms2/ports/RG351V-M8" ]] && vPTH="/roms2/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms2"
[[ -d "/roms/ports/RG351V-M8" ]] && vPTH="/roms/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms"
[[ -z "$vPTH" ]] && echo "!! RG351V-M8 doesn't appear to be where it should? (should be in [/roms/ports/] || [/roms2/ports/])" && exit 1

#
# Has our humble repo user slapped in a pre-/post-hook?
[[ -e "$vPTH/M8-START.PRE.sh" ]] && vW8T=1 && vPRE=1
[[ -e "$vPTH/M8-START.PST.sh" ]] && vW8T=1 && vPST=1
[[ "$vW8T" -eq 1 ]] && echo "** YO CHUCK! WE GOT HOOKS IN HERE. ...WICKED?" | tee /dev/tty1 && sleep 2

#
# Disable wiffy if enabled, and set CPU governor to "performance" (if not already) to help minimize audio crackles...
sudo modprobe -r mt7601u
sudo sed -i '$ablacklist mt7601u' /etc/modprobe.d/blacklist.conf
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

#
# Utilise auto_midi_connect to connect_midi_automatically...
sudo python3 $vPTH/M8-START.midi_connect.py
echo "-- aconnect found the following devices, FYI:" | tee /dev/tty1
/bin/aconnect -ol > /dev/tty1
sleep 1

#
# No kiss kiss; no bang bang.
[[ "$vPRE" -eq 1 ]] && echo "-- RUNNING PRE-HOOK" | tee /dev/tty1 && $vPTH/M8-START.PRE.sh

#
# Here's a bit of re-engineered but-absolutely-solid-in-principle rg351_m8c 'find the M8' logic:
# This runs a script in the background to try and 'catch' the M8's output audio before m8c starts...
$vPTH/M8-START.alsaloop &
$vPTH/m8c/m8c

#
# Isn't there a thought repeating in that barbaric brain of yours?  DON'TCHUHAVESOMEONETOKILL.
[[ "$vPST" -eq 1 ]] && echo "-- RUNNING POST-HOOK" | tee /dev/tty1 && $vPTH/M8-START.PST.sh

#
# 3...2...1...now you're back in the room...
pkill alsaloop
aconnect -x
sudo modprobe -i mt7601u
sudo sed -i '/blacklist mt7601u/d' /etc/modprobe.d/blacklist.conf
sleep 2
printf "\033c" >> /dev/tty1
