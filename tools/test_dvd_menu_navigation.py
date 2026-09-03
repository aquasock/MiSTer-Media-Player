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
    rb"media_source: (?:DVD|ISO) menu hop "
    rb"(root|activate|delayed activate) "
    rb"discarded_block_tail=([0-9]+)"
)
CONTINUE_RE = re.compile(
    rb"media_source: (?:DVD|ISO) menu continue "
    rb"(activate|delayed activate) "
    rb"discarded_block_tail=([0-9]+)"
)
PENDING_RE = re.compile(
    rb"media_source: (?:DVD|ISO) menu pending (activate) "
    rb"discarded_block_tail=([0-9]+)"
)
PENDING_PAYLOAD_RE = re.compile(
    rb"media_player_helper: DVD menu activation pending reached still "
    rb"payloads=([1-9][0-9]*) duration=(?:indefinite/)?([0-9]+)"
)
POST_STILL_PENDING_RE = re.compile(
    rb"media_player_helper: DVD delayed activation remains pending "
    rb"after finite still"
)
POST_STILL_HOP_RE = re.compile(
    rb"media_player_helper: DVD delayed activation stream hop before payload"
)
COMMAND_RE = re.compile(
    rb"media_source: (?:DVD|ISO) menu command="
    rb"(up|down|left|right|activate|root) pci_lbn=([0-9]+) "
    rb"buttons=([0-9]+) before=([0-9]+) target=([0-9]+) "
    rb"after=([0-9]+) "
    rb"status=(ok|error|ignored|ignored-error|auto-action|already-root) "
    rb"highlight=([01]) "
    rb"rect=([0-9]+),([0-9]+),([0-9]+),([0-9]+) "
    rb"palette=([0-9a-fA-F]{8})"
)
RANDOM_ACCESS_RE = re.compile(
    rb"media_player_helper: DVD random access sequence_offset=([0-9]+) "
    rb"intra_offset=([0-9]+) next_reference_offset=([0-9]+) "
    rb"discarded=([0-9]+) pre-context picture\(s\), "
    rb"([0-9]+) leading B picture\(s\)"
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
    parser.add_argument("--require-delayed-activation", action="store_true")
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
    action_pending = False
    action_decisions = 0
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
    pending_counts = {"activate": 0}
    pending_discarded = {"activate": []}
    pending_payloads = []
    post_still_pending = 0
    post_still_hops = 0
    root_random_access = []
    activation_random_access = []
    last_hop = None
    video_bytes_after_second_ready = 0
    command_counts = {name: 0 for name in
                      ("up", "down", "left", "right", "activate", "root")}
    direction_transitions = []

    try:
        while time.monotonic() < deadline:
            now = time.monotonic()
            if not root_sent and root_due is not None and now >= root_due:
                parent.send(bytes((ROOT_MENU,)))
                root_sent = True
            if (ready_events and menu_events and counts[3] and
                    action_index < len(actions) and not action_pending and
                    (action_due is None or now >= action_due)):
                parent.send(bytes((actions[action_index],)))
                action_index += 1
                action_pending = True
                action_due = now + 0.35

            activation_done = (hop_counts["activate"] and ready_events >= 2) or (
                (continue_counts["activate"] or pending_counts["activate"]) and
                continue_events)
            if args.require_delayed_activation:
                activation_done = (pending_counts["activate"] and
                                   pending_payloads and
                                   post_still_pending and
                                   post_still_hops and
                                   ready_events >= 2 and leave_events and
                                   not continue_events and
                                   activation_random_access and
                                   video_bytes_after_second_ready)
            if (activation_done and action_index == len(actions) and
                    hop_counts["root"] and
                    root_random_access and
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
                        if action_pending:
                            action_pending = False
                            action_decisions += 1
                        parent.send(bytes((GO,)))
                    elif event[0] == MENU_ENTER:
                        menu_events += 1
                    elif event[0] == MENU_LEAVE:
                        leave_events += 1
                    elif event[0] == MENU_CONTINUE:
                        continue_events += 1
                        if action_pending:
                            action_pending = False
                            action_decisions += 1
                    elif event[0] == 0xff:
                        raise RuntimeError("helper reported a control error")
                elif key.data == "video":
                    try:
                        chunk = os.read(process.stdout.fileno(), 1 << 20)
                    except BlockingIOError:
                        continue
                    if chunk:
                        if ready_events >= 2:
                            video_bytes_after_second_ready += len(chunk)
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
                                if name == "delayed activate":
                                    name = "activate"
                                hop_counts[name] += 1
                                hop_discarded[name].append(
                                    int(match.group(2)))
                                last_hop = name
                            match = CONTINUE_RE.search(line)
                            if match:
                                name = match.group(1).decode("ascii")
                                if name == "delayed activate":
                                    name = "activate"
                                continue_counts[name] += 1
                                continue_discarded[name].append(
                                    int(match.group(2)))
                            match = PENDING_RE.search(line)
                            if match:
                                name = match.group(1).decode("ascii")
                                pending_counts[name] += 1
                                pending_discarded[name].append(
                                    int(match.group(2)))
                            match = PENDING_PAYLOAD_RE.search(line)
                            if match:
                                pending_payloads.append(
                                    (int(match.group(1)),
                                     int(match.group(2))))
                            if POST_STILL_PENDING_RE.search(line):
                                post_still_pending += 1
                            if POST_STILL_HOP_RE.search(line):
                                post_still_hops += 1
                                last_hop = "activate"
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
                            match = RANDOM_ACCESS_RE.search(line)
                            if match and last_hop:
                                access = tuple(
                                    int(match.group(index))
                                    for index in range(1, 6))
                                if last_hop == "root":
                                    root_random_access.append(access)
                                elif last_hop == "activate":
                                    activation_random_access.append(access)
                                last_hop = None
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
        ((continue_counts["activate"] >= 1 or
          pending_counts["activate"] >= 1) and continue_events >= 1)
    )
    if args.require_menu_continue:
        activation_passed = ((continue_counts["activate"] >= 1 or
                              pending_counts["activate"] >= 1) and
                             continue_events >= 1 and ready_events >= 1)
    if args.require_delayed_activation:
        activation_passed = (pending_counts["activate"] >= 1 and
                             pending_payloads and
                             post_still_pending >= 1 and
                             post_still_hops >= 1 and
                             ready_events >= 2 and leave_events >= 1 and
                             continue_events == 0 and
                             continue_counts["activate"] == 0 and
                             activation_random_access and
                             video_bytes_after_second_ready > 0)
    passed = (return_code in (0, -15) and root_sent and activation_passed and
              action_index == len(actions) and not action_pending and
              action_decisions == len(actions) and ready_events >= 1 and
              menu_events >= 1 and counts[1] >= 1 and counts[2] >= 1 and
              counts[3] >= 1 and counts[5] >= 86400 and
              overlay_state["visible_highlights"] >= 1 and
              overlay_state["highlight_pixels"] >= 1 and
              hop_counts["root"] >= 1 and
              root_random_access and
              all(sequence < intra < following
                  for sequence, intra, following, _, _
                  in root_random_access) and
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
          f"root_random_access={root_random_access} "
          f"activation_random_access={activation_random_access} "
          f"post_activation_video={video_bytes_after_second_ready} "
          f"activate_hops={hop_counts['activate']} "
          f"activate_discarded={hop_discarded['activate']} "
          f"activate_continues={continue_counts['activate']} "
          f"continue_discarded={continue_discarded['activate']} "
          f"activate_pending={pending_counts['activate']} "
          f"pending_discarded={pending_discarded['activate']} "
          f"pending_payloads={pending_payloads} "
          f"post_still_pending={post_still_pending} "
          f"post_still_hops={post_still_hops} "
          f"visible_highlights={overlay_state['visible_highlights']} "
          f"highlight_pixels={overlay_state['highlight_pixels']} "
          f"commands={command_counts} transitions={direction_transitions} "
          f"action_decisions={action_decisions}/{len(actions)} "
          f"root_sent={int(root_sent)} helper_rc={return_code} "
          f"elapsed={time.monotonic() - started:.2f}s")
    if not passed:
        sys.stderr.write(error_buffer.decode(errors="replace"))
        return 1
    print("dvd menu navigation: root, direction, activation, visible highlight and control acknowledgment pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
