#!/usr/bin/env python3
"""Reusable 'look' helper for driving the AnyNote app on the device.

Dumps the Android UI hierarchy (Flutter exposes semantics via content-desc),
then prints every interactive/labeled element with its computed tap center.

Usage:
    python look.py            # print current screen's elements
    python look.py --raw      # print full XML (debug)
"""
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

DEV = os.environ.get("QA_DEV", "26f01ec875217ece")
ENV = dict(os.environ, MSYS_NO_PATHCONV="1")


def adb(*args):
    # Always decode as UTF-8 (Windows defaults to GBK and breaks on Chinese).
    return subprocess.run(
        ["adb", "-s", DEV, *args], env=ENV,
        capture_output=True, encoding="utf-8", errors="replace",
    )


def center(b):
    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", b)
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    return ((x1 + x2) // 2, (y1 + y2) // 2)


def main():
    # Force UTF-8 stdout so Chinese labels render (Windows defaults to GBK).
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    raw = "--raw" in sys.argv
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    xml = adb("shell", "cat", "/sdcard/ui.xml").stdout
    if raw:
        print(xml)
        return
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as e:
        print(f"[XML parse error: {e}]")
        print(xml[:2000])
        return

    rows = []
    for node in root.iter("node"):
        cd = node.get("content-desc", "")
        txt = node.get("text", "")
        cls = node.get("class", "")
        clickable = node.get("clickable", "false")
        scrollable = node.get("scrollable", "false")
        bounds = node.get("bounds", "")
        label = cd or txt
        is_input = "EditText" in cls
        is_btn = "Button" in cls
        interesting = bool(label) or is_input or is_btn or clickable == "true"
        if not interesting:
            continue
        c = center(bounds)
        if not c:
            continue
        # skip full-screen filler containers
        if not label and not is_input and not is_btn and clickable != "true":
            continue
        if label in ("", ) and c == (720, 1480):
            continue
        kind = "INPUT" if is_input else ("BTN" if is_btn else "")
        tag = f"[{kind}]" if kind else ""
        scroll = " <scroll>" if scrollable == "true" else ""
        rows.append((c[0], c[1], clickable == "true", cls.split(".")[-1],
                     f"{tag}{scroll} {label}".strip()))

    if not rows:
        print("(no interactive elements found)")
        return
    # de-duplicate identical (x,y,label)
    seen = set()
    for cx, cy, clk, cls, label in rows:
        key = (cx, cy, label)
        if key in seen:
            continue
        seen.add(key)
        clk_s = "tap" if clk else "   "
        print(f"({cx:4d},{cy:4d}) {clk_s} {cls:14s} {label}")


if __name__ == "__main__":
    main()
