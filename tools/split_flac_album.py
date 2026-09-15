#!/usr/bin/env python3
"""Split a CD-format album FLAC into the directory containing this script.

Usage: python3 split_flac_album.py "path/to/album.flac"
The album must contain an embedded CUESHEET. Requires flac and metaflac. Original
filenames/titles were not retained by bundle_flac_album.py; numbered names
are used instead. The album and existing files are never overwritten.
"""

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import wave


def export_cue(path):
    result = subprocess.run(
        ["metaflac", "--export-cuesheet-to=-", str(path)],
        capture_output=True, text=True)
    return result.stdout if result.returncode == 0 else ""


def track_starts(cue):
    starts = []
    current = None
    for line in cue.splitlines():
        track = re.fullmatch(r"\s*TRACK\s+(\d+)\s+AUDIO\s*", line)
        index = re.fullmatch(r"\s*INDEX\s+01\s+(\d+):(\d+):(\d+)\s*", line)
        if track:
            current = int(track[1])
        elif index and current is not None:
            minutes, seconds, frames = map(int, index.groups())
            if seconds >= 60 or frames >= 75:
                raise RuntimeError("Invalid CD track timestamp.")
            starts.append((current, ((minutes * 60 + seconds) * 75 + frames) * 588))
            current = None
    if not starts or len(starts) > 99:
        raise RuntimeError("Expected 1–99 audio tracks with INDEX 01 markers.")
    if any(number != i for i, (number, _) in enumerate(starts, 1)):
        raise RuntimeError("Expected consecutive track numbers starting at 01.")
    if starts[0][1] != 0:
        raise RuntimeError("First track must start at zero; hidden pre-track audio is not supported.")
    if any(a[1] >= b[1] for a, b in zip(starts, starts[1:])):
        raise RuntimeError("Track offsets must be strictly increasing.")
    return starts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("album", type=Path, help="input album FLAC containing embedded track markers")
    args = parser.parse_args()
    folder = Path(__file__).resolve().parent
    for tool in ("flac", "metaflac"):
        if shutil.which(tool) is None:
            raise RuntimeError(f"Required command not found: {tool}")

    album = args.album.resolve()
    if not album.is_file():
        raise RuntimeError(f"Input file not found: {album}")
    cue = export_cue(album)
    if not cue:
        raise RuntimeError(f"No readable embedded CUESHEET: {album}")

    starts = track_starts(cue)
    outputs = [folder / f"{number:02d} - Track {number:02d}.flac" for number, _ in starts]
    for output in outputs:
        if output.exists():
            raise RuntimeError(f"Output already exists: {output}")

    print(f"Decoding: {album.name}", flush=True)
    with tempfile.TemporaryDirectory(prefix=".split-flac-", dir=folder) as scratch:
        scratch = Path(scratch)
        wav_path = scratch / "album.wav"
        subprocess.run(["flac", "-d", "-o", str(wav_path), str(album)], check=True)
        with wave.open(str(wav_path), "rb") as audio:
            if (audio.getframerate(), audio.getnchannels(), audio.getsampwidth()) != (44100, 2, 2):
                raise RuntimeError("Expected 44.1 kHz, 16-bit stereo audio.")
            total = audio.getnframes()
            if starts[-1][1] >= total:
                raise RuntimeError("Last track starts beyond the end of the audio.")
            ends = [offset for _, offset in starts[1:]] + [total]
            for (number, start), end, output in zip(starts, ends, outputs):
                print(f"[{number}/{len(starts)}] {output.name}", flush=True)
                track_wav = scratch / "track.wav"
                audio.setpos(start)
                with wave.open(str(track_wav), "wb") as track:
                    track.setparams((2, 2, 44100, 0, "NONE", "not compressed"))
                    remaining = end - start
                    while remaining:
                        count = min(remaining, 262144)
                        pcm = audio.readframes(count)
                        if len(pcm) != count * 4:
                            raise RuntimeError("Incomplete decoded album audio.")
                        track.writeframesraw(pcm)
                        remaining -= count
                subprocess.run([
                    "flac", "-8", "-V", "--seekpoint=10s",
                    f"--tag=TRACKNUMBER={number}", f"--tag=TRACKTOTAL={len(starts)}",
                    f"--tag=ALBUM={album.stem}",
                    "-o", str(output), str(track_wav),
                ], check=True)
    print(f"Created {len(outputs)} tracks in: {folder}")
    print("Original album preserved.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, wave.Error, subprocess.CalledProcessError) as error:
        sys.exit(f"Error: {error}")
