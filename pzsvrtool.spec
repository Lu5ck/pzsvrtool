Name:           pzsvrtool
Version:        1.4.13
Release:        1%{?dist}
Summary:        Scripts to manage Project Zomboid Server

License:        GPLv2+
URL:            https://ko-fi.com/zomboidkwrr
Source0:        pzsvrtool_common.sh
Source1:        pzsvrtool_main.sh
Source2:        pzsvrtool_wrapper.sh
Source3:        pzsvrtool_console.py
Source4:        pzsvrtool_countdown_shutdown.py
Source5:        pzsvrtool
Source6:        pzsvrtool_common.py
Source7:        pzsvrtool_checkmodupdate.py
Source8:        pzsvrtool_updateusrpw.py
Source9:        pzsvrtool_checkserverstarted.py

Requires:       bash, procps, findutils, coreutils, gawk, util-linux, tar, wget, lz4, python3, python3-psutil, epel-release, sqlite, tmux

%description
Scripts to manage Project Zomboid Server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE5} %{buildroot}/usr/bin/pzsvrtool

mkdir -p %{buildroot}/usr/libexec/pzsvrtool
install -m 0644 %{SOURCE0} %{buildroot}/usr/libexec/pzsvrtool
install -m 0755 %{SOURCE1} %{buildroot}/usr/libexec/pzsvrtool
install -m 0755 %{SOURCE2} %{buildroot}/usr/libexec/pzsvrtool
install -m 0755 %{SOURCE3} %{buildroot}/usr/libexec/pzsvrtool
install -m 0755 %{SOURCE4} %{buildroot}/usr/libexec/pzsvrtool
install -m 0644 %{SOURCE6} %{buildroot}/usr/libexec/pzsvrtool
install -m 0755 %{SOURCE7} %{buildroot}/usr/libexec/pzsvrtool
install -m 0755 %{SOURCE8} %{buildroot}/usr/libexec/pzsvrtool
install -m 0755 %{SOURCE9} %{buildroot}/usr/libexec/pzsvrtool

%files
/usr/bin/pzsvrtool
/usr/libexec/pzsvrtool/pzsvrtool_common.sh
/usr/libexec/pzsvrtool/pzsvrtool_main.sh
/usr/libexec/pzsvrtool/pzsvrtool_wrapper.sh
/usr/libexec/pzsvrtool/pzsvrtool_console.py
/usr/libexec/pzsvrtool/pzsvrtool_countdown_shutdown.py
/usr/libexec/pzsvrtool/pzsvrtool_common.py
/usr/libexec/pzsvrtool/pzsvrtool_checkmodupdate.py
/usr/libexec/pzsvrtool/pzsvrtool_updateusrpw.py
/usr/libexec/pzsvrtool/pzsvrtool_checkserverstarted.py

%post
# Note: glibc.i686 will install libgcc.i686, libgcc.i686 alone is not enough unlike Debian package
echo "Manually install python3-bcrypt python3-aiohttp glibc.i686"

%changelog
* Wed Dec 25 2024 - 1.0.0
- Initial release
