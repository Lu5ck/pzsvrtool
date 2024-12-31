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

    write_boot_log "Server has shutdown"
    # Delay 2s to make sure everything terminated
    sleep 2

    # We don't expect server to restart every 2 minutes thus assume it could be bootloop
    # A broken start_server.sh or ProjectZomboidxx.json or mod can cause bootloop
    # We also don't want it to keep backing up the same thing which will override the older backup due to backup limits
    if [[ $(($(date +%s)-${pzsvrtool_wrapper_startTime})) -ge 120 ]]; then
        if [[ ${backup}=="true" ]]; then
            write_boot_log "Backing up"
            backup_files
            write_boot_log "Backup done"
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
        logger -p user.err "[pzsvrtool] Project Zomboid server bootup stuck in loop. Server bootup halted."
        write_boot_log "Bootloop detected. Exiting"
        exit;
    elif [[ pzsvrtool_wrapper_retry -gt 0 ]]; then
        write_boot_log "Bootloot suspected - Retry attempt ${pzsvrtool_wrapper_retry}"
    fi
done

# Screen will close itself when this script stop