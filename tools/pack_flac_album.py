#!/usr/bin/env python3
"""Place beside numbered audio tracks and run with Python 3.

Requires ffmpeg and flac. Tracks are joined in filename order after conversion
into 44.1 kHz, 16-bit stereo PCM. Compatible CD PCM remains sample-exact.
Unaligned tracks receive less than 13.4 ms of trailing silence so embedded CD
track boundaries are exact. Resampling/downmixing changes samples; encoding
lossy sources to FLAC does not restore their original quality.
"""

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave


AUDIO_EXTENSIONS = {
    ".flac", ".wav", ".wave", ".aif", ".aiff", ".aifc", ".mp3", ".mp2",
    ".m4a", ".m4b", ".aac", ".ogg", ".oga", ".opus", ".wma", ".ape",
    ".wv", ".alac", ".mka", ".au",
}


def main():
    folder = Path(__file__).resolve().parent
    output = folder / (folder.name + ".flac")
    if output.exists():
        raise RuntimeError(f"Output already exists; move it before rerunning: {output}")
    for tool in ("flac", "ffmpeg"):
        if shutil.which(tool) is None:
            raise RuntimeError(f"Required command not found: {tool}")
    tracks = sorted(p for p in folder.iterdir()
                    if p.is_file() and p.suffix.lower() in AUDIO_EXTENSIONS)
    if not 1 <= len(tracks) <= 99:
        raise RuntimeError("Expected between 1 and 99 supported audio tracks beside this script.")

    with tempfile.TemporaryDirectory(prefix=".bundle-flac-", dir=folder) as scratch:
        scratch = Path(scratch)
        wav_path = scratch / "album.wav"
        cue_path = scratch / "album.cue"
        cue = ['FILE "album.wav" WAVE']
        position = 0
        with wave.open(str(wav_path), "wb") as wav:
            wav.setparams((2, 2, 44100, 0, "NONE", "not compressed"))
            for number, track in enumerate(tracks, 1):
                frames = position // 588
                cue.extend([
                    f"  TRACK {number:02d} AUDIO",
                    f"    INDEX 01 {frames // 4500:02d}:{frames // 75 % 60:02d}:{frames % 75:02d}",
                ])
                print(f"[{number}/{len(tracks)}] {track.name}", flush=True)
                with subprocess.Popen([
                    "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-xerror",
                    "-i", str(track), "-map", "0:a:0", "-vn", "-sn", "-dn",
                    "-af", "aresample=44100:filter_size=64:dither_method=triangular",
                    "-ar", "44100", "-ac", "2", "-c:a", "pcm_s16le", "-f", "s16le", "pipe:1",
                ], stdout=subprocess.PIPE) as decoder:
                    decoded = 0
                    try:
                        while chunk := decoder.stdout.read(1024 * 1024):
                            wav.writeframesraw(chunk)
                            decoded += len(chunk)
                    except BaseException:
                        decoder.kill()
                        raise
                    if decoder.wait() != 0 or decoded == 0 or decoded % 4:
                        raise RuntimeError(f"Could not decode complete track: {track.name}")
                samples = decoded // 4
                padding = (-samples) % 588
                if padding:
                    wav.writeframesraw(b"\0" * (padding * 4))
                    print(f"  CD alignment: added {padding / 44.1:.2f} ms of silence.")
                position += samples + padding

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
