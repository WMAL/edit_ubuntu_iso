#!/bin/bash
set -x

# see: https://help.ubuntu.com/community/LiveCDCustomization
# see: https://wiki.ubuntu.com/CustomizeLiveInitrd

PATH=.:$(dirname "$0"):$PATH

ISO=$1
TMPDIR=${2:-/tmp/edit_iso.$$}
PWDORIG=$PWD

mkdir -p "$TMPDIR"/isomnt
rm -f /tmp/edit_iso && ln -s "$TMPDIR" /tmp/edit_iso
sudo mount -o loop "$1" "$TMPDIR"/isomnt
cd "$TMPDIR"

read -p "Edit initrd... (y/n) [n]: " RESP
if [ "x$RESP" = "xy" ]; then
    INITRD=$(ls "isomnt/casper/initrd."*)
    edit_initrd.sh "$INITRD" || {
        ret=$?
        echo "Not generating iso"
        sudo umount isomnt
        exit $ret
    }

fi

read -p "Edit grub config... (y/n) [n]: " RESP
cp isomnt/boot/grub/grub.cfg .
if [ "x$RESP" = "xy" ]; then
    sudo nano -w grub.cfg
fi

read -p "Edit grub loopback config... (y/n) [n]: " RESP
cp isomnt/boot/grub/loopback.cfg .
if [ "x$RESP" = "xy" ]; then
    sudo nano -w loopback.cfg
fi

read -p "Edit disk defines... (y/n) [n]: " RESP
cp isomnt/README.diskdefines .
if [ "x$RESP" = "xy" ]; then
    chmod +w README.diskdefines
    nano -w README.diskdefines
    chmod -w README.diskdefines
fi

grep DISKNAME README.diskdefines
read -p "Enter ISO Image Name (32 chars or less): " DISKNAME
if [ -z "$DISKNAME" ]; then
    DISKNAME=$(grep DISKNAME README.diskdefines|cut -f3-|cut -b1-32)
    DISKNAME=$(awk "{ if $ }" < README.diskdefines)
fi

INITRD=$(basename "isomnt/casper/initrd."*)
# regen the md5sum.txt
grep -v "README.diskdefines\|$INITRD" isomnt/md5sum.txt > md5sum.txt
md5sum README.diskdefines "$INITRD" |
    sed 's|initrd|./casper/initrd|' >> md5sum.txt

( cd isomnt
# regen the iso
read -p "Enter iso name tag: " ISOTAG

# isolinux directory needs to be written to
cp -r isolinux ..

for P in casper/* boot/grub/* *; do
    case "$P" in
        casper|casper/$INITRD) ;;
        README.diskdefines|md5sum.txt) ;;
        isolinux|isolinux/boot.cat) ;;
        boot|boot/grub/grub.cfg) ;;
        boot|boot/grub/loopback.cfg) ;;
        *) echo "$P=$P";;
    esac
done > ../path-list.txt
sudo mkisofs -D -r -V "$DISKNAME" -cache-inodes -J -l -graft-points \
    -b isolinux/isolinux.bin -c isolinux/boot.cat -x *boot.cat* \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -o "$PWDORIG"/"$(basename "$ISO" .iso)"-"$ISOTAG".iso \
    -path-list ../path-list.txt \
    casper/$INITRD=../$INITRD \
    boot/grub/grub.cfg=../grub.cfg \
    boot/grub/loopback.cfg=../loopback.cfg \
    README.diskdefines=../README.diskdefines \
    md5sum.txt=../md5sum.txt \
    isolinux=../isolinux || (echo "failed see what happened..." && bash)
)

sudo umount isomnt

cd ..
rm -rf "$TMPDIR"