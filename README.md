<div align="center">

# 🧰️ pzsvrtool

An lightweight terminal toolchain for running Project Zomboid on Linux Server
</div>

**Why pzsvrtool?**<br>Many PZ server tools uses docker, need rcons or simply don't survive a VPS reboot cleanly. pzsvrtool is built by a server owner, for server owners: no container, small backups and lightweight.

## ✅ Features
- Detects unlisted mod updates
- Stays running unless explicitly shut down
- Compressed backups up to 10x smaller than PZ's own zip
- Bootloop detection — avoids burning through backup slots on crash loops
- Real console experience: scrollable with Page Up/Down and arrow keys
- Restart/shutdown countdowns, with skip-if-recent-backup logic for cron
- Kicks players before restart/shutdown - PZ only saves when cells unload
- Guards against multiple PZ instances running at once
- Auto-backs up start-server.sh and ProjectZomboidXX.json on update, with revert option
- Discord webhook alerts: boot, shutdown, backup, restart, bootloop, mod update check status
- Graceful shutdown on unplanned reboot or shutdown (runs PZ as a systemd service)
- User password reset, zombie population reset, and more


## 🐧 Supported Platforms
Tested on Almalinux 9.8. Theorically the scripts should work in all linux enviroments as long the followings are met<details>
<summary>Dependencies</summary>
Should come installed with linux but just incase

- `bash`
- `procps`
- `findutils`
- `coreutils`
- `gawk`
- `util-linux`
- `tar`

Need to install

- `wget`
- `lz4`
- `python3`
- `python3-psutil`
- `python3-bcrypt`, dnf requires `epel-release` repo to install
- `sqlite` or `sqlite3`
- `tmux`
- SteamCMD dpendency varies slightly on distro. On apt is `lib32gcc-s1`. On dnf is `glibc.i686`. I don't know about `pacman` or `swupd`.

</details>

## 💻 Installations
**Fedora / RHEL / Rocky / AlmaLinux**
```bash
sudo dnf install epel-release glibc.i686
sudo dnf install <rpm file name>
```

**Debian / Ubuntu**
```bash
sudo apt-get install /tmp/<deb file name>
```

pzsvrtool won't run as root. Create a user first:
```bash
sudo useradd --create-home --shell /bin/bash <username>
sudo passwd <username>
sudo -i -u <username>
```

Then, as that user:
```bash
pzsvrtool install
pzsvrtool start
```

Graceful shutdown on host reboot. As root, run <br>`systemctl edit user@$(id -u <username>).service` and add:
```
[Service]
TimeoutStopSec=20m
```

## 🧐 General usage
The scripts should provide all basics you need to run a linux PZ server.
- If you need to do scheduled restart, you can add `* /12 * * *     pzsvrtool restart --backupgrace 120` to crontab schedule
- If you want to periodically check mod updates, you can add `*/10 * * * *    pzsvrtool checkmodupdate` to crontab schedule
- If you want to automatically start server after reboot, you can add `@reboot      sleep 60 && pzsvrtool start` to crontab schedule

## 📄 Commands
```
Usage: pzsvrtool <command> <arg> <options>
Commands list
install <flags>                           Install or update steam and Project Zomboid
      -j or --json                        Backup and restore the previous ProjectZomboidXX.json
      -s or --startserver                 Backup and restore the previous startserver.sh
      -l or --lib                         Backup and update the game steamclient library using steamcmd
start                                     Start the server
restart <arg> <option>                    Restart the server
      -t or --time <minutes>              Custom countdown time in minutes
      -b or --backupgrace <minutes>       Skip restart if compressed backup made in past X minutes, useful for crontab schedule
cancelrestart                             Cancel restarting the server
quit <arg> <option>                       Shutdown the server
      -t or --time <minutes>              Custom countdown time in minutes
cancelquit                                Cancel shutting down the server
console <flags>                           Open console to the log and commandline to server if any
      -c or --chatonly                    Show only game chats
consoleold                                Read-only console, if the modern console doesn't work for you
checkmodupdate                            Check and restart on mod update, useful for crontab schedule
message <message>                         Send admin message, useful for crontab schedule
command <command>                         Send any commands, useful for crontab schedule
updateusrpw <username> <new password>     Change user's password
backupnow                                 Backup Project Zomboid saves
resetzpop                                 Reset Project Zomboid zombie population
kill                                      Kill all zomboid server process
reconfig                                  Reconfigure settings
```

## 📂 Directories
```
/<home>/Zomboid         Where your PZ saves, backup, server settings are at. pzsvrtool will save its compressed backups at the backup folder.
/<home>/pzserver        PZ server software itself where you find ProjectZomboid64.json and start-server.sh and workshop mods
/<home>/pzsvrtool       Where you can find pzsvrtool config and hidden var file, should you want to edit your backup limit or server names etc.
/<home>/Steam           SteamCMD folder
```

## Check out my other useful guide!
[Project Zomboid Steam Guide > Linux Server: Java, Garbage Collector and Memory](https://steamcommunity.com/sharedfiles/filedetails/?id=3130670064)

[Project Zomboid Steam Guide > Linux Server: Firewall](https://steamcommunity.com/sharedfiles/filedetails/?id=3130996558)

## ❤️ Support the work
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Y8Y8CX2QA) <br>
I pretty much made this for a community server of mine which is totally community funded. If it went dead then I don't see a point in maintaining the script as well.