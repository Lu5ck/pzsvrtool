#!/usr/bin/python3

# We cannot afford to await most of these functions
# It will mess up the sequences

import os
import subprocess
import fnmatch
import getpass
import psutil
import aiohttp

def is_process_active(process_name):
    username = getpass.getuser()
    for proc in psutil.process_iter(attrs=["name", "username"]):
        try:
            if process_name in proc.info["name"] and proc.info["username"] == username:
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return False

async def is_process_active_async(process_name):
    username = getpass.getuser()
    for proc in psutil.process_iter(attrs=["name", "username"]):
        try:
            if process_name in proc.info["name"] and proc.info["username"] == username:
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return False

def send_keys_to_tmux_session(session_name, command_text):
    try:
        command = ["tmux", "send-keys", "-t", session_name, command_text, "C-m"]
        subprocess.run(command, check=True)
    except:
        pass

def get_tmux_session():
    try:
        # List all tmux sessions
        result = subprocess.run(
            ["tmux", "list-sessions", "-F", "#S"],
            stdout=subprocess.PIPE,
            text=True,
            check=True
        )
        serverName = "pzsvrtool_" + str(get_config_value(os.path.expanduser("~/pzsvrtool/pzsvrtool.config"), "zomboidServerName"))
        sessions = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        for session in sessions :
            if fnmatch.fnmatch(session, serverName):
                return session
        return None  # No matching session found
    except subprocess.CalledProcessError as e:
        return None


def modify_config(file_path, key, new_value):
    # Check if the file exists; if not, create it
    if not os.path.exists(file_path):
        with open(file_path, 'w') as file:
            pass 

    # Read the content of the file into a dictionary
    config = {}
    with open(file_path, 'r') as file:
        for line in file:
            # Skip empty lines or lines starting with #
            line = line.strip()
            if line and not line.startswith('#'):
                key_value = line.split('=', 1)
                if len(key_value) == 2:
                    key_in_file, value_in_file = key_value
                    config[key_in_file] = value_in_file

    # Modify or add the key-value pair
    config[key] = new_value

    # Write the modified config back to the file
    with open(file_path, 'w') as file:
        for k, v in config.items():
            file.write(f"{k}={v}\n")

def get_config_value(file_path, key):
    with open(file_path, 'r') as file:
        for line in file:
            # Skip empty lines or lines starting with '#'
            line = line.strip()
            if line and not line.startswith('#'):
                key_value = line.split('=', 1)
                if len(key_value) == 2:
                    key_in_file, value_in_file = key_value
                    if key_in_file == key:
                        return value_in_file
    return None  # Return None if the key is not found

async def send_discord_webhook(message):
    async with aiohttp.ClientSession() as session:
        try:
            webhook_url = get_config_value(os.path.expanduser("~/pzsvrtool/pzsvrtool.config"), "discord_webhook_notice")
            data = {
                "content": message,
            }
            if webhook_url:
                    await session.post(url=webhook_url, json=data)
        except:
            pass