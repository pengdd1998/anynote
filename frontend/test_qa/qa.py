#!/usr/bin/env python3
"""Compact driver for the AnyNote device QA walkthrough.

Subcommands:
    tap X Y            tap at coordinates
    longtap X Y        long-press
    swipe X1 Y1 X2 Y2  swipe (duration 300ms)
    back               press back key
    key NAME           press a keyevent (e.g. ENTER)
    type TEXT          type ASCII text (spaces ok)
    text CN            type via clipboard (Unicode/Chinese capable)
    shot NAME          screenshot to test_qa/shots/NAME.png
    sleep SECONDS      pause
"""
import os
import subprocess
import sys
import time

DEV = os.environ.get("QA_DEV", "26f01ec875217ece")
ENV = dict(os.environ, MSYS_NO_PATHCONV="1")


def adb(*args):
    subprocess.run(["adb", "-s", DEV, "shell", *args], env=ENV)


def shot(name):
    p = f"test_qa/shots/{name}.png"
    os.makedirs("test_qa/shots", exist_ok=True)
    adb("screencap", "-p", "/sdcard/q.png")
    subprocess.run(["adb", "-s", DEV, "pull", "/sdcard/q.png", p],
                   env=ENV, capture_output=True)
    adb("rm", "/sdcard/q.png")
    print(f"shot: {p}")


def type_ascii(s):
    # Android `input text` decodes %s as space; escape it.
    adb("input", "text", s.replace(" ", "%s"))


def type_unicode(s):
    # Push to clipboard, then paste. Requires ADBKeyboard or similar IME that
    # accepts broadcast; fall back to raw broadcast (works on most ROMs).
    subprocess.run(
        ["adb", "-s", DEV, "shell", "am", "broadcast", "-a",
         "clipper.set", "-e", "text", s], env=ENV, capture_output=True)
    # Try the common ADBKeyboard broadcast; if absent, this is a no-op.
    subprocess.run(
        ["adb", "-s", DEV, "shell", "am", "broadcast", "-a",
         "com.android.adbkeyboard.SET_TEXT", "-e", "text", s],
        env=ENV, capture_output=True)
    adb("input", "keyevent", "279")  # KEYCODE_PASTE


def main():
    cmd = sys.argv[1]
    if cmd == "tap":
        adb("input", "tap", str(sys.argv[2]), str(sys.argv[3]))
    elif cmd == "longtap":
        adb("input", "swipe", str(sys.argv[2]), str(sys.argv[3]),
            str(sys.argv[2]), str(sys.argv[3]), "800")
    elif cmd == "swipe":
        adb("input", "swipe", *map(str, sys.argv[2:7]))
    elif cmd == "back":
        adb("input", "keyevent", "4")
    elif cmd == "key":
        adb("input", "keyevent", str(sys.argv[2]))
    elif cmd == "type":
        type_ascii(sys.argv[2])
    elif cmd == "text":
        type_unicode(sys.argv[2])
    elif cmd == "shot":
        shot(sys.argv[2])
    elif cmd == "sleep":
        time.sleep(float(sys.argv[2]))
    else:
        print(f"unknown: {cmd}")
        sys.exit(2)


if __name__ == "__main__":
    main()
