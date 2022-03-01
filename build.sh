#!/bin/bash

# Version: 5.0 -- by eznix (https://sourceforge.net/projects/ezarch/)
# Revision: 2022.01.18
# (GNU/General Public License version 3.0)

# ----------------------------------------
# Define Variables
# ----------------------------------------

LCLST="en_US"
# Format is language_COUNTRY where language is lower case two letter code
# and country is upper case two letter code, separated with an underscore

KEYMP="us"
KEYMOD="pc105"
# pc105 and pc104 are modern standards, all others need to be researched
MYUSERNM="live"
MYUSRPASSWD="arcigo"
RTPASSWD="toor"
MYHOSTNM="arcigo"

# ----------------------------------------
# Functions
# ----------------------------------------

# Test for root user
rootuser () {
  if [[ "$EUID" = 0 ]]; then
    continue
  else
    echo "Please Run As Root"
    sleep 2
    exit 1
  fi
}

# Display line error
handlerror () {
clear
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
}

# Clean up working directories
cleanup () {
[[ -d ./ezreleng ]] && rm -r ./ezreleng
[[ -d ./work ]] && rm -r ./work
[[ -d ./out ]] && mv ./out ../
sleep 2
}

# Requirements and preparation
prepreqs () {
pacman -S --noconfirm archlinux-keyring
pacman -S --needed --noconfirm archiso mkinitcpio-archiso
}

# Copy ezreleng to working directory
cpezreleng () {
cp -r /usr/share/archiso/configs/releng/ ./ezreleng
rm -r ./ezreleng/efiboot
rm -r ./ezreleng/syslinux
}

# Copy arcigo-repo to opt
cp_arcigo_repo () {
cp -r ./opt/arcigo /opt/
}

# Remove arcigo-repo from opt
rm_arcigo_repo () {
rm -r /opt/arcigo
}

# Delete automatic login
nalogin () {
[[ -d ./ezreleng/airootfs/etc/systemd/system/getty@tty1.service.d ]] && rm -r ./ezreleng/airootfs/etc/systemd/system/getty@tty1.service.d
}

# Remove cloud-init and other stuff
rmunitsd () {
[[ -d ./ezreleng/airootfs/etc/systemd/system/cloud-init.target.wants ]] && rm -r ./ezreleng/airootfs/etc/systemd/system/cloud-init.target.wants
[[ -f ./ezreleng/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service ]] && rm ./ezreleng/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service
[[ -f ./ezreleng/airootfs/etc/xdg/reflector/reflector.conf ]] && rm ./ezreleng/airootfs/etc/xdg/reflector/reflector.conf
}

# Add Bluetooth, cups, haveged, NetworkManager, & sddm systemd links
addnmlinks () {
[[ ! -d ./ezreleng/airootfs/etc/systemd/system/sysinit.target.wants ]] && mkdir -p ./ezreleng/airootfs/etc/systemd/system/sysinit.target.wants
[[ ! -d ./ezreleng/airootfs/etc/systemd/system/network-online.target.wants ]] && mkdir -p ./ezreleng/airootfs/etc/systemd/system/network-online.target.wants
[[ ! -d ./ezreleng/airootfs/etc/systemd/system/multi-user.target.wants ]] && mkdir -p ./ezreleng/airootfs/etc/systemd/system/multi-user.target.wants
[[ ! -d ./ezreleng/airootfs/etc/systemd/system/printer.target.wants ]] && mkdir -p ./ezreleng/airootfs/etc/systemd/system/printer.target.wants
[[ ! -d ./ezreleng/airootfs/etc/systemd/system/sockets.target.wants ]] && mkdir -p ./ezreleng/airootfs/etc/systemd/system/sockets.target.wants
[[ ! -d ./ezreleng/airootfs/etc/systemd/system/timers.target.wants ]] && mkdir -p ./ezreleng/airootfs/etc/systemd/system/timers.target.wants
[[ ! -d ./ezreleng/airootfs/etc/systemd/system/bluetooth.target.wants ]] && mkdir -p ./ezreleng/airootfs/etc/systemd/system/bluetooth.target.wants
ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service ./ezreleng/airootfs/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service
ln -sf /usr/lib/systemd/system/NetworkManager.service ./ezreleng/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service ./ezreleng/airootfs/etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service
ln -sf /usr/lib/systemd/system/sddm.service ./ezreleng/airootfs/etc/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/haveged.service ./ezreleng/airootfs/etc/systemd/system/sysinit.target.wants/haveged.service
ln -sf /usr/lib/systemd/system/cups.service ./ezreleng/airootfs/etc/systemd/system/printer.target.wants/cups.service
ln -sf /usr/lib/systemd/system/cups.socket ./ezreleng/airootfs/etc/systemd/system/sockets.target.wants/cups.socket
ln -sf /usr/lib/systemd/system/cups.path ./ezreleng/airootfs/etc/systemd/system/multi-user.target.wants/cups.path
ln -sf /usr/lib/systemd/system/plocate-updatedb.timer ./ezreleng/airootfs/etc/systemd/system/timers.target.wants/plocate-updatedb.timer
ln -sf /usr/lib/systemd/system/bluetooth.service ./ezreleng/airootfs/etc/systemd/system/dbus-org.bluez.service
ln -sf /usr/lib/systemd/system/bluetooth.service ./ezreleng/airootfs/etc/systemd/system/bluetooth.target.wants/bluetooth.service
}

# Copy files to customize the ISO
cpmyfiles () {
cp packages.x86_64 ./ezreleng/
cp pacman.conf ./ezreleng/
cp profiledef.sh ./ezreleng/
cp -r efiboot ./ezreleng/
cp -r syslinux ./ezreleng/
cp -r usr ./ezreleng/airootfs/
cp -r etc ./ezreleng/airootfs/
cp -r opt ./ezreleng/airootfs/
ln -sf /usr/share/arcigo-docs ./ezreleng/airootfs/etc/skel/arcigo-docs
}

# Set hostname
sethostname () {
echo "${MYHOSTNM}" > ./ezreleng/airootfs/etc/hostname
}

# Create passwd file
crtpasswd () {
echo "root:x:0:0:root:/root:/usr/bin/bash
"${MYUSERNM}":x:1010:1010::/home/"${MYUSERNM}":/bin/bash" > ./ezreleng/airootfs/etc/passwd
}

# Create group file
crtgroup () {
echo "root:x:0:root
sys:x:3:"${MYUSERNM}"
adm:x:4:"${MYUSERNM}"
wheel:x:10:"${MYUSERNM}"
log:x:19:"${MYUSERNM}"
network:x:90:"${MYUSERNM}"
floppy:x:94:"${MYUSERNM}"
scanner:x:96:"${MYUSERNM}"
power:x:98:"${MYUSERNM}"
rfkill:x:850:"${MYUSERNM}"
users:x:985:"${MYUSERNM}"
video:x:860:"${MYUSERNM}"
storage:x:870:"${MYUSERNM}"
optical:x:880:"${MYUSERNM}"
lp:x:840:"${MYUSERNM}"
audio:x:890:"${MYUSERNM}"
"${MYUSERNM}":x:1010:" > ./ezreleng/airootfs/etc/group
}

# Create shadow file
crtshadow () {
usr_hash=$(openssl passwd -6 "${MYUSRPASSWD}")
root_hash=$(openssl passwd -6 "${RTPASSWD}")
echo "root:"${root_hash}":14871::::::
"${MYUSERNM}":"${usr_hash}":14871::::::" > ./ezreleng/airootfs/etc/shadow
}

# create gshadow file
crtgshadow () {
echo "root:!*::root
"${MYUSERNM}":!*::" > ./ezreleng/airootfs/etc/gshadow
}

# Set the keyboard layout
setkeylayout () {
    echo "KEYMAP="${KEYMP}"" > ./ezreleng/airootfs/etc/vconsole.conf
}

# Create 00-keyboard.conf file
crtkeyboard () {
mkdir -p ./ezreleng/airootfs/etc/X11/xorg.conf.d
echo "Section \"InputClass\"
        Identifier \"system-keyboard\"
        MatchIsKeyboard \"on\"
        Option \"XkbLayout\" \""${KEYMP}"\"
        Option \"XkbModel\" \""${KEYMOD}"\"
EndSection" > ./ezreleng/airootfs/etc/X11/xorg.conf.d/00-keyboard.conf
}

# Fix 40-locale-gen.hook and create locale.conf
crtlocalec () {
    sed -i "s/en_US/"${LCLST}"/g" ./ezreleng/airootfs/etc/pacman.d/hooks/40-locale-gen.hook
    echo "LANG="${LCLST}".UTF-8" > ./ezreleng/airootfs/etc/locale.conf
}

# Start mkarchiso
runmkarchiso () {
mkarchiso -v -w ./work -o ./out ./ezreleng
}

# ----------------------------------------
# Run Functions
# ----------------------------------------

rootuser
handlerror
prepreqs
cleanup
cpezreleng
addnmlinks
cp_arcigo_repo
nalogin
rmunitsd
cpmyfiles
sethostname
crtpasswd
crtgroup
crtshadow
crtgshadow
setkeylayout
crtkeyboard
crtlocalec
runmkarchiso
rm_arcigo_repo
