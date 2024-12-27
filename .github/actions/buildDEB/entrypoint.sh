#!/usr/bin/bash
msg(){
    echo
    echo "==> $*"
    echo
}

free
df -h

msg "Updating container..."
apt-get update && apt-get upgrade -y

workdir=$(pwd)
echo $workdir
mkdir -p build
mkdir -p pzsvrtool/usr/bin
mkdir -p pzsvrtool/usr/libexec/pzsvrtool
mkdir -p pzsvrtool/DEBIAN
cp SOURCES/* pzsvrtool/usr/libexec/pzsvrtool
chmod +x pzsvrtool/usr/libexec/pzsvrtool/*
chmod 644 pzsvrtool/usr/libexec/pzsvrtool/pzsvrtool_common.py
chmod 644 pzsvrtool/usr/libexec/pzsvrtool/pzsvrtool_common.sh
mv -f pzsvrtool/usr/libexec/pzsvrtool/pzsvrtool pzsvrtool/usr/bin
cp control pzsvrtool/DEBIAN/
dpkg-deb --build pzsvrtool/
mv -f pzsvrtool.deb "$workdir/build"
