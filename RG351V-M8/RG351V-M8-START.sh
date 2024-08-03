#!/bin/bash

# Modified from multiple files within https://github.com/jasonporritt/rg351_m8c
# Also uses https://github.com/stevelittlefish/auto_midi_connect

set -e

#
# Can we find ourselves?
if [ ! -d "/roms2/ports/RG351V-M8" ] && [ ! -d "/roms/ports/RG351V-M8" ]; then
	echo "RG351V-M8 doesn't appear to be where it should? (should be in [/roms/ports/] || [/roms2/ports/])"
	exit 1
fi

#
# Determine which card we're using, and move into it...
if [ -d "/roms2/ports/RG351V-M8" ]; then
	cd /roms2/ports/RG351V-M8
else
	cd /roms/ports/RG351V-M8
fi

#
# Disable wiffy if enabled, and set CPU governor to "performance" to help minimize audio crackles...
sudo modprobe -r mt7601u
sudo sed -i '$ablacklist mt7601u' /etc/modprobe.d/blacklist.conf
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

#
# Utilise auto_midi_connect to connect_midi_automatically...
sudo python3 ./M8-START.midi_connect.py
sudo chmod 666 /dev/tty1
/bin/aconnect -ol > /dev/tty1
sleep 2
printf "\033c" >> /dev/tty1

#
# Here's a bit of re-engineered but-absolutely-solid-in-principle rg351_m8c 'find the M8' logic:
# This runs a script in the background to try and 'catch' the M8's output audio before m8c starts...
./M8-START.alsaloop &
./m8c/m8c

#
# 3...2...1...now you're back in the room...
pkill alsaloop
aconnect -x
sudo modprobe -i mt7601u
sudo sed -i '/blacklist mt7601u/d' /etc/modprobe.d/blacklist.conf
