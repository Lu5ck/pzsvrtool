#!/bin/bash

if [[ $- == *i* ]]; then
	echo "[pzsvrtool] Do not run this directly"
	exit
fi

# Easy functions to read and save value-key pair style
sed_escape() {
	sed -e "s/[]\/$*.^[]/\\&/g"
}

cfg_write() { # path, key, value
	cfg_delete "$1" "$2"
	echo "$2=$3" >> "$1"
}

cfg_read() { # path, key -> value
	test -f "$1" && grep "^$(echo "$2" | sed_escape)=" "$1" | sed "s/^$(echo "$2" | sed_escape)=//" | tail -1
}

cfg_delete() { # path, key
	test -f "$1" && sed -i "/^$(echo $2 | sed_escape).*$/d" "$1"
}

cfg_haskey() { # path, key
	test -f "$1" && grep "^$(echo "$2" | sed_escape)=" "$1" > /dev/null
}

# DO NOT MODIFY
# Easier to hardcode this than to let user modify this
# Just too lazy to think about storing this to file while python needing to access the said file
configFolder="pzsvrtool"
configFile="pzsvrtool.config"
varFile=".varfile"
steamCmdUrl="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
steamFolderName="Steam"
zomboidCoreServerFolderName="pzserver"
zomboidServerFolderName="Zomboid"
backupDir="${HOME}/${zomboidServerFolderName}/backups/compressed"

# The only thing that users can modify which are stored into the config file
if [ -f ~/${configFolder}/${configFile} ]; then
	zomboidServerName=$(cfg_read ~/${configFolder}/${configFile} zomboidServerName)
	countdownTime=$(cfg_read ~/${configFolder}/${configFile} countdownTime)
	backup=$(cfg_read ~/${configFolder}/${configFile} backup)
	backupLimit=$(cfg_read ~/${configFolder}/${configFile} backupLimit)
	pzRootAdmin=$(cfg_read ~/${configFolder}/${configFile} pzRootAdmin)
	discord_webhook_notice=$(cfg_read ~/${configFolder}/${configFile} discord_webhook_notice)
fi

# Function to prompt and allow empty input without space
prompt_allow_empty_without_space_default() {
    local input
    while true; do
        read -p "${2}" input
        if [[ "${input}" =~ [[:space:]] ]]; then
            echo "[pzsvrtool] ${3} cannot contain spaces. Please try again."
        else
			if [[ -n ${input} ]]; then
				eval "${1}=\"${input}\""
			fi
            break
        fi
    done
}

# Function to prompt and validate non-empty input
prompt_non_empty() {
    local input
    while true; do
        read -p "${2}" input
        # Check if input is not empty and does not contain spaces
        if [[ -n "${input}" && ! "${input}" =~ [[:space:]] ]]; then
            eval "${1}=\"${input}\""
            break
        elif [[ -z "${input}" ]]; then
            echo "[pzsvrtool] ${3} cannot be empty. Please try again."
        else
            echo "[pzsvrtool] ${3} cannot contain spaces. Please try again."
        fi
    done
}

# Function to prompt and validate numeric input
prompt_non_empty_boolean() {
	local input
	while true; do
		read -p "${2}" input
		case ${input} in
			[Yy]* ) eval "${1}=true"; break;;
			[Nn]* ) eval "${1}=false"; break;;
			* ) echo "[pzsvrtool] ${3} must be y or n. Please try again.";;
		esac
	done
}

# Function to prompt and validate numeric input
prompt_non_empty_numeric() {
	local input
	while true; do
		read -p "${2}" input
		if [ -z "${input}" ]; then
			echo "[pzsvrtool] ${3} cannot be empty. Please try again."
		elif [[ "${input}" =~ ^[0-9]+$ ]]; then
			eval "${1}=\"${input}\""
			break
		else
			echo "[pzsvrtool] ${3} must be a numeric value. Please try again."
		fi
	done
}

# This don't play nice with local variable thus don't call this with local variable as return
prompt_password() {

	while true; do
		# Prompt for the first password
		read -sp "[pzsvrtool] Enter your password: " password1
		echo

        # Check if the password is empty or contains spaces
        if [[ -z "$password1" ]]; then
            echo "[pzsvrtool] Password cannot be empty. Please try again."
            continue
        elif [[ "$password1" =~ [[:space:]] ]]; then
            echo "[pzsvrtool] Password cannot contain spaces. Please try again."
            continue
        fi

        # Prompt for the password confirmation
        read -sp "[pzsvrtool] Confirm your password: " password2
		echo

        # Check if passwords match
        if [[ "$password1" == "$password2" ]]; then
            break
        else
            echo "[pzsvrtool] Passwords do not match. Please try again."
        fi
    done
	
	pzRootAdmin_password="${password1}"
}

# Incase user modify the config file wrongly
check_config() {
	if [[ ! -f ~/${configFolder}/${configFile} ]]; then
		echo "[pzsvrtool] Missing config file, setting up config"
		config_setup
	fi

	local line_number=0
	while IFS= read -r line || [[ -n "${line}" ]]; do
		line_number=$((line_number + 1))

		# Check if the line contains "="
		if [[ "${line}" != *"="* ]]; then
			echo "[pzsvrtool] Error: Missing "=" in config file at line $line_number: $line"
			exit 1
		fi

		# Check if the line starts or ends with "="
		if [[ "${line}" =~ ^= ]]; then
			echo "[pzsvrtool] Error: Invalid formatting in config file at line $line_number: $line"
			exit 1
		fi

		# Check for valid key names (alphanumeric + underscores)
		if [[ ! "${line}" =~ ^[a-zA-Z0-9_]+=[^=]*$ ]]; then
			echo "[pzsvrtool] Error: Invalid key-value format in config file at line $line_number: $line"
			exit 1
		fi
	done < ~/${configFolder}/${configFile}

	if [[ -z ${zomboidServerName} ]]; then
		prompt_non_empty zomboidServerName "Enter Zomboid Server Name: " "Zomboid Server Name"
		cfg_write ~/${configFolder}/${configFile} zomboidServerName ${zomboidServerName}
	fi

	if [[ -z ${countdownTime} ]]; then
		prompt_non_empty_numeric countdownTime "Enter shutdown Countdown Time (in minutes): " "Countdown Time"
		cfg_write ~/${configFolder}/${configFile} countdownTime ${countdownTime}
	fi

	if [[ -z ${backup} ]]; then
		prompt_non_empty_boolean backup "Enable Backup After Shutdown (y/n): " "Backup option"
		cfg_write ~/${configFolder}/${configFile} backup ${backup}
	fi

	if [[ -z ${backupLimit} ]]; then
		prompt_non_empty_numeric backupLimit "Enter maximum number of backups: " "Backup Limit"
		cfg_write ~/${configFolder}/${configFile} backupLimit ${backupLimit}
	fi
}

get_pzInstance() {
	local pzPID=$(pgrep -u $(id -un) -f ProjectZomboid)
	if [ -z "${pzPID}" ]; then
		echo "false"
	else
		echo ${pzPID}
	fi
}

exit_if_has_pz() {
	if [[ "$(get_pzInstance)" != "false" ]]; then
		echo "[pzsvrtool] Server is running, cannot execute command"
		exit
	fi
}

exit_if_no_pz() {
	if [[ "$(get_pzInstance)" == "false" ]]; then
		echo "[pzsvrtool] Server not found, cannot execute command"
		exit
	fi
}

exit_if_has_pzscreen() {
	if tmux has-session -t "pzsvrtool_${zomboidServerName}" 2>/dev/null; then
		# Return 0 or blank if has screen
		echo "[pzsvrtool] PZ screen found, check if backup is running, cannot execute command"
		exit
	else
		:
	fi
}

exit_if_no_pzscreen() {
	if tmux has-session -t "pzsvrtool_${zomboidServerName}" 2>/dev/null; then
		# Return 0 or blank if has screen
		:
	else
		echo "[pzsvrtool] PZ screen not found, cannot execute command"
		exit
	fi
}

exit_if_no_tmux() {
    # Incase users installed this not via installer
    if command -v rpm &>/dev/null; then
        if ! rpm -q tmux &>/dev/null; then
            echo "[pzsvrtool] tmux is NOT installed."
            exit
        fi
    elif command -v dpkg-query &>/dev/null; then
        if ! dpkg-query -l tmux &>/dev/null; then
            echo "[pzsvrtool] tmux is NOT installed."
            exit
        fi
    fi
}

exit_if_no_common_python_module() {
    if command -v rpm &>/dev/null; then
        if ! rpm -q python3-psutil &>/dev/null; then
            echo "[pzsvrtool] python3-psutil is NOT installed."
            exit
        fi
    elif command -v dpkg-query &>/dev/null; then
        if ! dpkg-query -l python3-psutil &>/dev/null; then
            echo "[pzsvrtool] python3-psutil is NOT installed."
            exit
        fi
    fi

    if command -v rpm &>/dev/null; then
        if ! rpm -q python3-aiohttp &>/dev/null; then
            echo "[pzsvrtool] python3-aiohttp is NOT installed."
            exit
        fi
    elif command -v dpkg-query &>/dev/null; then
        if ! dpkg-query -l python3-aiohttp &>/dev/null; then
            echo "[pzsvrtool] python3-aiohttp is NOT installed."
            exit
        fi
    fi
}

# Not tested, don't use
get_pzScreenID() {
	tmux list-sessions -F "#{session_name}" | while read -r session; do
		tmux list-panes -t "${session}" -F "#{pane_index}" | while read -r pane; do
			OUTPUT=$(tmux capture-pane -t "${session}.${pane}" -p -S -100)
			if echo "${output}" | grep -q "pzsvrtool_wrapper"; then
				echo ${session}
			fi
		done
	done
}

is_shutdown_screen_active() {
	if tmux has-session -t "pzsvrtool_$(id -u)_shutdown" 2>/dev/null; then
		echo "true"
	else
		echo "false"
	fi
}

sql_query() {
	# $1 is db_path $2 is query
	if [[ -z "${1}" || -z "${2}" ]]; then
		return 1
	fi

	if [[ ! -f "${1}" ]]; then
		return 1
	fi
	
	# It will execute and display the result
	sqlite3 "${1}" "${2}"
}

backup_files() {
	local pzBackup=$(pgrep -u $(id -un) -f "tar --ignore-failed-read --warning=no-all -chf.*Zomboid")
	if [ -n "${pzBackup}" ]; then
		echo "false"
		return
	fi

	mkdir -p "${backupDir}"
	local filename=""

	# Where we read the safeShutdown and have the filename named accordingly
	if [[ $(cfg_read ~/${configFolder}/${varFile} safeShutdown) == "true" ]]; then
		filename=$(date +%Y%m%d-%H%M%S).tar.lz4
	else
		filename=$(date +%Y%m%d-%H%M%S)_abnormal.tar.lz4
	fi

	# --ignore-failed-read is very important, ignore files/folders that don't exist
	tar --ignore-failed-read --warning=no-all -chf - ~/"${zomboidServerFolderName}/Saves" ~/"${zomboidServerFolderName}/Server" ~/"${zomboidServerFolderName}/Lua" ~/"${zomboidServerFolderName}/db" | lz4 > "${backupDir}/${filename}"

	# Count backups
	file_count=$(find "${backupDir}" -type f -name "*.tar.lz4" | wc -l)

	# Delete oldest backups if exceed limit
	if [ "${file_count}" -gt "${backupLimit}" ]; then
		# Find .tar.lz4 files, sort by modification time (oldest first), and delete the extras
		find "${backupDir}" -type f -name "*.tar.lz4" -printf '%T@ %p\n' | \
		sort -n | \
		head -n "$((file_count - ${backupLimit}))" | \
		awk '{print $2}' | \
		xargs -d '\n' rm -f
	fi
}

get_newest_backup_time() {
	mkdir -p "${backupDir}"
	echo $(find "${backupDir}" -type f -name "*.tar.lz4" -printf '%T@ %p\n' | sort -nr | head -n 1 | awk '{print int($1)}')
}

write_boot_log() {
    local message="$1"
    local timestamp
    timestamp=$(date "+[%s] [%d-%b-%Y %H:%M]") # Format date and Unix time
	if [[ ! -f ~/${configFolder}/boot_log.txt ]]; then
		touch ~/${configFolder}/boot_log.txt
	fi
    echo "${timestamp} ${message}" >> ~/${configFolder}/boot_log.txt
	shift
}

send_discord_webhook() {
	if [[ -n ${discord_webhook_notice} ]]; then
		curl -f -H "Content-Type: application/json" \
			-X POST \
			-d "{\"content\": \"${1}\"}" \
			"${discord_webhook_notice}"
	fi
}

customMinutes=""
backupGrace=""

parse_args_restart() {
	# -o = short
	# --long = long flag
	# : after flag means mandatory argument
	# :: after flag means optional arguement

	parsed_args=$(getopt -o t:b: --long time:,backupgrace: -n "pzsvrtool" -- "${@}")
	if [[ $? -ne 0 ]]; then
		exit 1
	fi

	eval set -- "${parsed_args}"

	while [ $# -gt 0 ]; do
		case "${1}" in
			-t|--time)
				customMinutes="${2}"
				shift 2
				;;
			-b|--backupgrace)
				backupGrace="${2}"
				shift 2
				;;
			--)
				shift
				break
				;;
			*)
				echo "[pzsvrtool] Invalid argument '${1}'"
				exit 1
				;;
		esac
	done

	if [[ -n ${customMinutes} && ! "${customMinutes}" =~ ^-?[0-9]+$ ]]; then
		echo "[pzsvrtool] Invalid value for \"time\""
		exit 1
	fi
	
	if [[ -n ${backupGrace} && ! "${backupGrace}" =~ ^-?[0-9]+$ ]]; then
		echo "[pzsvrtool] Invalid value \"backupgrace\""
		exit 1
	fi

    # After processing valid flags, check if there are leftover positional arguments
    if [[ $# -gt 0 ]]; then
        echo "[pzsvrtool] Unexpected arguments: $*"
        exit 1
    fi

	unset parsed_args
}

parse_args_quit() {
	# -o = short
	# --long = long flag
	# : after flag means mandatory argument
	# :: after flag means optional arguement

	parsed_args=$(getopt -o t: --long time: -n "pzsvrtool" -- "${@}")
	if [[ $? -ne 0 ]]; then
		exit 1
	fi

	eval set -- "${parsed_args}"

	while [ $# -gt 0 ]; do
		case "${1}" in
			-t|--time)
				customMinutes="${2}"
				shift 2
				;;
			--)
				shift
				break
				;;
			*)
				echo "[pzsvrtool] Invalid argument '${1}'"
				exit 1
				;;
		esac
	done

	if [[ -n ${customMinutes} && ! "${customMinutes}" =~ ^-?[0-9]+$ ]]; then
		echo "[pzsvrtool] Invalid value for \"time\""
		exit 1
	fi

    # After processing valid flags, check if there are leftover positional arguments
    if [[ $# -gt 0 ]]; then
        echo "[pzsvrtool] Unexpected arguments: $*"
        exit 1
    fi

	unset parsed_args
}

installJson=""
installStartServer=""

parse_args_install() {
    # Define the valid short and long flags
    parsed_args=$(getopt -o js --long json,startserver -n "pzsvrtool" -- "${@}")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    eval set -- "${parsed_args}"

    while [ $# -gt 0 ]; do
        case "${1}" in
            -j|--json)
                installJson="true"
                shift
                ;;
            -s|--startserver)
                installStartServer="true"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "[pzsvrtool] Invalid argument '${1}'"
                exit 1
                ;;
        esac
    done

    # After processing valid flags, check if there are leftover positional arguments
    if [[ $# -gt 0 ]]; then
        echo "[pzsvrtool] Unexpected arguments: $*"
        exit 1
    fi

    unset parsed_args
}

chatonly=""

parse_args_console() {
    # Define the valid short and long flags
    parsed_args=$(getopt -o c --long chatonly -n "pzsvrtool" -- "${@}")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    eval set -- "${parsed_args}"

    while [ $# -gt 0 ]; do
        case "${1}" in
            -c|--chatonly)
                chatonly="--chatonly"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "[pzsvrtool] Invalid argument '${1}'"
                exit 1
                ;;
        esac
    done

    # After processing valid flags, check if there are leftover positional arguments
    if [[ $# -gt 0 ]]; then
        echo "[pzsvrtool] Unexpected arguments: $*"
        exit 1
    fi

    unset parsed_args
}