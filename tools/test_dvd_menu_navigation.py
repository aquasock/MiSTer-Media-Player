#!/usr/bin/env python3
"""Exercise a real DVD image or directory's menu and overlay path."""

import argparse
import os
import re
import selectors
import socket
import subprocess
import sys
import time


MARKER = b"\x00\x00\x01\xb9"
READY = 0x81
MENU_ENTER = 0x82
MENU_LEAVE = 0x83
MENU_CONTINUE = 0x84
GO = 0x03
MENU_DOWN = 0x05
MENU_LEFT = 0x06
MENU_RIGHT = 0x07
MENU_ACTIVATE = 0x08
ROOT_MENU = 0x09
MENU_UP = 0x04
HOP_RE = re.compile(
    rb"media_source: (?:DVD|ISO) menu hop (root|activate) "
    rb"discarded_block_tail=([0-9]+)"
)
CONTINUE_RE = re.compile(
    rb"media_source: (?:DVD|ISO) menu continue (activate) "
    rb"discarded_block_tail=([0-9]+)"
)
COMMAND_RE = re.compile(
    rb"media_source: (?:DVD|ISO) menu command="
    rb"(up|down|left|right|activate|root) pci_lbn=([0-9]+) "
    rb"buttons=([0-9]+) before=([0-9]+) target=([0-9]+) "
    rb"after=([0-9]+) status=(ok|error|ignored) highlight=([01]) "
    rb"rect=([0-9]+),([0-9]+),([0-9]+),([0-9]+) "
    rb"palette=([0-9a-fA-F]{8})"
)


def highlighted_plane_pixels(style, plane):
    if len(style) != 41 or len(plane) != 86400 or style[0] & 3 != 3:
        return 0
    if not any(style[index] for index in (20, 24, 28, 32)):
        return 0
    x1 = (style[33] << 8) | style[34]
    y1 = (style[35] << 8) | style[36]
    x2 = (style[37] << 8) | style[38]
    y2 = (style[39] << 8) | style[40]
    if x1 > x2 or y1 > y2 or x2 >= 720 or y2 >= 480:
        return 0
    nonzero = 0
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            pixel = y * 720 + x
            shift = (3 - (pixel & 3)) * 2
            nonzero += ((plane[pixel >> 2] >> shift) & 3) != 0
    return nonzero


def parse_overlay_records(buffer, counts, overlay_state):
    while True:
        marker = buffer.find(MARKER)
        if marker < 0:
            return buffer[-3:]
        if len(buffer) < marker + 7:
            return buffer[marker:]
        size = (buffer[marker + 4] << 8) | buffer[marker + 5]
        command = buffer[marker + 6]
        expected = ((0, 1), (1, 42), (2, None), (3, 1), (4, 42))
        valid = any(command == item[0] and
                    (item[1] is None or size == item[1])
                    for item in expected)
        if not valid or size < 1 or size > 4097:
            buffer = buffer[marker + 1:]
            continue
        total = marker + 6 + size
        if len(buffer) < total:
            return buffer[marker:]
        counts[command] += 1
        payload = buffer[marker + 7:total]
        if command == 1:
            overlay_state["style"] = bytes(payload)
            overlay_state["loading"] = bytearray()
        if command == 2:
            counts[5] += size - 1
            overlay_state["loading"].extend(payload)
        elif command == 3:
            overlay_state["plane"] = bytes(overlay_state["loading"])
            pixels = highlighted_plane_pixels(overlay_state["style"],
                                               overlay_state["plane"])
            if pixels:
                overlay_state["visible_highlights"] += 1
                overlay_state["highlight_pixels"] = max(
                    overlay_state["highlight_pixels"], pixels)
        elif command == 4:
            overlay_state["style"] = bytes(payload)
            pixels = highlighted_plane_pixels(overlay_state["style"],
                                               overlay_state["plane"])
            if pixels:
                overlay_state["visible_highlights"] += 1
                overlay_state["highlight_pixels"] = max(
                    overlay_state["highlight_pixels"], pixels)
        buffer = buffer[total:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("helper")
    parser.add_argument("dvd")
    parser.add_argument("--timeout", type=float, default=35.0)
    parser.add_argument("--require-menu-continue", action="store_true")
    args = parser.parse_args()

    parent, child = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
    dvd_path = os.path.abspath(args.dvd)
    source = ("dvdmenu:" if os.path.isdir(dvd_path) else "isomenu:") + dvd_path
    process = subprocess.Popen(
        [os.path.abspath(args.helper), "--protocol", "1", "--source",
         source, "--control-fd", str(child.fileno())],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, pass_fds=(child.fileno(),)
    )
    child.close()
    parent.setblocking(False)
    os.set_blocking(process.stdout.fileno(), False)
    os.set_blocking(process.stderr.fileno(), False)
    selector = selectors.DefaultSelector()
    selector.register(parent, selectors.EVENT_READ, "control")
    selector.register(process.stdout, selectors.EVENT_READ, "video")
    selector.register(process.stderr, selectors.EVENT_READ, "error")

    deadline = time.monotonic() + args.timeout
    started = time.monotonic()
    root_due = None
    action_due = None
    actions = [MENU_RIGHT, MENU_DOWN, MENU_LEFT, MENU_UP, MENU_ACTIVATE]
    action_index = 0
    root_sent = False
    menu_events = 0
    leave_events = 0
    ready_events = 0
    continue_events = 0
    counts = [0] * 6
    video_buffer = b""
    overlay_state = {
        "style": b"", "loading": bytearray(), "plane": b"",
        "visible_highlights": 0, "highlight_pixels": 0,
    }
    error_buffer = bytearray()
    error_scan = b""
    hop_counts = {"root": 0, "activate": 0}
    hop_discarded = {"root": [], "activate": []}
    continue_counts = {"activate": 0}
    continue_discarded = {"activate": []}
    command_counts = {name: 0 for name in
                      ("up", "down", "left", "right", "activate", "root")}
    direction_transitions = []

    try:
        while time.monotonic() < deadline:
            now = time.monotonic()
            if not root_sent and root_due is not None and now >= root_due:
                parent.send(bytes((ROOT_MENU,)))
                root_sent = True
            if (menu_events and counts[3] and action_index < len(actions) and
                    (action_due is None or now >= action_due)):
                parent.send(bytes((actions[action_index],)))
                action_index += 1
                action_due = now + 0.35

            activation_done = (hop_counts["activate"] and ready_events >= 2) or (
                continue_counts["activate"] and continue_events)
            if (activation_done and action_index == len(actions) and
                    hop_counts["root"] and
                    menu_events and counts[1] and
                    counts[2] and counts[3] and counts[5] >= 86400 and
                    overlay_state["visible_highlights"] and
                    all(command_counts[name] >= 1 for name in
                        ("up", "down", "left", "right", "activate", "root")) and
                    direction_transitions):
                break
            for key, _ in selector.select(0.1):
                if key.data == "control":
                    try:
                        event = parent.recv(1)
                    except BlockingIOError:
                        continue
                    if not event:
                        continue
                    if event[0] == READY:
                        ready_events += 1
                        parent.send(bytes((GO,)))
                    elif event[0] == MENU_ENTER:
                        menu_events += 1
                    elif event[0] == MENU_LEAVE:
                        leave_events += 1
                    elif event[0] == MENU_CONTINUE:
                        continue_events += 1
                    elif event[0] == 0xff:
                        raise RuntimeError("helper reported a control error")
                elif key.data == "video":
                    try:
                        chunk = os.read(process.stdout.fileno(), 1 << 20)
                    except BlockingIOError:
                        continue
                    if chunk:
                        video_buffer = parse_overlay_records(
                            video_buffer + chunk, counts, overlay_state)
                else:
                    try:
                        chunk = os.read(process.stderr.fileno(), 65536)
                    except BlockingIOError:
                        continue
                    if chunk:
                        error_buffer.extend(chunk)
                        if len(error_buffer) > 262144:
                            del error_buffer[:-262144]
                        error_scan += chunk
                        lines = error_scan.split(b"\n")
                        error_scan = lines.pop()
                        for line in lines:
                            if (root_due is None and
                                    (b"DVD menu " in line or
                                     b"DVD still wait " in line)):
                                # libdvdnav is now actively walking authored
                                # playback.  Avoid queuing root-menu during
                                # the helper's CSS/preflight scans.
                                root_due = time.monotonic() + 0.25
                            match = HOP_RE.search(line)
                            if match:
                                name = match.group(1).decode("ascii")
                                hop_counts[name] += 1
                                hop_discarded[name].append(
                                    int(match.group(2)))
                            match = CONTINUE_RE.search(line)
                            if match:
                                name = match.group(1).decode("ascii")
                                continue_counts[name] += 1
                                continue_discarded[name].append(
                                    int(match.group(2)))
                            match = COMMAND_RE.search(line)
                            if match:
                                name = match.group(1).decode("ascii")
                                before = int(match.group(4))
                                target = int(match.group(5))
                                after = int(match.group(6))
                                status = match.group(7).decode("ascii")
                                command_counts[name] += 1
                                if (name in ("up", "down", "left", "right") and
                                        status == "ok" and before > 0 and
                                        target > 0 and after != before):
                                    direction_transitions.append(
                                        (name, before, target, after))
            if process.poll() is not None:
                break
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        parent.close()

    return_code = process.returncode
    activation_passed = (
        (hop_counts["activate"] >= 1 and ready_events >= 2) or
        (continue_counts["activate"] >= 1 and continue_events >= 1)
    )
    if args.require_menu_continue:
        activation_passed = (continue_counts["activate"] >= 1 and
                             continue_events >= 1 and ready_events >= 1)
    passed = (return_code in (0, -15) and root_sent and activation_passed and
              action_index == len(actions) and ready_events >= 1 and
              menu_events >= 1 and counts[1] >= 1 and counts[2] >= 1 and
              counts[3] >= 1 and counts[5] >= 86400 and
              overlay_state["visible_highlights"] >= 1 and
              overlay_state["highlight_pixels"] >= 1 and
              hop_counts["root"] >= 1 and
              all(command_counts[name] >= 1 for name in
                  ("up", "down", "left", "right", "activate", "root")) and
              direction_transitions)
    print("dvd menu navigation: "
          f"enter={menu_events} leave={leave_events} ready={ready_events} "
          f"continue_events={continue_events} "
          f"config={counts[1]} data_records={counts[2]} "
          f"data_bytes={counts[5]} commit={counts[3]} style={counts[4]} "
          f"clear={counts[0]} root_hops={hop_counts['root']} "
          f"root_discarded={hop_discarded['root']} "
          f"activate_hops={hop_counts['activate']} "
          f"activate_discarded={hop_discarded['activate']} "
          f"activate_continues={continue_counts['activate']} "
          f"continue_discarded={continue_discarded['activate']} "
          f"visible_highlights={overlay_state['visible_highlights']} "
          f"highlight_pixels={overlay_state['highlight_pixels']} "
          f"commands={command_counts} transitions={direction_transitions} "
          f"root_sent={int(root_sent)} helper_rc={return_code} "
          f"elapsed={time.monotonic() - started:.2f}s")
    if not passed:
        sys.stderr.write(error_buffer.decode(errors="replace"))
        return 1
    print("dvd menu navigation: root, direction, activation, visible highlight and control acknowledgment pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
