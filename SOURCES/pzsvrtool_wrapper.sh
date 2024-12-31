#!/bin/bash

# Wrapper for ProjectZomboid executable
# By running through this shell script, we can be informed if the executable is stopped or not

# Detached screen should be non-interactive
if [[ $- == *i* ]]; then
    echo "[pzsvrtool] Do not run this directly"
    exit
fi

source /usr/libexec/pzsvrtool/pzsvrtool_common.sh

pzsvrtool_wrapper_startTime=$(date +%s)
pzsvrtool_wrapper_retry=0
while true; do

    if [[ $(get_pzInstance) != "false" ]]; then
        echo "[pzsvrtool] Server is already running"
        exit;
    fi

    send_discord_webhook "Server is booting up, please wait"
    write_boot_log "Server is booting up"

    # Flag to know if is safe shutdown or not. We change this flag at launch and during controlled shutdown
    cfg_write ~/${configFolder}/${varFile} "safeShutdown" "false"

	if [[ "${1}" && "${2}" ]]; then
		bash ~/${zomboidCoreServerFolderName}/start-server.sh -servername "${zomboidServerName}" -adminusername "${1}" -adminpassword "${2}"
        # Get rid of $2 as we are done with this
        shift
    else
        bash ~/${zomboidCoreServerFolderName}/start-server.sh -servername "${zomboidServerName}" -adminusername "${1}"
	fi

    send_discord_webhook "Server has shutdown"
    write_boot_log "Server has shutdown"
    # Delay 2s to make sure everything terminated
    sleep 2

    # We don't expect server to restart every 2 minutes thus assume it could be bootloop
    # A broken start_server.sh or ProjectZomboidxx.json or mod can cause bootloop
    # We also don't want it to keep backing up the same thing which will override the older backup due to backup limits
    if [[ $(($(date +%s)-${pzsvrtool_wrapper_startTime})) -ge 120 ]]; then
        if [[ ${backup}=="true" ]]; then
            if [[ $(cfg_read ~/${configFolder}/${varFile} safeShutdown) == "true" ]]; then
                send_discord_webhook "Safe shutdown detected, backing up"
                write_boot_log "Safe shutdown detected, backing up"
            else
                send_discord_webhook "Adnormal shutdown detected, backing up"
                write_boot_log "Adnormal shutdown detected, backing up"
            fi
            backup_files
            send_discord_webhook "Backup completed"
            write_boot_log "Backup completed"
            sleep 2
        fi
        pzsvrtool_wrapper_retry=0
    else
        let "pzsvrtool_wrapper_retry=pzsvrtool_wrapper_retry+1"
    fi
    pzsvrtool_wrapper_startTime=$(date +%s)

    # If shutdown command is issued, we will exit the screen instead of keep booting it up
    if [[ $(cfg_read ~/${configFolder}/${varFile} shutdown) == "true" ]]; then
        exit;
    fi

    # We stop if retried more than 3 times
    if [[ pzsvrtool_wrapper_retry -gt 3 ]]; then
        send_discord_webhook "Bootloop detected, bootup attempt halted"
        write_boot_log "Bootloop detected. bootup attempt halted"
        logger -p user.err "[pzsvrtool] Project Zomboid server bootup stuck in loop. Server bootup halted."
        exit;
    elif [[ pzsvrtool_wrapper_retry -gt 0 ]]; then
        send_discord_webhook "Bootloop suspected - Retry attempt ${pzsvrtool_wrapper_retry}"
        write_boot_log "Bootloop suspected - Retry attempt ${pzsvrtool_wrapper_retry}"
    fi
done

# Screen will close itself when this script stop