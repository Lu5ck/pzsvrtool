#!/usr/bin/bash

source /usr/libexec/pzsvrtool/pzsvrtool_common.sh

# Called when doing fresh install
# Also called by reconfig thus the if else
config_setup() {
    # Prompt the user for input
    if [[ -z ${zomboidServerName} ]]; then
        prompt_non_empty zomboidServerName "Enter Zomboid Server Name: " "Zomboid Server Name"
    else
        prompt_non_empty zomboidServerName "Enter Zomboid Server Name [Current=${zomboidServerName}]: " "Zomboid Server Name"
    fi
    if [[ -z ${countdownTime} ]]; then
        prompt_non_empty_numeric countdownTime "Enter shutdown Countdown Time (in minutes): " "Countdown Time"
    else
        prompt_non_empty_numeric countdownTime "Enter shutdown Countdown Time (in minutes) [Current=${countdownTime}]: " "Countdown Time"
    fi
    if [[ -z ${backup} ]]; then
        prompt_non_empty_boolean backup "Enable Backup After Shutdown (y/n): " "Backup option"
    else
        if [[ ${backup} == "true" ]]; then
            local temp="y"
        else
            local temp="n"
        fi
        prompt_non_empty_boolean backup "Enable Backup After Shutdown (y/n) [Current=${temp}]: " "Backup option"
    fi
    if [[ -z ${backupLimit} ]]; then
        prompt_non_empty_numeric backupLimit "Enter maximum number of backups: " "Backup Limit"
    else
        prompt_non_empty_numeric backupLimit "Enter maximum number of backups [Current=${backupLimit}]: " "Backup Limit"
    fi
    if [[ -z ${discord_webhook_notice} ]]; then
        prompt_allow_empty_without_space_default discord_webhook_notice "Enter discord notice webhook, empty if none: " "Discord webhook URL"
    else
        echo "Current Webhook = ${discord_webhook_notice}"
        prompt_allow_empty_without_space_default discord_webhook_notice "Enter discord notice webhook, empty if no change: " "Discord webhook URL"
    fi
    if [[ -n ${pzRootAdmin} ]]; then
        prompt_non_empty pzRootAdmin "Enter root admin name [Current=${pzRootAdmin}]: " "Root Admin Name"
    fi

    if [[ ! -d ~/${configFolder} ]]; then
        mkdir ~/${configFolder}
    fi

    if [[ -f ~/${configFolder}/${configFile} ]]; then
        : > ~/${configFolder}/${configFile}
    fi

    if [[ ! -f ~/${configFolder}/${configFile} ]]; then
        touch ~/${configFolder}/${configFile}
    fi

    cfg_write ~/${configFolder}/${configFile} zomboidServerName ${zomboidServerName}
    cfg_write ~/${configFolder}/${configFile} countdownTime ${countdownTime}
    cfg_write ~/${configFolder}/${configFile} backup ${backup}
    cfg_write ~/${configFolder}/${configFile} backupLimit ${backupLimit}
    cfg_write ~/${configFolder}/${configFile} discord_webhook_notice ${discord_webhook_notice}
    
    if [[ -n ${pzRootAdmin} ]]; then
        cfg_write ~/${configFolder}/${configFile} pzRootAdmin ${pzRootAdmin}
    fi

    # Confirm completion
    echo "[pzsvrtool] Configuration saved to ${HOME}/${configFolder}/${configFile}"
}

install_steam() {
    # steamcmd required libraries
    if command -v rpm &>/dev/null; then
        if ! rpm -q glibc.i686 &>/dev/null; then
            echo "[pzsvrtool] glibc.i686 is NOT installed."
            exit
        fi
    elif command -v dpkg-query &>/dev/null; then
        if ! dpkg-query -l lib32gcc-s1 &>/dev/null; then
            echo "[pzsvrtool] lib32gcc-s1 is NOT installed."
            exit
        fi
    fi

    check_config
    exit_if_has_pz
    exit_if_has_pzscreen

    if [[ -n "${@}" ]]; then
        parse_args_install "${@}"
    fi

    echo "[pzsvrtool] See https://steamdb.info/app/108600/depots/ for branches"
    prompt_non_empty zomboidBranch "[pzsvrtool] Install what branch: " "Branch"

    # Backup old files, if any
    if [[ -f ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json ]]; then
        mv -f ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json.old
    fi

    if [[ -f ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json ]]; then
        mv -f ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json.old
    fi

    if [[ -f ~/${zomboidCoreServerFolderName}/start-server.sh ]]; then
        mv -f ~/${zomboidCoreServerFolderName}/start-server.sh ~/${zomboidCoreServerFolderName}/start-server.sh.old
    fi

    # Check for steamcmd before downloading again
    if [[ ! -f ~/${steamFolderName}/steamcmd.sh ]]; then
        echo "[pzsvrtool] Downloading & Extracting SteamCMD"
        wget -q ${steamCmdUrl} && mkdir ~/${steamFolderName} && tar -xzf steamcmd_linux.tar.gz -C ${steamFolderName} && rm -f steamcmd_linux.tar.gz
    fi

    bash ~/${steamFolderName}/steamcmd.sh +force_install_dir ~/${zomboidCoreServerFolderName}/ +login anonymous +app_update 380870 ${zomboidBranch} validate +quit

    # Restore json if flag
    if [[ -n ${installJson} ]]; then
        if [[ -f ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json && -f ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json.old ]]; then
            mv -f ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json.original
            mv -f ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json.old ~/${zomboidCoreServerFolderName}/ProjectZomboid64.json
        fi

        if [[ -f ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json && -f ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json.old ]]; then
            mv -f ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json.original
            mv -f ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json.old ~/${zomboidCoreServerFolderName}/ProjectZomboid32.json
        fi
    fi

    # Restore start-server if flag
    if [[ -n ${installStartServer} ]]; then
        if [[ -f ~/${zomboidCoreServerFolderName}/start-server.sh && -f ~/${zomboidCoreServerFolderName}/start-server.sh.old ]]; then
            mv -f ~/${zomboidCoreServerFolderName}/start-server.sh ~/${zomboidCoreServerFolderName}/start-server.sh.original
            mv -f ~/${zomboidCoreServerFolderName}/start-server.sh.old ~/${zomboidCoreServerFolderName}/start-server.sh
        fi
    fi

    echo "[pzsvrtool] Installation Completed"
}

start_server() {
    exit_if_no_tmux
    exit_if_no_common_python_module
    check_config
    exit_if_has_pz
    exit_if_has_pzscreen

    # Project Zomboid always ask for an ingame root admin, we need to supply it
    if [[ -z "${pzRootAdmin}" ]]; then
        prompt_non_empty pzRootAdmin "Enter root admin name: " "Root Admin Name"
        cfg_write ~/${configFolder}/${configFile} pzRootAdmin ${pzRootAdmin}
    fi

    # Reset the flag
    cfg_write ~/${configFolder}/${varFile} "shutdown" "false"

    # Check if root admin exist, if not, prompt password and run with its password
    if [[ $(sql_query ~/"${zomboidServerFolderName}/db/${zomboidServerName}.db" "SELECT username FROM whitelist WHERE id = 1;") != "${pzRootAdmin}" ]]; then
        prompt_password
        tmux new-session -d -s "pzsvrtool_${zomboidServerName}" /usr/libexec/pzsvrtool/pzsvrtool_wrapper.sh ${pzRootAdmin} ${pzRootAdmin_password}
    else
        tmux new-session -d -s "pzsvrtool_${zomboidServerName}" /usr/libexec/pzsvrtool/pzsvrtool_wrapper.sh ${pzRootAdmin}
    fi
    

    echo "[pzsvrtool] start command executed"
}

# Accept numeric arugment, to do custom countdown
quit_server() {
    exit_if_no_tmux
    exit_if_no_common_python_module
    check_config
    exit_if_no_pz
    exit_if_no_pzscreen

    # Parse the arguments
    if [[ -n "${@}" ]]; then
        parse_args_quit "${@}"
    fi

    # Check numeric and valid range
    if [[ -n "${customMinutes}" && (! "${customMinutes}" =~ ^[0-9]+$ || "${customMinutes}" -le 0) ]]; then
        echo "[pzsvrtool] Invalid time, only positive integer"
        exit
    fi

    if [[ "$(is_shutdown_screen_active)" == "true" ]]; then # If countdown already running
        local temp=$(cfg_read ~/${configFolder}/${varFile} shutdown) # Read flag to see if restart or shutdown mode
        if [[ ${temp} == "false" ]]; then # Change mode accordingly
            cfg_write ~/${configFolder}/${varFile} "shutdown" "true"
            if [[ ${1} ]]; then # Change time if any
                tmux send-keys -t "pzsvrtool_$(id -u)_shutdown" "updatetime ${customMinutes}" C-m
                echo "[pzsvrtool] There's already an restart task, changing to shutdown mode"
                echo "[pzsvrtool] Countdown modified to ${customMinutes} minutes"
            else
                echo "[pzsvrtool] There's already an restart task, changing to shutdown mode"
            fi
        else
            if [[ ${1} ]]; then # Change time if any
                tmux send-keys -t "pzsvrtool_$(id -u)_shutdown" "updatetime ${customMinutes}" C-m
                echo "[pzsvrtool] Countdown modified to ${customMinutes} minutes"
            else
                echo "[pzsvrtool] There's already an shutdown task"
            fi
        fi
        exit
    fi

    cfg_write ~/${configFolder}/${varFile} "shutdown" "true" # We shutting down thus indicate the flag
    if [[ -z ${1} ]]; then # If we have custom timing
        tmux new-session -d -s "pzsvrtool_$(id -u)_shutdown" "python3 /usr/libexec/pzsvrtool/pzsvrtool_countdown_shutdown.py -minutes ${countdownTime}"
        echo "[pzsvrtool] quit command executed. Server shutting down in ${countdownTime} minutes"
    else
        tmux new-session -d -s "pzsvrtool_$(id -u)_shutdown" "python3 /usr/libexec/pzsvrtool/pzsvrtool_countdown_shutdown.py -minutes ${customMinutes}"
        echo "[pzsvrtool] quit command executed. Server shutting down in ${customMinutes} minutes"
    fi
}

# Accept numeric arugment, to do custom countdown
restart_server() {
    exit_if_no_tmux
    exit_if_no_common_python_module
    check_config
    exit_if_no_pz
    exit_if_no_pzscreen

    # Parse the arguments
    if [[ -n "${@}" ]]; then
        parse_args_restart "${@}"
    fi

    # Check numeric and valid range
    if [[ -n "${customMinutes}" && (! "${customMinutes}" =~ ^[0-9]+$ || "${customMinutes}" -le 0) ]]; then
        echo "[pzsvrtool] Invalid time, only positive integer"
        exit
    fi

    # Check numeric and valid range
    if [[ -n "${backupGrace}" && (! "${backupGrace}" =~ ^[0-9]+$ || "${backupGrace}" -le 0) ]]; then
        echo "[pzsvrtool] Invalid backupgrace, only positive integer"
        exit
    fi

    # This flag is used to skip restart if last backup is within X minutes, useful for scheduled restart
    if [[ -n "${backupGrace}" ]]; then
        if [[ -z $(get_newest_backup_time) ]]; then # If no backup
            :
        elif [[ "$(( $(date +%s) - $(get_newest_backup_time) ))" -lt "$(( ${backupGrace} * 60 ))" ]]; then
            echo "[pztoolbox] Backup detected within ${backupGrace} minutes, skipping restart"
            exit # Backup found within X minutes, so we don't restart
        fi
    fi

    if [[ "$(is_shutdown_screen_active)" == "true" ]]; then If countdown already running
        local temp=$(cfg_read ~/${configFolder}/${varFile} shutdown) # Read flag to see if restart or shutdown mode
        if [[ ${temp} == "false" ]]; then # Change mode accordingly
            if [[ ${1} ]]; then # Change time if any
                tmux send-keys -t "pzsvrtool_$(id -u)_shutdown" "updatetime ${customMinutes}" C-m
                echo "[pzsvrtool] Countdown modified to ${customMinutes} minutes"
            else
                echo "[pzsvrtool] There's already an restart task"
            fi
        else
            cfg_write ~/${configFolder}/${varFile} "shutdown" "false"
            if [[ ${1} ]]; then # Change time if any
                tmux send-keys -t "pzsvrtool_$(id -u)_shutdown" "updatetime ${customMinutes}" C-m
                echo "[pzsvrtool] There's already an shutdown task, changing to restart mode"
                echo "[pzsvrtool] Countdown modified to ${customMinutes} minutes"
            else
                echo "[pzsvrtool] There's already an shutdown task, changing to restart mode"
            fi
        fi
        exit
    fi

    if [[ -z ${customMinutes} ]]; then # If we have custom timing
        tmux new-session -d -s "pzsvrtool_$(id -u)_shutdown" "python3 /usr/libexec/pzsvrtool/pzsvrtool_countdown_shutdown.py -minutes ${countdownTime}"
        echo "[pzsvrtool] restart command executed. Server restarting in ${countdownTime} minutes."
    else
        tmux new-session -d -s "pzsvrtool_$(id -u)_shutdown" "python3 /usr/libexec/pzsvrtool/pzsvrtool_countdown_shutdown.py -minutes ${customMinutes}"
        echo "[pzsvrtool] restart command executed. Server restarting in ${customMinutes} minutes."
    fi
}

cancel_shutdown() {
    exit_if_no_tmux
    check_config
    exit_if_no_pz
    exit_if_no_pzscreen

    if [[ "$(is_shutdown_screen_active)" == "false" ]]; then
		echo "[pzsvrtool] No task found"
        exit
    fi

    cfg_write ~/${configFolder}/${varFile} "shutdown" "false"
    tmux send-keys -t "pzsvrtool_$(id -u)_shutdown" "stop" C-m

    echo "[pzsvrtool] cancel command executed"
}

backupNow() {
    check_config
    exit_if_has_pz
    exit_if_has_pzscreen

    echo "[pzsvrtool] Executing command. Please wait"
    if [[ $(backup_files) == "false" ]]; then
        echo "[pzsvrtool] Detected ongoing backup. Command not executed"
    else
        echo "[pzsvrtool] Backup completed"
    fi
}

console() {
    exit_if_no_common_python_module
    check_config

    if [[ -n "${@}" ]]; then
        parse_args_console "${@}"
    fi

    if [[ -f "${HOME}/${zomboidServerFolderName}/server-console.txt" ]]; then
        if [[ -n ${chatonly} ]]; then
            python3 /usr/libexec/pzsvrtool/pzsvrtool_console.py --tail "${HOME}/${zomboidServerFolderName}/server-console.txt ${chatonly}"
        else
            python3 /usr/libexec/pzsvrtool/pzsvrtool_console.py --tail "${HOME}/${zomboidServerFolderName}/server-console.txt"
        fi
    else
        echo "[pzsvrtool] server-console.txt not found"
        exit
    fi
}

# Old school tail, incase the python console doesn't work
consoleold() {
    check_config

    if [[ -f "${HOME}/${zomboidServerFolderName}/server-console.txt" ]]; then
        tail -f -n "200" "${HOME}/${zomboidServerFolderName}/server-console.txt"
    else
        echo "[pzsvrtool] server-console.txt not found"
        exit
    fi
}

updateusrpw() {
    exit_if_no_common_python_module
    if command -v rpm &>/dev/null; then
        if ! rpm -q python3-bcrypt &>/dev/null; then
            echo "[pzsvrtool] python3-bcrypt is NOT installed."
            exit
        fi
    elif command -v dpkg-query &>/dev/null; then
        if ! dpkg-query -l python3-bcrypt &>/dev/null; then
            echo "[pzsvrtool] python3-bcrypt is NOT installed."
            exit
        fi
    fi
    check_config
    if [[ $(sql_query ~/"${zomboidServerFolderName}/db/${zomboidServerName}.db" "SELECT id FROM whitelist WHERE username = \"${1}\";") ]]; then
        python3 /usr/libexec/pzsvrtool/pzsvrtool_updateusrpw.py -username ${1} -password ${2}
        echo "[pzsvrtool] Password changed for ${1} "
    else
        echo "[pzsvrtool] ${1} not found"
    fi
}

# Doesn't work, doesn't make sense
# While you can change the username, the character share the same name as the username thus it doesn't make sense.
# You also cannot change the character name while the server is running
updateusrname() {
    check_config

    if [[ $(sql_query ~/"${zomboidServerFolderName}/db/${zomboidServerName}.db" "SELECT id FROM whitelist WHERE username = \"${1}\";") ]]; then
        local id=$(sql_query ~/"${zomboidServerFolderName}/db/${zomboidServerName}.db" "SELECT id FROM whitelist WHERE username = \"${1}\";")
        sql_query ~/"${zomboidServerFolderName}/db/${zomboidServerName}.db" "UPDATE whitelist SET username = \"${2}\" WHERE id = \"${id}\";"
        echo "[pzsvrtool] Username ${1} changed to ${2} "
    else
        echo "[pzsvrtool] ${1} not found"
    fi
}

checkmodupdate() {
    check_config
    exit_if_no_pz
    exit_if_no_pzscreen

    if pgrep -u $(id -u) -fa "pzsvrtool_checkmodupdate.py" > /dev/null; then
        echo "[pzsvrtool] checkmodupdate already running"
        exit
    fi

    if [[ $(python3 /usr/libexec/pzsvrtool/pzsvrtool_checkmodupdate.py) == "true" ]]; then
        if [[ "$(is_shutdown_screen_active)" == "true" ]]; then
            echo "[pzsvrtool] Mod update detected, countdown already in process"
        else
            echo "[pzsvrtool] Mod update detected, executing restart command"
            send_message "Mod update detected"
            send_discord_webhook "Mod update detected"
            restart_server
        fi
    else
        echo "[pzsvrtool] No update found"
    fi
}

# Useful for scheduled announcement
send_message() {
    exit_if_no_tmux
    check_config
    exit_if_no_pz
    exit_if_no_pzscreen

    tmux send-keys -t "pzsvrtool_${zomboidServerName}" "servermsg \"$*\"" C-m
}

# Useful for scheduled tasks
send_command() {
    exit_if_no_tmux
    check_config
    exit_if_no_pz
    exit_if_no_pzscreen

    tmux send-keys -t "pzsvrtool_${zomboidServerName}" "$*" C-m
}

# Yes, you can reset zpop even if server running, I did it many times
resetzpop() {
    check_config

    if [[ ! -d ~/"${zomboidServerFolderName}/Saves/Multiplayer/${zomboidServerName}" ]]; then
        echo "[pzsvrtool] Saves directory not found"
        exit
    fi

    prompt_non_empty_boolean bResetZPop "[pzsvrtool] Confirm Reset Z Pop? (y/n): " "ResetZ Confirmation"

    if [[ "${bResetZPop}" == "false" ]]; then
        exit
    else
        find ~/"${zomboidServerFolderName}/Saves/Multiplayer/${zomboidServerName}" -type f -name 'zpop_[0-9]*_[0-9]*.bin' -print -exec rm -f {} \;
    fi
}

kill() {
    check_config
    exit_if_no_pz

    prompt_non_empty_boolean bKill "[pzsvrtool] Confirm kill all PZ processes? (y/n): " "Kill Confirmation"

    if [[ "${bKill}" == "false" ]]; then
        :
    else
        # Since you killed it, I assume there's something wrong thus shutdown for good
        cfg_write ~/${configFolder}/${varFile} "shutdown" "true"
        pkill -9 -u "$(id -un)" -f "ProjectZomboid" # Kill all that match the name
        logger -p user.info "[pzsvrtool] User has killed Project Zomboid server processes"
        echo "[pzsvrtool] Kill command executed"
    fi
}

if declare -f "$1" > /dev/null; then
    "$1" "${@:2}"
else
    exit 1
fi