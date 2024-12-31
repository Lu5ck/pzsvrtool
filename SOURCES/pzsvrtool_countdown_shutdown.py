#!/usr/bin/python3

# Performs up to three tasks at the same time which are countdown, read input and check log to kick players
# Require non-blocking solution
# Threading will have up to three threads, one waiting for 1s most of the time, one waiting for input which is empty most of the time.
# Thus async make better sense with 1 thread doing up to three tasks
# await is the yield point, isntead of waiting, do other await jobs

import sys
import asyncio
import time
import os
import subprocess
import argparse
sys.path.append("/usr/libexec/pzsvrtool")
import pzsvrtool_common

# Global variables
seconds = 0
bRunning = True
isFirstAnnouncement = True
isOperatorChangedAnnounced = False
isGraced = False
tailProc = None

async def announcement():
    global seconds
    timeleft = seconds // 60

    if pzsvrtool_common.get_config_value(os.path.expanduser("~/pzsvrtool/.varfile"), "shutdown") == "false":
        message = "servermsg \"Restarting server"
    else:
        message = "servermsg \"Shutting down server"
    if timeleft > 0:
        message += f" in {timeleft} minutes."
    else:
        message += "."
    if timeleft == 1:
        message += " Stop moving and log out or risk data loss!"
    elif timeleft <= 5 and timeleft > 1:
        message += " Get to safety!"

    message += "\""
    pzsvrtool_common.send_keys_to_tmux_session(pzsvrtool_common.get_tmux_session(), message)
    await pzsvrtool_common.send_discord_webhook(message.removeprefix("servermsg \"").removesuffix("\""))

# We kick players to force all the ingame cells to be unloaded
# I just got this impression that some data are not saved because of it
async def kick_all_players(proc):
    # Don't do await for this as waiting will make us lose some log lines related to the command
    pzsvrtool_common.send_keys_to_tmux_session(pzsvrtool_common.get_tmux_session(), "players")
    num_connected = -1 # Start at negative because 0 is valid number
    players_connected = []

    try:
        while True:
            line = await proc.stdout.readline()
            line = line.decode("utf-8").strip() # Convert binary to text

            # Find matching line and get index character to retrieve the player number
            if "Players connected (" in line:
                start_idx = line.find("(") + 1
                end_idx = line.find("):")
                num_connected = int(line[start_idx:end_idx])

            # If player is more than 0, we look at the next lines for player names
            if num_connected > 0 and len(players_connected) < num_connected:
                if line.startswith("-"):
                    players_connected.append(line.lstrip("-").strip())

            # Once we got all the players name, we kick
            if len(players_connected) == num_connected:
                if pzsvrtool_common.get_config_value(os.path.expanduser("~/pzsvrtool/.varfile"), "shutdown") == "false":
                    kickmsg = "Server Restarting"
                else:
                    kickmsg = "Server shutting down"

                for player in players_connected:
                    pzsvrtool_common.send_keys_to_tmux_session(pzsvrtool_common.get_tmux_session(), f"kickuser \"{player}\" -r \"{kickmsg}\"")

                # End the reader
                proc.terminate()
                await proc.wait()
                break
    except Exception as e:
        pass

async def countdown_timer():
    global seconds, bRunning, isFirstAnnouncement, isGraced, isOperatorChangedAnnounced, tailProc
    while seconds > 0 and bRunning:
        if not await pzsvrtool_common.is_process_active_async("ProjectZomboid"): # Incase server exit while we running this
            bRunning = False

        # Prevent duplicated announcements due to periodic and initial announcement, if both are at specific time
        if isFirstAnnouncement: 
            await announcement()
            isFirstAnnouncement = False
        elif isOperatorChangedAnnounced: # Prevent duplicated announcement but this time operator change and periodic
            isOperatorChangedAnnounced = False
        else:
            if seconds % 300 == 0:
                await announcement()

            if seconds < 300 and seconds % 60 == 0:
                await announcement()

            if seconds == 30 and not isGraced: # We add 20s here as we kick players at 20th second, just to give players full indicated time
                isGraced = True
                seconds += 20

            if seconds == 20:
                # Create reader, this returns binary as it doesnt have text=True, async doesn't allow it
                tailProc = await asyncio.create_subprocess_exec(
                    "tail", "-F", "-n", "1", os.path.expanduser("~/Zomboid/server-console.txt"),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    close_fds=True)
                # Don't need to track this task, we can stop this task by terminating tailProc
                asyncio.create_task(kick_all_players(tailProc))

        await asyncio.sleep(1)
        seconds -= 1

    if bRunning:
        # To indicate if safe shutdown or a crash, the save file will backup according to this variable
        pzsvrtool_common.modify_config(os.path.expanduser("~/pzsvrtool/.varfile"), "safeShutdown", "true")
        pzsvrtool_common.send_keys_to_tmux_session(pzsvrtool_common.get_tmux_session(), "quit")
        bRunning =  False

async def command_listener():
    global seconds, bRunning, isGraced, isOperatorChangedAnnounced, tailProc
    
    # All just to create async reader for input
    loop = asyncio.get_event_loop()
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, sys.stdin)

    while bRunning:
        try:
            # With timeout, allow loop to keep running to check flag
            commands = await asyncio.wait_for(reader.readline(), timeout=0.5)
            commands = commands.decode().strip().split()

            if not commands:
                continue
            if commands[0] == "timeleft":
                print(seconds, flush=True)
            elif commands[0] == "updatetime":
                seconds = int(commands[1]) * 60
                isGraced = False # Remember we kick at 20s, we use this flag to add time so we need to reset this flag
                isOperatorChangedAnnounced = True
                if tailProc: # If changed after everybody kicked, what a troll at this point
                    tailProc.terminate()
                    tailProc = None
                pzsvrtool_common.send_keys_to_tmux_session(pzsvrtool_common.get_tmux_session(), f"servermsg \"Operator has changed countdown time to {commands[1]} minutes.\"")
                await pzsvrtool_common.send_discord_webhook(f"Operator has changed countdown time to {commands[1]} minutes.")
            elif commands[0] == "stop":
                bRunning = False
                pzsvrtool_common.send_keys_to_tmux_session(pzsvrtool_common.get_tmux_session(), "servermsg \"Operator has cancelled the countdown.\"")
                await pzsvrtool_common.send_discord_webhook("Operator has cancelled the countdown.")
        except asyncio.TimeoutError:
            continue

async def main():
    global seconds

    # Library to parse arguments
    parser = argparse.ArgumentParser(description="Countdown Shutdown", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("-minutes", help="How many minutes?", required=True)
    args = parser.parse_args()
    seconds = int(args.minutes) * 60

    await asyncio.gather(countdown_timer(), command_listener())


if __name__ == "__main__":
    asyncio.run(main())
