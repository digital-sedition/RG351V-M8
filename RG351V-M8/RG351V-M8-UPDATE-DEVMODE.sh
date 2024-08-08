#!/bin/bash

set -e



# Check for root/sudo...
tRoot=$(id -u)
if [ "$tRoot" == "0" ]; then
  echo "DO NOT RUN THIS AS ROOT/SUDO!"
  exit 1
fi

sudo chmod 666 /dev/tty1

if [ ! -e "/home/ark/.config/.devenabled" ]; then
	echo "I don't think you can reliably build m8c (or anything, really) under ArkOS without first enabling dev-mode, and you don't appear to have it enabled." | tee /dev/tty1
	echo "" | tee /dev/tty1
	echo "This is something you don't want to have done auto-magically for you: enabling it ERASES your content (roms, etc.), so I don't provide this in these scripts." | tee /dev/tty1
	echo "" | tee /dev/tty1
	echo "https://github.com/christianhaitian/arkos/tree/main/Headers for more information." | tee /dev/tty1
	echo "" | tee /dev/tty1
	sleep 8
	exit 1
fi



# Can we find ourselves?
vPTH=""
[[ -d "/roms2/ports/RG351V-M8" ]] && vPTH="/roms2/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms2" | tee /dev/tty1
[[ -d "/roms/ports/RG351V-M8" ]] && vPTH="/roms/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms" | tee /dev/tty1
[[ -z "$vPTH" ]] && echo "!! RG351V-M8 doesn't appear to be where it should? (should be in [/roms/ports/] || [/roms2/ports/])" | tee /dev/tty1 && exit 1

# Has our humble repo user slapped in a pre-/post-hook?
[[ -e "$vPTH/M8-UPDATE-DEVMODE.PRE.sh" ]] && vW8T=1 && vPRE=1
[[ -e "$vPTH/M8-UPDATE-DEVMODE.PST.sh" ]] && vW8T=1 && vPST=1
[[ "$vW8T" -eq 1 ]] && echo "** YO CHUCK! WE GOT HOOKS IN HERE. ...WICKED?" | tee /dev/tty1 && sleep 2



# Update ArkOS...
echo "-- UPDATING ARKOS" | tee /dev/tty1
sudo apt-get update --assume-yes | tee /dev/tty1



# Illuminate.  Deluminate.  Go ahead; you try it.
[[ "$vPRE" -eq 1 ]] && echo "-- RUNNING PRE-HOOK" | tee /dev/tty1 && $vPTH/M8-UPDATE-DEVMODE.PRE.sh



# Update the required tooling...
# Do a full re-install of each too, just to ensure everything is nice and clean.
echo "-- UPDATING TOOLING" | tee /dev/tty1
sudo apt-get install --assume-yes build-essential libc6-dev linux-libc-dev libserialport-dev libserialport0 libsdl2-dev | tee /dev/tty1



# Enter: the always scary 'rm -rf'!  Not *strictly* needed, but let's double-check that path is non-empty too...
[[ -d "$vPTH/m8c" ]] && echo "-- REMOVING EXISTING M8C INSTALL" | tee /dev/tty1 && [[ -z "$vPTH" ]] && rm -rf $vPTH/m8c

# Why we're actually here: pull and build m8c!
echo "-- PULLING/BUILDING LATEST M8C" | tee /dev/tty1
cd $vPTH
git clone https://github.com/laamaa/m8c.git m8c
cd ./m8c
make | tee /dev/tty1

# Can we push the config?  YES, WE CA--well, we might not be able to?
if [ -d "~/.local/share/m8c" ] && [ -e "$vPTH/M8-DEFAULT-CONFIG.ini" ]; then
	cp $vPTH/M8-MY-DEFAULT-CONFIG.ini ~/.local/share/m8c/config.ini
fi



# ...ILLUMINATE. *claps*
[[ "$vPST" -eq 1 ]] && echo "-- RUNNING POST-HOOK" | tee /dev/tty1 && $vPTH/M8-UPDATE-DEVMODE.PST.sh

# Noice.
echo "-- CEASE ALL PANIC IMMEDAITELY; I THINK WE'RE GOOD!" | tee /dev/tty1
sleep 2
printf "\033c" >> /dev/tty1
