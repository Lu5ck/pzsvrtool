import os
import sys
import argparse
import subprocess
import curses
import asyncio
import textwrap
sys.path.append("/usr/libexec/pzsvrtool")
import pzsvrtool_common

# Setup arguments
parser = argparse.ArgumentParser(description="Show tail and output to screen", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("--tail", help="Tail file location", required=True)
parser.add_argument("--chatonly", help="See chat only", action="store_true", required=False)
args = parser.parse_args()
tailfile = args.tail
chatOnly = args.chatonly

bRunning = True
logProc = None
max_lines = None
scrolling = False
pad_pos = None
pad_last_pos = None

async def read_textbox(input_win, pad, scrnHeight):
    global bRunning, pad_pos, pad_last_pos, scrolling
    temp, width = pad.getmaxyx()
    cursor_x = 0
    input_text = ""
    input_win.clear()
    input_win.nodelay(True)
    input_win.refresh()

    while bRunning:
        try:
            char = input_win.get_wch()
            
            if isinstance(char, int):
                if char == curses.KEY_BACKSPACE:
                    if len(input_text) > 0:
                        input_text = input_text[:-1]
                        cursor_x -= 1
                        input_win.delch(0, cursor_x)
                elif char == curses.KEY_UP:
                    scrolling = True
                    pad_pos = max(0, pad_pos - (scrnHeight - 1) - 1)
                    pad.noutrefresh(pad_pos, 0, 0, 0, curses.LINES - 2, width - 1)
                    input_win.refresh()
                elif char == curses.KEY_DOWN:
                    pad_pos = min(pad_last_pos, pad_pos + (scrnHeight - 1) + 1)
                    if pad_pos == pad_last_pos:
                        scrolling = False
                    pad.noutrefresh(pad_pos, 0, 0, 0, curses.LINES - 2, width - 1)
                    input_win.refresh()
                elif char == curses.KEY_PPAGE:
                    scrolling = True
                    pad_pos = max(0, pad_pos - (scrnHeight - 1) // 4)
                    pad.noutrefresh(pad_pos, 0, 0, 0, curses.LINES - 2, width - 1)
                    input_win.refresh()
                elif char == curses.KEY_NPAGE:
                    pad_pos = min(pad_last_pos, pad_pos + (scrnHeight - 1) // 4)
                    if pad_pos == pad_last_pos:
                        scrolling = False
                    pad.noutrefresh(pad_pos, 0, 0, 0, curses.LINES - 2, width - 1)
                    input_win.refresh()
            elif isinstance(char, str):
                if char == "\n": # Enter
                    if pzsvrtool_common.is_process_active("ProjectZomboid") and pzsvrtool_common.get_tmux_session():
                        if input_text == "quit":
                            pzsvrtool_common.modify_config(os.path.expanduser("~/pzsvrtool/.varfile"), "shutdown", "true")
                            pzsvrtool_common.modify_config(os.path.expanduser("~/pzsvrtool/.varfile"), "safeShutdown", "true")
                        pzsvrtool_common.send_keys_to_tmux_session(pzsvrtool_common.get_tmux_session(), input_text)
                    input_text = ""
                    cursor_x = 0
                    input_win.erase()
                elif char == "\x7f": # Backspace
                    if len(input_text) > 0:
                        input_text = input_text[:-1]
                        cursor_x -= 1
                        input_win.delch(0, cursor_x)
                else:
                    input_text += char
                    input_win.addstr(0, cursor_x, char)
                    cursor_x += 1
            input_win.refresh()
        except curses.error: # get_wch cause an error if empty
            await asyncio.sleep(0.1) # Important, otherwise it will block

async def display_log(pad, input_win, tailfile):
    global max_lines, logProc, bRunning, pad_pos, pad_last_pos, scrolling
    height, width = pad.getmaxyx()
    log_lines = []
    pad_pos = 0
    pad_last_pos = 0
    while bRunning:
        logProc = await asyncio.create_subprocess_exec(
        "tail", "-F", "-n", str(max_lines), tailfile,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        close_fds=True)
        try:
            while True:
                line = await logProc.stdout.readline()
                if not line:
                    continue

                line = line.decode("utf-8").strip()

                if chatOnly:
                    if not "Message 'ChatMessage{chat=" in line and not "DISCORD: User '" in line and not "command entered via server console (System.in): \"servermsg " in line:
                        continue

                wrapped_lines = textwrap.wrap(line, width - 1, break_on_hyphens=False)
                for wrapped_line in wrapped_lines:
                    log_lines.append(wrapped_line)

                while len(log_lines) > max_lines:
                    log_lines.pop(0)

                pad.erase()
                for i, log_line in enumerate(log_lines):
                    pad.addstr(i, 0, log_line[:width - 1])

                pad_last_pos = max(0, len(log_lines) - curses.LINES + 1)
                if not scrolling:
                    pad_pos = pad_last_pos

                # Refreshing with input_win after noutrefresh will place cursor at input_win
                pad.noutrefresh(pad_pos, 0, 0, 0, curses.LINES - 2, width - 1) #
                input_win.refresh()
                
        except Exception as e:
            print(e)
            pass
        finally:
            await logProc.wait()
            await asyncio.sleep(1)

async def main(stdscr):
    global bRunning, max_lines, logProc
    stdscr.clear()
    stdscr.refresh()
    height, width = stdscr.getmaxyx()
    max_lines = height * 5
    pad = curses.newpad(max_lines, width) # Pad is a huge windows that allow partial display. Useful for scrolling
    pad.scrollok(True) # For scrolling but I don't know if it really needed
    input_win = curses.newwin(1, width, height - 1, 0)
    input_win.keypad(True) # To recognize speical keys

    task_display_log = asyncio.create_task(display_log(pad, input_win, tailfile))
    task_read_textbox = asyncio.create_task(read_textbox(input_win, pad, height))

    try:
        await asyncio.gather(task_read_textbox, task_display_log)
    finally:
        bRunning = False
        if logProc:
            logProc.terminate()
        curses.endwin()

if __name__ == "__main__":
    try:
        curses.wrapper(lambda stdscr: asyncio.run(main(stdscr))) # Wrapper for noob
    except KeyboardInterrupt:
        bRunning = False
