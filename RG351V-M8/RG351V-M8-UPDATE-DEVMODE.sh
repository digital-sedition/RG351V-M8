#!/bin/bash

# Modified from multiple files within https://github.com/jasonporritt/rg351_m8c

set -e



# Check for root/sudo...
tRoot=$(id -u)
if [ "$tRoot" == "0" ]; then
  echo "DO NOT RUN THIS AS ROOT/SUDO!"
  exit 1
fi

# ...and an internet connection!
tNet=`ip route | awk '/default/ { print $3 }'`
if [ -z "$tNet" ]; then
  echo "CANNOT FIND A NETWORK CONNECTION!"
  exit 1
fi



if [ ! -e "/home/ark/.config/.devenabled" ]; then
	echo "I don't think you can reliably build m8c (or anything, really) under ArkOS without enabling dev-mode :/"
	echo "[ See: https://github.com/christianhaitian/arkos/tree/main/Headers ]"
	echo ""
	echo "DO YOU WANT TO CONTINUE REGARDLESS?  BEAR IN MIND THAT ARKOS MIGHT **BREAK**"
	read -p "Enter GOATSE to continue: " ohimsofunny
	if [ "$ohimsofunny" != "GOATSE" ]; then
		echo "You declined.  ...which is likely sensible, to be honest."
		echo "It *did* work for me once, but then all other times it died a death..."
		exit 2
	fi
	echo ""
fi

sudo chmod 666 /dev/tty1
echo "== PREPARING TO RE/BUILD M8C" | tee /dev/tty1

#
# Can we find ourselves?
vPTH=""
[[ -d "/roms2/ports/RG351V-M8" ]] && vPTH="/roms2/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms2"
[[ -d "/roms/ports/RG351V-M8" ]] && vPTH="/roms/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms"
[[ -z "$vPTH" ]] && echo "!! RG351V-M8 doesn't appear to be where it should? (should be in [/roms/ports/] || [/roms2/ports/])" && exit 1

#
# Has our humble repo user slapped in a pre-/post-hook?
[[ -e "$vPTH/M8-UPDATE-DEVMODE.PRE.sh" ]] && vW8T=1 && vPRE=1
[[ -e "$vPTH/M8-UPDATE-DEVMODE.PST.sh" ]] && vW8T=1 && vPST=1
[[ "$vW8T" -eq 1 ]] && echo "** YO CHUCK! WE GOT HOOKS IN HERE. ...WICKED?" | tee /dev/tty1 && sleep 2

#
# Update ArkOS...
echo "-- UPDATING ARKOS" | tee /dev/tty1
sudo apt-get update --assume-yes | tee /dev/tty1

#
# Illuminate.  Deluminate.  Go ahead; you try it.
[[ "$vPRE" -eq 1 ]] && echo "-- RUNNING PRE-HOOK" | tee /dev/tty1 && $vPTH/M8-UPDATE-DEVMODE.PRE.sh

#
# Update the required tooling...
# Do a full re-install of each too, just to ensure everything is nice and clean.
echo "-- UPDATING TOOLING" | tee /dev/tty1
sudo apt-get install --assume-yes build-essential libc6-dev linux-libc-dev libserialport-dev libserialport0 libsdl2-dev | tee /dev/tty1

#
# Enter: the always scary 'rm -rf'!  Not *strictly* needed, but let's double-check that path is non-empty...
[[ -d "$vPTH/m8c" ]] && echo "-- REMOVING EXISTING M8C INSTALL" | tee /dev/tty1 && [[ -z "$vPTH" ]] && rm -rf $vPTH/m8c

#
# Why we're actually here: pull and build m8c!
echo "-- PULLING/BUILDING LATEST M8C" | tee /dev/tty1
cd $vPTH
git clone https://github.com/laamaa/m8c.git m8c
cd ./m8c
make | tee /dev/tty1

#
# Can we push the config?  YES, WE CA--well, we might not be able to?
if [ -d "~/.local/share/m8c" ] && [ -e "$vPTH/M8-DEFAULT-CONFIG.ini" ]; then
	cp $vPTH/M8-MY-DEFAULT-CONFIG.ini ~/.local/share/m8c/config.ini
fi

#
# ...ILLUMINATE. *claps*
[[ "$vPST" -eq 1 ]] && echo "-- RUNNING POST-HOOK" | tee /dev/tty1 && $vPTH/M8-UPDATE-DEVMODE.PST.sh

#
# Noice.
echo "-- CEASE ALL PANIC IMMEDAITELY; I THINK WE'RE GOOD!" | tee /dev/tty1
sleep 2
printf "\033c" >> /dev/tty1
