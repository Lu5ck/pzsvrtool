Name:           pzsvrtool
Version:        1.7.3
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
Source10:       pzsvrtool_gracefulstop.sh
Source11:       pzsvrtool@.service

Requires:       bash, procps, findutils, coreutils, gawk, util-linux, tar, wget, lz4, python3, python3-psutil, sqlite, tmux, python3-bcrypt, python3-aiohttp

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
install -m 0755 %{SOURCE10} %{buildroot}/usr/libexec/pzsvrtool
install -m 0755 %{SOURCE10} %{buildroot}/usr/libexec/pzsvrtool
mkdir -p %{buildroot}/usr/lib/systemd/user/
install -m 0644 %{SOURCE11} %{buildroot}/usr/lib/systemd/user/


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
/usr/libexec/pzsvrtool/pzsvrtool_gracefulstop.sh
/usr/lib/systemd/user/pzsvrtool@.service

%pre
if [ $1 -gt 1 ] ; then
    MIN_SAFE_UPGRADE_VERSION="1.7.0"
    installed_version=$(rpm -q --queryformat '%%{VERSION}' pzsvrtool 2>/dev/null || echo "")
    if [ -n "$installed_version" ]; then
        cmp_result=$(rpm --eval "%%{lua:
            print(rpm.vercmp('${installed_version}', '${MIN_SAFE_UPGRADE_VERSION}'))
        }")
        # cmp_result: -1 if installed < min, 0 if equal, 1 if installed > min
        if [ "$cmp_result" -lt 0 ]; then
            found_session=""
            for sockdir in /tmp/tmux-*; do
                [ -d "$sockdir" ] || continue
                uid="${sockdir#/tmp/tmux-}"
                owner=$(stat -c '%U' "$sockdir" 2>/dev/null)
                [ -n "$owner" ] || continue

                for sock in "$sockdir"/*; do
                    [ -S "$sock" ] || continue
                    sessions=$(sudo -u "$owner" tmux -S "$sock" list-sessions -F '#{session_name}' 2>/dev/null || true)
                    match=$(echo "$sessions" | grep '^pzsvrtool_' || true)
                    if [ -n "$match" ]; then
                        found_session="yes"
                        break 2
                    fi
                done
            done

            if [ -n "$found_session" ]; then
                echo "Error: A pzsvrtool-managed server (tmux session) is currently running." >&2
                echo "Stop the server before upgrading pzsvrtool." >&2
                exit 1
            fi
        fi
    fi
fi

%preun
if [ $1 -eq 0 ] ; then
    found_session=""
    for sockdir in /tmp/tmux-*; do
        [ -d "$sockdir" ] || continue
        owner=$(stat -c '%U' "$sockdir" 2>/dev/null)
        [ -n "$owner" ] || continue

        for sock in "$sockdir"/*; do
            [ -S "$sock" ] || continue
            sessions=$(runuser -u "$owner" -- tmux -S "$sock" list-sessions -F '#{session_name}' 2>/dev/null || true)
            match=$(echo "$sessions" | grep '^pzsvrtool_' || true)
            if [ -n "$match" ]; then
                found_session="yes"
                break 2
            fi
        done
    done

    if [ -n "$found_session" ]; then
        echo "Error: A pzsvrtool-managed server (tmux session) is currently running." >&2
        echo "Stop the server before uninstalling pzsvrtool." >&2
        exit 1
    fi
fi

%post
if ! rpm -q glibc.i686 >/dev/null 2>&1; then
    # Note: glibc.i686 will install libgcc.i686, libgcc.i686 alone is not enough unlike Debian package
    echo "Note: glibc.i686 is required for steamcmd, run dnf install glibc.i686"
fi

%changelog
* Wed Dec 25 2024 - 1.0.0
- Initial release
