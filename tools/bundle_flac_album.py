#!/usr/bin/env python3
"""Place beside numbered CD-format FLAC tracks and run with Python 3.

Requires flac and metaflac. Inputs are assumed to be 44.1 kHz, 16-bit stereo
with CD-aligned track boundaries. Tracks are joined in filename order.
"""

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave


def main():
    folder = Path(__file__).resolve().parent
    output = folder / (folder.name + ".flac")
    if output.exists():
        raise RuntimeError(f"Output already exists; move it before rerunning: {output}")
    for tool in ("flac", "metaflac"):
        if shutil.which(tool) is None:
            raise RuntimeError(f"Required command not found: {tool}")
    tracks = sorted(p for p in folder.iterdir()
                    if p.is_file() and p.suffix.lower() == ".flac")
    if not 1 <= len(tracks) <= 99:
        raise RuntimeError("Expected between 1 and 99 FLAC tracks beside this script.")

    with tempfile.TemporaryDirectory(prefix=".bundle-flac-", dir=folder) as scratch:
        scratch = Path(scratch)
        wav_path = scratch / "album.wav"
        cue_path = scratch / "album.cue"
        cue = ['FILE "album.wav" WAVE']
        position = 0
        with wave.open(str(wav_path), "wb") as wav:
            wav.setparams((2, 2, 44100, 0, "NONE", "not compressed"))
            for number, track in enumerate(tracks, 1):
                samples = int(subprocess.check_output(
                    ["metaflac", "--show-total-samples", str(track)], text=True))
                frames = position // 588
                cue.extend([
                    f"  TRACK {number:02d} AUDIO",
                    f"    INDEX 01 {frames // 4500:02d}:{frames // 75 % 60:02d}:{frames % 75:02d}",
                ])
                print(f"[{number}/{len(tracks)}] {track.name}", flush=True)
                with subprocess.Popen([
                    "flac", "-d", "-c", "--silent", "--force-raw-format",
                    "--endian=little", "--sign=signed", str(track),
                ], stdout=subprocess.PIPE) as decoder:
                    decoded = 0
                    try:
                        while chunk := decoder.stdout.read(1024 * 1024):
                            wav.writeframesraw(chunk)
                            decoded += len(chunk)
                    except BaseException:
                        decoder.kill()
                        raise
                    if decoder.wait() != 0 or decoded != samples * 4:
                        raise RuntimeError(f"Could not decode complete track: {track.name}")
                position += samples

        cue_path.write_text("\n".join(cue) + "\n", encoding="ascii")
        print("Encoding and verifying album...", flush=True)
        # 400 regular points plus up to 99 track points stay below the core's
        # 512-point table capacity, including long albums with many tracks.
        subprocess.run([
            "flac", "-8", "-V", "--seekpoint=400x",
            f"--cuesheet={cue_path}", f"--tag=ALBUM={folder.name}",
            "-o", str(output), str(wav_path),
        ], check=True)
    print(f"Created: {output}")
    print("Load this FLAC in MediaPlayer; N/P selects its embedded tracks.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(f"Error: {error}")
