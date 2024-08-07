#!/bin/bash

# I FUCKING HATE HOW ARKOS WORKS - IT *THINKS* IT HAS DEV-TOOLS INSTALLED BUT...HASN'T.
#
# THIS IS LIKELY FOR THE (GOOD) REASON THAT IT REDUCES ITS FOOTPRINT TO ENABLE MORE ROOM FOR GAMING
# BUT, RIGHT NOW, AFTER HOURS OF BASHING MY HEAD AGAINST A WALL, I JUST WISH I COULD APT-GET PACKAGES
# TO BUILD WITH!!!  YES, I KNOW THERE'S A 'DEV MODE', BUT IT FUNDAMENTALLY ALTERS ARKOS, AND I
# WOULDN'T WANT THAT TO BE A REQUIREMENT FOR THE AVERAGE USER.  AND NO, I DON'T LIKE PRE-BUILT
# PACKAGES BECAUSE A) PEOPLE EVENTUALLY STOP UPDATING THEM AND LEAVE OTHER USERS HIGH-AND-DRY, AND
# B) PEOPLE SHOULDN'T JUST TRUST RANDOM BINARIES BLINDLY.
#
# /breathes/
#
# Okay, after considering all other possibilities, the best option for compiling m8c from source,
# given installing missing packages can trash the ArkOS install, was to construct a CHROOT jail that
# provides a very minimal environment that can host all the dev libraries you *would* install.  The
# resultant m8c build is therefore built compatible for the host without breaking anything.  Yay!
#
# It took a lot of trial and error to fully map this out.  People online don't seem to understand that
# containerisation (debootstrap etc.) doesn't meet requirements for something like this due to the
# differences between the host OS and <insert container distro> (especially glibc).  I love that Linux
# Package Managers essentially resolve C/C++ dependency issues, but the fact you can't just setup
# a folder, slap libs in there, and then build against THOSE libs (like you do on Windows) is a pain.
# Like, yeah, building under Windows is a pain because you have to deal with doing all that dependency
# shit yourself - and that ISN'T pretty, let's be fair - but Christ on a bike, all I wanted to do was
# just use host libs AND some optional-but-not-host-installed libs...
# 
# Fack.  I hope at least someone other than me can get good use out of this.

set -e



# Check for root/sudo...
tRoot=$(id -u)
if [ "$tRoot" == "0" ]; then
  echo "DO NOT RUN THIS AS ROOT/SUDO!"
  exit 1
fi

# ...an internet connection...
tNet=`ip route | awk '/default/ { print $3 }'`
if [ -z "$tNet" ]; then
  echo "CANNOT FIND A NETWORK CONNECTION!"
  exit 1
fi

# ...and disk space!
tDisk=$(df / | awk '/[0-9]%/{print $(NF-2)}')
if [ "$tDisk" -le 358400 ]; then # check for space, but don't fail - can't promise this limit is enough in the future, after all!
  echo "(POTENTIALLY) NOT ENOUGH FREE SPACE TO DO THIS...!"
  echo "Script WILL continue unless you stop it now."
  sleep 4
fi



sudo chmod 666 /dev/tty1
echo "## PROP'ING UP M8C CHROOT-JAIL BUILD ENV" | tee /dev/tty1



#
#
# Can we find ourselves?
vPTH=""
[[ -d "/roms2/ports/RG351V-M8" ]] && vPTH="/roms2/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms2"
[[ -d "/roms/ports/RG351V-M8" ]] && vPTH="/roms/ports/RG351V-M8" && echo "-- Found RG351V-M8 in /roms"
[[ -z "$vPTH" ]] && echo "!! RG351V-M8 doesn't appear to be where it should? (should be in [/roms/ports/] || [/roms2/ports/])" && exit 1

# Has our humble repo user slapped in a pre-/post-hook?
[[ -e "$vPTH/M8-UPDATE1.PRE.sh" ]] && vW8T=1 && vPRE1=1
[[ -e "$vPTH/M8-UPDATE2.PRE.sh" ]] && vW8T=1 && vPRE2=1
[[ -e "$vPTH/M8-UPDATE.PST.sh" ]] && vW8T=1 && vPST=1
[[ "$vW8T" -eq 1 ]] && echo "** YO CHUCK! WE GOT HOOKS IN HERE. ...WICKED?" | tee /dev/tty1 && sleep 2



#
#
# Where we build within; seems to be issues building this in [/roms/ports/] - homedir seems fine.
echo "" | tee /dev/tty1
echo "-- This normally takes ~20 minutes and uses ~340M of space." | tee /dev/tty1
echo "-- Script will automatically delete all that when done though!" | tee /dev/tty1



#
#
# Update ArkOS...
echo "" | tee /dev/tty1
echo ">> ArkOS apt-get update..." | tee /dev/tty1
sudo apt-get update --assume-yes | tee /dev/tty1



#
#
# The folder(s) all of this will be captured within.
vHOM=/home/ark
[[ -z "$vHOM" ]] || [[ ! -d "$vHOM" ]] && echo "'ark' home folder not found?" | tee /dev/tty1 && exit 1
vBLD=$vHOM/m8c-gaol
[[ -z "$vBLD" ]] && echo "Path is (somehow) not setting?" | tee /dev/tty1 && exit 1 # just being conscious...

# Create the chroot jail, along with its base folders.  If it already exists, delete it - always build from fresh.
[[ -d "$vBLD/gaol" ]] && rm -rf $vBLD/gaol
mkdir -p $vBLD/gaol/{bin,etc,lib,tmp,usr}



#
#
#
# Download all identified m8c build packages as DEB bundles.
# These bundles will be requested against the system's architecture etc., so will match the host's requirements and should (hopefully) mean OS updates won't invalidate this.
# If m8c dependencies change, you'll need to adjust the [ vLIB=(<list of things here>) ] line -- all the rest should still be okay.
echo "" | tee /dev/tty1
echo ">> Base folder structure built; downloading dpkgs..." | tee /dev/tty1
echo "   This may *appear* to hang, but it IS silently doing things :)" | tee /dev/tty1
mkdir -p $vBLD/dpkg
cd $vBLD/dpkg

# The libsdl2 runtime package is a bit of a linchpin for this; catching all the main runtime requirements of m8c to properly build it...
# TODO: potentially review this list.  It was a bit of a trail-and-error in seeing that m8c failed to build, finding the missing library, etc..
vLIB=("build-essential" "libc6-dev" "linux-libc-dev" "binutils" "gcc" "libisl-dev" "libmpc-dev" "libmpfr-dev" "libgmp-dev" "libserialport-dev" "libserialport0" "libsdl2-dev" "libasound-dev" "libpulse-dev" "xorg-dev" "libwayland-dev" "libffi-dev" "libsystemd-dev" "libwrap0" "libsndfile1" "libflac-dev" "libvorbis-dev" "libogg-dev" "libasyncns-dev" "libgpg-error-dev" "libbsd-dev" "libsdl2-2.0-0")
[[ -z "$vLIB" ]] && echo "No dpkg libraries to download?" | tee /dev/tty1 && exit 1

# Find all package dependencies (currently just checked twice) and then download them...
# TODO: [maybe] if possible, is there a way to auto-magically find this out?  Or just update so it resolves the dependencies until <the new result> == <the previous>?
for i in ${vLIB[@]}; do apt-cache depends $i | grep -E 'Depends|Recommends' | cut -d ':' -f 2,3 | sed -e s/'<'/''/ -e s/'>'/''/ >> dpkg.list; done
echo "   First pass of dpkg dependencies done; now for a second..." | tee /dev/tty1
sort -u dpkg.list > dpkg.list.clean
cat dpkg.list.clean | while read line; do apt-cache depends $line | grep -E 'Depends|Recommends' | cut -d ':' -f 2,3 | sed -e s/'<'/''/ -e s/'>'/''/ 1>> dpkg.list; done
echo "   Second pass done; now to download them all..." | tee /dev/tty1
rm dpkg.list.clean && sort -u dpkg.list > dpkg.list.clean && rm dpkg.list
cat dpkg.list.clean | while read line; do apt-get download $line | tee /dev/tty1 2>>errors.txt; done

# Finally, download the named packages themselves...
for i in ${vLIB[@]}; do apt-get download $i | tee /dev/tty1 2>>errors.txt; done



#
#
#
# Okay: using the DEB bundles from above, we extract them one-by-one into the jail.
echo "" | tee /dev/tty1
echo ">> Setting up jail..." | tee /dev/tty1
echo "   Extracting dpkgs into jail..." | tee /dev/tty1
cd $vBLD/dpkg
vDPK="$(ls *.deb)"
for i in $vDPK; do
	dpkg-deb -x $vBLD/dpkg/$i $vBLD/gaol
done

# Now we pull in some system binaries (and support libraries) to help out...
# NOTE: trial and error meant sometimes these weren't pulled; this step (bar bash and pkg-config) might not be needed.
echo "   Pulling system programs into jail..." | tee /dev/tty1
vDPS=("/bin/bash" "/bin/sh" "/bin/sed" "/bin/as" "/bin/ld" "/bin/pkg-config")
for i in ${vDPS[@]}; do
	cp -v $i $vBLD/gaol/bin
	chRTDepsTmp="$(ldd $i | egrep -o '/lib.*\..* ')"
	for j in $chRTDepsTmp; do cp -v --parents "$j" "${vBLD}/gaol"; done
done



#
#
#
# First pre-build hook for the user if wanted...
[[ "$vPRE1" -eq 1 ]] && echo "!! RUNNING PRE-HOOK #1" | tee /dev/tty1 && $vPTH/M8-UPDATE1.PRE.sh



#
#
#
# Grab the actual reason why we're here, and build it...
echo "" | tee /dev/tty1
echo ">> Time to grab m8c and build it...!" | tee /dev/tty1
echo "   Pulling m8c..." | tee /dev/tty1
mkdir -p $vBLD/gaol/m8c
git clone https://github.com/laamaa/m8c.git $vBLD/gaol/m8c

# Prepare the CHROOT script...
echo "   Running jail build!" | tee /dev/tty1
echo '#!/bin/bash' > $vBLD/gaol/ex.sh && chmod 777 $vBLD/gaol/ex.sh
echo "PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig" >> $vBLD/gaol/ex.sh
echo "cd m8c && make" >> $vBLD/gaol/ex.sh

# Run the CHROOT!
sudo chroot $vBLD/gaol ./ex.sh



#
#
#
# Second pre-build hook for the user if wanted...
[[ "$vPRE2" -eq 1 ]] && echo "!! RUNNING PRE-HOOK #2" | tee /dev/tty1 && $vPTH/M8-UPDATE2.PRE.sh



#
#
#
# Okay, clean up, move m8c, and erase the jail...
echo "" | tee /dev/tty1
echo ">> Time to clean up our jail..." | tee /dev/tty1
vSIZ=$(du -sh $vBLD)
echo "   Storage used: $vSIZ"
sleep 1
rm -rf $vBLD/gaol/m8c/src
rm -rf $vBLD/gaol/m8c/package
echo "   Moving m8c into its proper home..." | tee /dev/tty1
[[ -d "$vPTH/m8c" ]] && rm -rf $vPTH/m8c
mkdir -p $vPTH/m8c
cp -r $vBLD/gaol/m8c/* $vPTH/m8c/
echo "   Deleting the jail!" | tee /dev/tty1
rm -rf $vBLD

# Can we push the config?  YES, WE CA--well, we might not be able to?
if [ -d "~/.local/share/m8c" ] && [ -e "$vPTH/M8-DEFAULT-CONFIG.ini" ]; then
	cp $vPTH/M8-MY-DEFAULT-CONFIG.ini ~/.local/share/m8c/config.ini
fi



#
#
#
# Post-duck hook fuck.
[[ "$vPST" -eq 1 ]] && echo "!! RUNNING POST-HOOK" | tee /dev/tty1 && $vPTH/M8-UPDATE.PST.sh



#
#
#
# Fin.
# Thank you for coming to my Ted Talk.
echo "" | tee /dev/tty1
echo "## FINISHED" | tee /dev/tty1
sleep 2
printf "\033c" >> /dev/tty1
