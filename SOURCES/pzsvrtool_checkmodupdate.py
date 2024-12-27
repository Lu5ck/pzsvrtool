#!/usr/bin/python3

# Performs two tasks at the same time which are countdown and read log
# Require non-blocking solution
# Threading will have two threads, one waiting for 1s most of the time.
# Thus async make better sense with 1 thread doing two tasks
# await is the yield point, isntead of waiting, do other await jobs

import asyncio
import os
import sys
import subprocess
sys.path.append("/usr/libexec/pzsvrtool")
import pzsvrtool_common

if not pzsvrtool_common.is_process_active("ProjectZomboid"):
    sys.exit()

async def checkmodupdate_process(proc):
    global bRunning
    # Don't do await for this as waiting will make us lose some log lines related to the command
    pzsvrtool_common.send_keys_to_tmux_session(pzsvrtool_common.get_tmux_session(), "checkModsNeedUpdate")
    try:
        while True:
            line = await proc.stdout.readline()
            line = line.decode("utf-8").strip() # Convert binary to text

            # Find matching lines
            if "CheckModsNeedUpdate: Mods updated" in line:
                bRunning = False
                print("false")
                break

            if "CheckModsNeedUpdate: Mods need update" in line:
                bRunning = False
                print("true") # Shell script only recognize this, other returns are placeholder
                break

            if "CheckModsNeedUpdate: Check not completed" in line:
                bRunning = False
                print("false")
                break
    except Exception as e:
        bRunning = False
        print("error", e)

async def main():
    global bRunning

    bRunning = True
    # Create reader, this returns binary as it doesnt have text=True, async doesn't allow it
    proc = await asyncio.create_subprocess_exec(
        "tail", "-F", "-n", "1", os.path.expanduser("~/Zomboid/server-console.txt"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        close_fds=True)

    # Like threading but in async mode
    task = asyncio.create_task(checkmodupdate_process(proc))

    # Timeout
    start_time = asyncio.get_event_loop().time()
    while bRunning:
        if not await pzsvrtool_common.is_process_active_async("ProjectZomboid"): # Incase server exit while we running this
            bRunning = False
        if (asyncio.get_event_loop().time() - start_time) > 60:
            bRunning = False
            print("timeout")
            break
        await asyncio.sleep(1) # Instead of waiting full second, it will now read logs

    task.cancel() # If timeout, need to explicitly end the task
    proc.terminate()
    await proc.wait()
    sys.exit()

if __name__ == "__main__":
    asyncio.run(main())
