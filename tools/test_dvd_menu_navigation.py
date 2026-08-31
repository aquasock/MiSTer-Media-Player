#!/usr/bin/env python3
"""Exercise a real DVD image's menu control and overlay transport path."""

import argparse
import os
import selectors
import socket
import subprocess
import sys
import time


MARKER = b"\x00\x00\x01\xb9"
READY = 0x81
MENU_ENTER = 0x82
MENU_LEAVE = 0x83
GO = 0x03
MENU_DOWN = 0x05
MENU_RIGHT = 0x07
MENU_ACTIVATE = 0x08
ROOT_MENU = 0x09


def parse_overlay_records(buffer, counts):
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
        if command == 2:
            counts[5] += size - 1
        buffer = buffer[total:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("helper")
    parser.add_argument("iso")
    parser.add_argument("--timeout", type=float, default=35.0)
    args = parser.parse_args()

    parent, child = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
    process = subprocess.Popen(
        [os.path.abspath(args.helper), "--protocol", "1", "--source",
         "isomenu:" + os.path.abspath(args.iso), "--control-fd",
         str(child.fileno())],
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
    root_due = time.monotonic() + 1.0
    action_due = None
    actions = [MENU_RIGHT, MENU_DOWN, MENU_ACTIVATE]
    action_index = 0
    root_sent = False
    menu_events = 0
    leave_events = 0
    ready_events = 0
    counts = [0] * 6
    video_buffer = b""
    error_buffer = bytearray()

    try:
        while time.monotonic() < deadline:
            now = time.monotonic()
            if not root_sent and now >= root_due:
                parent.send(bytes((ROOT_MENU,)))
                root_sent = True
            if (menu_events and counts[3] and action_index < len(actions) and
                    (action_due is None or now >= action_due)):
                parent.send(bytes((actions[action_index],)))
                action_index += 1
                action_due = now + 0.35

            if (ready_events >= 2 and menu_events and counts[1] and
                    counts[2] and counts[3] and counts[5] >= 86400):
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
                    elif event[0] == 0xff:
                        raise RuntimeError("helper reported a control error")
                elif key.data == "video":
                    try:
                        chunk = os.read(process.stdout.fileno(), 1 << 20)
                    except BlockingIOError:
                        continue
                    if chunk:
                        video_buffer = parse_overlay_records(
                            video_buffer + chunk, counts)
                else:
                    try:
                        chunk = os.read(process.stderr.fileno(), 65536)
                    except BlockingIOError:
                        continue
                    if chunk:
                        error_buffer.extend(chunk)
                        if len(error_buffer) > 262144:
                            del error_buffer[:-262144]
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

    passed = (root_sent and action_index == len(actions) and ready_events >= 2 and
              menu_events >= 1 and counts[1] >= 1 and counts[2] >= 1 and
              counts[3] >= 1 and counts[5] >= 86400)
    print("dvd menu navigation: "
          f"enter={menu_events} leave={leave_events} ready={ready_events} "
          f"config={counts[1]} data_records={counts[2]} "
          f"data_bytes={counts[5]} commit={counts[3]} style={counts[4]} "
          f"clear={counts[0]}")
    if not passed:
        sys.stderr.write(error_buffer.decode(errors="replace"))
        return 1
    print("dvd menu navigation: root, direction, activation and overlay pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
