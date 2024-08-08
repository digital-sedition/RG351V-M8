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
echo "## M8C O'CLOCK, SONNY!" | tee /dev/tty1



# Can we find ourselves?
vPTH=""
[[ -d "/roms2/ports/RG351V-M8" ]] && vPTH="/roms2/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms2" | tee /dev/tty1
[[ -d "/roms/ports/RG351V-M8" ]] && vPTH="/roms/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms" | tee /dev/tty1
[[ -z "$vPTH" ]] && echo "!! RG351V-M8 doesn't appear to be where it should? (should be in [/roms/ports/] || [/roms2/ports/])" | tee /dev/tty1 && sleep 4 && exit 1
[[ ! -e "$vPTH/m8c/m8c" ]] && echo "!! Can't find m8c?  Have you built it?" | tee /dev/tty1 && sleep 4 && exit 1



# Is the current user in the dialout group - used by libserialport and required by m8c - if not, add them but warn them.
if id -nG "$USER" | grep -qw "dialout"; then
    echo "-- NOT OUR FIRST RODEO: USER ALREADY ADDED TO DIALOUT" | tee /dev/tty1
else
	echo "-- USER NOT PART OF DIALOUT, AND WILL BE ADDED NOW" | tee /dev/tty1
	echo "   IF M8C DOESN'T START, YOU NEED TO REBOOT FOR IT TO APPLY" | tee /dev/tty1
	echo "" | tee /dev/tty1
	sudo adduser $USER dialout
	sleep 4
fi



# Has our humble repo user slapped in a pre-/post-hook?
[[ -e "$vPTH/M8-START.PRE.sh" ]] && vW8T=1 && vPRE=1
[[ -e "$vPTH/M8-START.PST.sh" ]] && vW8T=1 && vPST=1
[[ "$vW8T" -eq 1 ]] && echo "** YO CHUCK! WE GOT HOOKS IN HERE. ...WICKED?" | tee /dev/tty1 && sleep 2



# Disable wiffy if enabled, and set CPU governor to "performance" (if not already) to help minimize audio crackles...
echo "" | tee /dev/tty1
echo ">> Twiddling stuff..." | tee /dev/tty1
echo "   Disabling wiffy..." | tee /dev/tty1
sudo modprobe -r mt7601u
sudo sed -i '$ablacklist mt7601u' /etc/modprobe.d/blacklist.conf
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor



# Utilise auto_midi_connect to connect_midi_automatically...
echo "   Finding MIDI devices..." | tee /dev/tty1
sudo python3 $vPTH/M8-START.midi_connect.py
/bin/aconnect -ol > /dev/tty1
sleep 1



# No kiss kiss; no bang bang.
[[ "$vPRE" -eq 1 ]] && echo "-- RUNNING PRE-HOOK" | tee /dev/tty1 && $vPTH/M8-START.PRE.sh

# Here's a bit of re-engineered but-absolutely-solid-in-principle rg351_m8c 'find the M8' logic:
# This runs a script in the background to try and 'catch' the M8's output audio before m8c starts...
echo "" | tee /dev/tty1
echo ">> It's m8c time!" | tee /dev/tty1
echo "   ALSA-linking the M8's output to the RG351V's audio..." | tee /dev/tty1
$vPTH/M8-START.alsaloop &
echo "   Starting m8c..." | tee /dev/tty1
$vPTH/m8c/m8c

# Isn't there a thought repeating in that barbaric brain of yours?  DON'TCHUHAVESOMEONETOKILL.
[[ "$vPST" -eq 1 ]] && echo "-- RUNNING POST-HOOK" | tee /dev/tty1 && $vPTH/M8-START.PST.sh



# 3...2...1...now you're back in the room...
echo "" | tee /dev/tty1
echo ">> Hope you made sum'ert good, eh." | tee /dev/tty1
pkill alsaloop
aconnect -x
sudo modprobe -i mt7601u
sudo sed -i '/blacklist mt7601u/d' /etc/modprobe.d/blacklist.conf
sleep 2
printf "\033c" >> /dev/tty1
