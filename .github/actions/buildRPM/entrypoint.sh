#!/usr/bin/bash
msg(){
    echo
    echo "==> $*"
    echo
}

free
df -h

msg "Updating container..."
dnf -y upgrade

msg "Installing prerequisites..."
dnf -y install rpm-build rpmdevtools

workdir=$(pwd)
echo $workdir
mkdir -p build
rpmdev-setuptree
cp -r SOURCES /github/home/rpmbuild
cp pzsvrtool.spec /github/home/rpmbuild/SPECS
rpmbuild -bb --target=x86_64 "/github/home/rpmbuild/SPECS/pzsvrtool.spec"
# rpmbuild -bb --target=armv7hl "/github/home/rpmbuild/SPECS/pzsvrtool.spec"
mv -f /github/home/rpmbuild/RPMS/x86_64/* "$workdir/build"
# mv -f /github/home/rpmbuild/RPMS/armv7hl/* "$workdir/build"