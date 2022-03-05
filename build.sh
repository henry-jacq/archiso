#!/bin/bash

# Version: 1.4 -- by henry (https://https://github.com/arcigo-os/) (https://github.com/henry-jacq/)
# Revision: 2022.03.05
# (GNU/General Public License version 3.0)

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
[[ -d ./releng ]] && rm -r ./releng
[[ -d ./work ]] && rm -r ./work
[[ -d ./out ]] && mv ./out ../
sleep 2
}

# Requirements and preparation
prepreqs () {
pacman -S --noconfirm archlinux-keyring
pacman -S --needed --noconfirm archiso mkinitcpio-archiso
}

# Copy releng to working directory
cpreleng () {
cp -r /usr/share/archiso/configs/releng/ ./releng
rm -r ./releng/efiboot
rm -r ./releng/syslinux
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
[[ -d ./releng/airootfs/etc/systemd/system/getty@tty1.service.d ]] && rm -r ./releng/airootfs/etc/systemd/system/getty@tty1.service.d
}

# Remove cloud-init and other stuff
rmunitsd () {
[[ -d ./releng/airootfs/etc/systemd/system/cloud-init.target.wants ]] && rm -r ./releng/airootfs/etc/systemd/system/cloud-init.target.wants
[[ -f ./releng/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service ]] && rm ./releng/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service
[[ -f ./releng/airootfs/etc/xdg/reflector/reflector.conf ]] && rm ./releng/airootfs/etc/xdg/reflector/reflector.conf
}

# Add Bluetooth, cups, haveged, NetworkManager, & sddm systemd links
addnmlinks () {
[[ ! -d ./releng/airootfs/etc/systemd/system/sysinit.target.wants ]] && mkdir -p ./releng/airootfs/etc/systemd/system/sysinit.target.wants
[[ ! -d ./releng/airootfs/etc/systemd/system/network-online.target.wants ]] && mkdir -p ./releng/airootfs/etc/systemd/system/network-online.target.wants
[[ ! -d ./releng/airootfs/etc/systemd/system/multi-user.target.wants ]] && mkdir -p ./releng/airootfs/etc/systemd/system/multi-user.target.wants
[[ ! -d ./releng/airootfs/etc/systemd/system/printer.target.wants ]] && mkdir -p ./releng/airootfs/etc/systemd/system/printer.target.wants
[[ ! -d ./releng/airootfs/etc/systemd/system/sockets.target.wants ]] && mkdir -p ./releng/airootfs/etc/systemd/system/sockets.target.wants
[[ ! -d ./releng/airootfs/etc/systemd/system/timers.target.wants ]] && mkdir -p ./releng/airootfs/etc/systemd/system/timers.target.wants
[[ ! -d ./releng/airootfs/etc/systemd/system/bluetooth.target.wants ]] && mkdir -p ./releng/airootfs/etc/systemd/system/bluetooth.target.wants
ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service ./releng/airootfs/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service
ln -sf /usr/lib/systemd/system/NetworkManager.service ./releng/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service ./releng/airootfs/etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service
ln -sf /usr/lib/systemd/system/sddm.service ./releng/airootfs/etc/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/haveged.service ./releng/airootfs/etc/systemd/system/sysinit.target.wants/haveged.service
ln -sf /usr/lib/systemd/system/cups.service ./releng/airootfs/etc/systemd/system/printer.target.wants/cups.service
ln -sf /usr/lib/systemd/system/cups.socket ./releng/airootfs/etc/systemd/system/sockets.target.wants/cups.socket
ln -sf /usr/lib/systemd/system/cups.path ./releng/airootfs/etc/systemd/system/multi-user.target.wants/cups.path
ln -sf /usr/lib/systemd/system/plocate-updatedb.timer ./releng/airootfs/etc/systemd/system/timers.target.wants/plocate-updatedb.timer
ln -sf /usr/lib/systemd/system/bluetooth.service ./releng/airootfs/etc/systemd/system/dbus-org.bluez.service
ln -sf /usr/lib/systemd/system/bluetooth.service ./releng/airootfs/etc/systemd/system/bluetooth.target.wants/bluetooth.service
}

# Copy files to customize the ISO
cpmyfiles () {
cp packages.x86_64 ./releng/
cp pacman.conf ./releng/
cp profiledef.sh ./releng/
cp -r efiboot ./releng/
cp -r syslinux ./releng/
cp -r usr ./releng/airootfs/
cp -r etc ./releng/airootfs/
cp -r opt ./releng/airootfs/
ln -sf /usr/share/arcigo-docs ./releng/airootfs/etc/skel/arcigo-docs
}

# Set hostname
sethostname () {
echo "${MYHOSTNM}" > ./releng/airootfs/etc/hostname
}

# Create passwd file
crtpasswd () {
echo "root:x:0:0:root:/root:/usr/bin/bash
"${MYUSERNM}":x:1010:1010::/home/"${MYUSERNM}":/bin/bash" > ./releng/airootfs/etc/passwd
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
"${MYUSERNM}":x:1010:" > ./releng/airootfs/etc/group
}

# Create shadow file
crtshadow () {
usr_hash=$(openssl passwd -6 "${MYUSRPASSWD}")
root_hash=$(openssl passwd -6 "${RTPASSWD}")
echo "root:"${root_hash}":14871::::::
"${MYUSERNM}":"${usr_hash}":14871::::::" > ./releng/airootfs/etc/shadow
}

# create gshadow file
crtgshadow () {
echo "root:!*::root
"${MYUSERNM}":!*::" > ./releng/airootfs/etc/gshadow
}

# Set the keyboard layout
setkeylayout () {
    echo "KEYMAP="${KEYMP}"" > ./releng/airootfs/etc/vconsole.conf
}

# Create 00-keyboard.conf file
crtkeyboard () {
mkdir -p ./releng/airootfs/etc/X11/xorg.conf.d
echo "Section \"InputClass\"
        Identifier \"system-keyboard\"
        MatchIsKeyboard \"on\"
        Option \"XkbLayout\" \""${KEYMP}"\"
        Option \"XkbModel\" \""${KEYMOD}"\"
EndSection" > ./releng/airootfs/etc/X11/xorg.conf.d/00-keyboard.conf
}

# Fix 40-locale-gen.hook and create locale.conf
crtlocalec () {
    sed -i "s/en_US/"${LCLST}"/g" ./releng/airootfs/etc/pacman.d/hooks/40-locale-gen.hook
    echo "LANG="${LCLST}".UTF-8" > ./releng/airootfs/etc/locale.conf
}

# Start mkarchiso
runmkarchiso () {
mkarchiso -v -w ./work -o ./out ./releng
}

# ----------------------------------------
# Run Functions
# ----------------------------------------

rootuser
handlerror
prepreqs
cleanup
cpreleng
addnmlinks
# cp_arcigo_repo
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
