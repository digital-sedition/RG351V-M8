#!/bin/bash

# Modified from multiple files within https://github.com/jasonporritt/rg351_m8c

set -e

#
# Can we find ourselves?
if [ ! -d "/roms2/ports/RG351V-M8" ] && [ ! -d "/roms/ports/RG351V-M8" ]; then
	echo "RG351V-M8 doesn't appear to be where it should? (should be in [/roms/ports/] || [/roms2/ports/])"
	exit 1
fi

#
# It's go time...
sudo chmod 666 /dev/tty1
echo "== PREPARING TO RE/BUILD M8C" | tee /dev/tty1

#
# Determine which card we're using, and move into it...
if [ -d "/roms2/ports/RG351V-M8" ]; then
	cd /roms2/ports/RG351V-M8
	echo "-- NOTE: FOUND RG351V-M8 ON SD CARD #2" | tee /dev/tty1
else
	cd /roms/ports/RG351V-M8
	echo "-- NOTE: FOUND RG351V-M8 ON SD CARD #1 (NOT #2)" | tee /dev/tty1
fi
sleep 2

#
# Update ArkOS...
# Note: I was worried this could 'break' the new screen fix, but it doesn't seem to.
echo "-- UPDATING ARKOS" | tee /dev/tty1
sudo apt-get update --assume-yes | tee /dev/tty1

#
# Update the required tooling...
# Do a full re-install of each too, just to ensure everything is nice and clean.
echo "-- UPDATING TOOLING" | tee /dev/tty1
sudo apt-get --reinstall install --assume-yes libserialport-dev libserialport0 libsdl2-dev build-essential libc6-dev linux-libc-dev | tee /dev/tty1

#
# Add the current user to the dialout group (used by libserialport)...
# Likely not needed (I imagine this is something the rg351_m8c maintainer personally wanted in), but kept because why not.
if id -nG "$USER" | grep -qw "dialout"; then
    echo "-- NOTE: USER ALREADY ADDED TO DIALOUT" | tee /dev/tty1
else
	sudo adduser $USER dialout
fi

#
# Enter: the always scary 'rm -rf'!
if [ -d "./m8c" ]; then
	echo "-- REMOVING EXISTING M8C INSTALL" | tee /dev/tty1
	rm -rf ./m8c
fi

#
# Why we're actually here: pull and build m8c!
echo "-- PULLING/BUILDING LATEST M8C" | tee /dev/tty1
git clone https://github.com/laamaa/m8c.git m8c
cd ./m8c
make | tee /dev/tty1
cd ..

#
# Building m8c fucky-wucky SDL2 run-time for PortMaster, so resetty-wetty it.
# Note: if this doesn't fix things, uninstall SDL2-dev and then re-install the below run-time.
sudo apt-get --reinstall install --assume-yes libsdl2-2.0-0 | tee /dev/tty1

#
# Can we push the config?  YES, WE CA--well, we might not be able to?
if [ -d "~/.local/share/m8c" ] && [ -e "./M8-DEFAULT-CONFIG.ini" ]; then
	cp ./M8-DEFAULT-CONFIG.ini ~/.local/share/m8c/config.ini
fi

#
# Noice.
echo "-- CEASE ALL PANIC ACTIONS; I THINK WE'RE GOOD" | tee /dev/tty1
sleep 2
printf "\033c" >> /dev/tty1
