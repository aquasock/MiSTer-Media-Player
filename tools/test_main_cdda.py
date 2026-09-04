#!/usr/bin/env python3
"""Static contract checks for Audio CD picker, Main routing and helper dispatch."""

from pathlib import Path
import sys


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    if len(sys.argv) != 4:
        print(
            f"usage: {sys.argv[0]} MEDIA_PLAYER_SV MAIN_PATCH HELPER_SOURCE",
            file=sys.stderr,
        )
        return 2

    core = Path(sys.argv[1]).read_text(encoding="utf-8")
    patch = Path(sys.argv[2]).read_text(encoding="utf-8")
    helper = Path(sys.argv[3]).read_text(encoding="utf-8")
    markers = (
        '!strcasecmp(extension, ".cd")',
        'source_spec = "cdda:/dev/sr0"',
        'track_controls = !strncasecmp(requested_source.c_str(), "cdda:", 5)',
        'seek_controls = track_controls ||',
        'audio_visualizer_controls = track_controls ||',
        'if (track_controls)',
        'seek_pending = true;',
        'Audio CD track command=%s',
    )

    require('"F1,WAVMP3FLCOGGCD,Open WAV, MP3, FLAC, OGG;"' in core,
            "Audio CD extension is missing from the audio picker")
    for marker in markers:
        require(marker in patch, f"missing Main Audio CD contract: {marker}")
    require(patch.index('if (track_controls)') <
            patch.index('chapter startup blank rearmed command=%s'),
            "track controls would enter the eager DVD chapter reset path")
    require('if (!strcasecmp(extension, ".dvd")) source_spec = '
            '"dvdmenu:/dev/sr0";' in patch,
            "Audio CD routing changed the DVD launcher")
    helper_markers = (
        "is_cdda = !strncmp(source_specification, MEDIA_PLAYER_CDDA_PREFIX,",
        "if (!is_cdda &&\n        media_source_open",
        "else if (!is_cdda && !is_wav && !is_flac && !is_ogg &&",
        "if (!is_cdda && media_source_prepare",
        "if (is_cdda) {\n        if (process_cdda_stream",
        "MEDIA_PLAYER_CONTROL_SEEK_CONTINUE",
        "cdda_complete_reposition",
    )
    for marker in helper_markers:
        require(marker in helper, f"missing helper Audio CD contract: {marker}")

    print("Audio CD picker/Main/helper contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
