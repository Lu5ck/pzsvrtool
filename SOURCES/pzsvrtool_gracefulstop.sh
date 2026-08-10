#!/bin/bash

source /usr/libexec/pzsvrtool/pzsvrtool_common.sh

exit_if_no_tmux
exit_if_no_common_python_module
check_config
exit_if_no_pz
exit_if_no_pzscreen

tmux send-keys -t "pzsvrtool_${zomboidServerName}" "servermsg \"Unplanned shutdown\"" C-m
send_discord_webhook "Unplanned shutdown"
cfg_write ~/${configFolder}/${varFile} "shutdown" "true"
python3 /usr/libexec/pzsvrtool/pzsvrtool_countdown_shutdown.py -minutes 3 -noinput

elapsed=0
while [[ "$(get_pzInstance)" != "false" ]]; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [ "$elapsed" -ge 120 ]; then
        cfg_write ~/${configFolder}/${varFile} "safeShutdown" "false"
        pkill -9 -u "$(id -un)" -f "ProjectZomboid" # Kill all that match the name
    fi
done

elapsed=0
while tmux has-session -t "pzsvrtool_${zomboidServerName}" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
done