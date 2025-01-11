#!/usr/bin/python3

# Performs two tasks at the same time which are timeout and read log
# Require non-blocking solution
# Threading will have two threads, one waiting for log while other counting timeout with sleep
# Thus async make better sense with 1 thread doing up to three tasks
# await is the yield point, isntead of waiting, do other await jobs

import sys
import asyncio
import os
import subprocess
import re
sys.path.append("/usr/libexec/pzsvrtool")
import pzsvrtool_common

# Global variables
bRunning = True

async def read_log(proc):
    global bRunning
    try:
        while True:
            line = await proc.stdout.readline()
            line = line.decode("utf-8").strip() # Convert binary to text

            # Find matching lines
            if re.match(r"LOG\s+:\s+Network\s+,\s+\d+>\s+\d{1,3}(?:,\d{3})*>.+?\*\*\*\s+SERVER STARTED\s+\*\*\*", line):
                await pzsvrtool_common.send_discord_webhook("Server started")
                pzsvrtool_common.write_log("Server started")
                bRunning = False
                break
    except Exception as e:
        bRunning = False
        print("error", e)

async def main():
    global bRunning

    proc = await asyncio.create_subprocess_exec(
        "tail", "-F", "-n", "1", os.path.expanduser("~/Zomboid/server-console.txt"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        close_fds=True)
    
    task = asyncio.create_task(read_log(proc))
    start_time = asyncio.get_event_loop().time()
    timeout = 5

    while bRunning:
        # We check if the server booted or not, can't have this python running forever
        if (asyncio.get_event_loop().time() - start_time) > timeout and not await pzsvrtool_common.is_process_active_async("ProjectZomboid") and bRunning:
            await pzsvrtool_common.send_discord_webhook("Server bootup failed")
            pzsvrtool_common.write_log("Server bootup failed")
            bRunning = False
        # If server booted, we set timeout to zero, switching to checking if server shutdown, specifically fail to start
        if timeout != 0 and await pzsvrtool_common.is_process_active_async("ProjectZomboid"):
            timeout = 0 
        await asyncio.sleep(0.5)

    task.cancel()
    proc.terminate()
    await proc.wait()
    sys.exit()

if __name__ == "__main__":
    asyncio.run(main())
