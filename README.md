## 🧰️ pzsvrtool
Did you...
- thought that running a docker on that expensive VPS is so wasting on your already limited paid resources?
- suddenly thought of doing a shutdown on the current restart countdown so you can apply some quick changes?
- saw those huge backup zip files, thinking it did be nice to be smaller so you can have more on your already limited resources?
- Tried VPS with virtualization securities that prohibit you from using some PZ tools because it uses some fancy ways to detach and attach PZ?
- get annoyed that some PZ tools doesn't restart because it couldn't detect unlisted mods updates, mods that you don't want others to use?
- get annoyed that your scheduled restart occur right after a mod update restart?
- hate it that when you try to update Zomboid but some PZ tools don't help you backup nor restore the previous modified `.json` or `start-server.sh`?

Well, I do and I waited but these tools never get updated so I made my own, much easier and cleaner. All in all, pzsvrtool is made by server owner for server owners.

## 🐧 Supported Platforms
Tested on Almalinux 9.5. Theorically the scripts should work in all linux enviroments as long the followings are met<details>
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

## 🧐 General usage
The scripts should provide all basics you need to run a linux PZ server.
- If you need to do scheduled restart, you can add `pzsvrtool restart --backupgrace 120` to crontab schedule
- If you want to periodically check mod updates, you can add `pzsvrtool checkmodupdate` to crontab schedule

## ✅ Features
- Able to detect unlisted mod update
- Always running unless explicitly shutdown
- Compresed backup with up to 10x smaller than PZ zip, highly recommended to disable PZ backup
- Bootloop detection to prevent unnecessary compressed backups thus data losses due to backup limits
- Console that looks like the real deal while able to scroll with page up, page down, arrow up and arrow down
- Countdown for restart and shutdown
- Unnecessary scheduled restart prevention option
- Reliable linux utilities used to run PZ in background
- Kick players before restart or shutdown to minimize data loss from PZ poor saving mechanic
- Numerous checks to prevent multiple PZ instances
- Change user password
- Reset zombie population
- Auto backup start-server-sh and ProjectZomboidXX.json when updating PZ with option to auto revert them
- Supports discord webhook to be informed of bootup, shutdown, backup, restart, bootloop and checkmodsneedupdate status

## ❤️ Support the work
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Y8Y8CX2QA) <br>
I pretty much made this for a community server of mine which is totally community funded. If it went dead then I don't see a point in maintaining the script as well.

## 💻 Installations
For Fedora / RHEL / Rocky Linux / AlmaLinux, download RPM and run `sudo dnf install <rpm file name>` then run `sudo dnf install python3-bcrypt python3-aiohttp glibc.i686`, accept key if asked.

For Debian / Ubuntu, download DEB and place it in `/tmp` then run `sudo apt-get install /tmp/<deb file name>`.

You are not allowed to run this as root so do `sudo useradd --create-home --shell /bin/bash <username>` and `sudo passwd <username>` to set password. Do `sudo -i -u <username>` to quick switch from root to target user. In the new user account, do `pzsvrtool install` to install then `pzsvrtool start` to launch your server.

## 📄 Commands
```
Usage: pzsvrtool <command> <arg> <options>
Commands list
install <flags>                           Install or update steam and Project Zomboid
      -j or --json                        Backup and restore the previous ProjectZomboidXX.json
      -s or --startserver                 Backup and restore the previous startserver.sh
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
/<home>/pzserver        PZ server software itself where you find ProjectZomboid64.json and start-server.sh
/<home>/pzsvrtool       Where you can find pzsvrtool config and hidden var file, should you want to edit your backup limit or server names etc.
/<home>/steam           SteamCMD folder where the mods are at
```

## Check out my other useful guide!
[Project Zomboid Steam Guide > Linux Server: Java, Garbage Collector and Memory](https://steamcommunity.com/sharedfiles/filedetails/?id=3130670064)

[Project Zomboid Steam Guide > Linux Server: Firewall](https://steamcommunity.com/sharedfiles/filedetails/?id=3130996558)