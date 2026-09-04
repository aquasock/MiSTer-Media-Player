#!/usr/bin/env python3
"""Static contract checks for MediaPlayer loader menus and source routing."""

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
    helper_path = Path(sys.argv[3])
    helper = helper_path.read_text(encoding="utf-8")
    protocol = helper_path.with_name("media_player_protocol.h").read_text(
        encoding="utf-8"
    )
    menu_entries = (
        '"P1,Load Physical Disc;"',
        '"P1F1,DVD,Video DVD;"',
        '"P1F2,CD,Audio CD;"',
        '"P2,Load Disc Image;"',
        '"P2F3,ISO,Video DVD;"',
        '"F4,M2VMPGMPEVOB,Load MPEG-2 Video File;"',
        '"F5,WAVMP3FLCOGG,Load Audio File;"',
    )
    for entry in menu_entries:
        require(entry in core, f"missing loader menu entry: {entry}")
    require(all(core.index(first) < core.index(second)
                for first, second in zip(menu_entries, menu_entries[1:])),
            "loader menu entries are out of order")
    require('Open WAV, MP3, FLAC, OGG' not in core and
            'Open MPEG-2 Video' not in core and 'Load Disk;' not in core,
            "legacy flat loader menu remains")

    asset_root = Path(sys.argv[1]).parent / "assets"
    require(not (asset_root / "Video DVD.dvd").exists(),
            "obsolete Video DVD marker remains")
    require(not (asset_root / "Audio CD.cd").exists(),
            "obsolete Audio CD marker remains")

    markers = (
        'MEDIAPLAYER_STREAM_INDEX = 1',
        'MEDIAPLAYER_LOADER_PHYSICAL_DVD = 1',
        'MEDIAPLAYER_LOADER_PHYSICAL_CD = 2',
        'MEDIAPLAYER_LOADER_DVD_ISO = 3',
        'MEDIAPLAYER_LOADER_VIDEO_FILE = 4',
        'MEDIAPLAYER_LOADER_AUDIO_FILE = 5',
        'mediaplayer_is_physical_loader(num)',
        'mediaplayer_start_physical(ioctl_index)',
        '"dvdmenu:/dev/sr0"',
        '"cdda:/dev/sr0"',
        'loader != MEDIAPLAYER_LOADER_DVD_ISO',
        'loader != MEDIAPLAYER_LOADER_VIDEO_FILE',
        'loader != MEDIAPLAYER_LOADER_AUDIO_FILE',
        'mediaplayer_start_source(source_spec.c_str(), MEDIAPLAYER_STREAM_INDEX)',
        'track_controls = !strncasecmp(requested_source.c_str(), "cdda:", 5)',
        'seek_controls = track_controls ||',
        'audio_visualizer_controls = track_controls ||',
        'MEDIA_CONTROL_PAUSE = 0x11',
        'MEDIA_CONTROL_PAUSE_READY = 0x87',
        'pause_pending = true;',
        'pause_barrier_finish();',
        'if (track_controls)',
        'seek_pending = true;',
        'Audio CD track command=%s',
        'static bool idle_session = false;',
        'static bool idle_retry_blocked = false;',
        'return mediaplayer_start_session(source_spec, index, false);',
        'telemetry_enabled = !idle && user_io_status_get("[125]");',
        'return mediaplayer_start_session("idle:", MEDIAPLAYER_STREAM_INDEX, true);',
        'if (idle_session)',
        'if (was_idle) idle_retry_blocked = true;',
        'if (block_idle_retry) idle_retry_blocked = true;',
        'if (!idle_retry_blocked && !mediaplayer_start_idle())',
    )

    for marker in markers:
        require(marker in patch, f"missing Main loader contract: {marker}")
    require(patch.index('if (track_controls)') <
            patch.index('chapter startup blank rearmed command=%s'),
            "track controls would enter the eager DVD chapter reset path")
    require('!strcasecmp(extension, ".dvd")' not in patch and
            '!strcasecmp(extension, ".cd")' not in patch,
            "marker-extension routing remains in Main")
    helper_markers = (
        "!strcmp(source_specification, MEDIA_PLAYER_IDLE_PREFIX)",
        "is_cdda = !strncmp(source_specification, MEDIA_PLAYER_CDDA_PREFIX,",
        "if (!is_cdda && !is_idle_visualizer &&\n        media_source_open",
        "else if (!is_cdda && !is_idle_visualizer && !is_wav && !is_flac &&",
        "if (!is_cdda && !is_idle_visualizer &&\n        media_source_prepare",
        "if (is_idle_visualizer) {\n        if (process_idle_visualizer",
        "} else if (is_cdda) {\n        if (process_cdda_stream",
        "idle playback must not emit silent PCM",
        "MEDIA_PLAYER_CONTROL_SEEK_CONTINUE",
        "cdda_complete_reposition",
        "audio_pause_barrier(output, control->control_fd,",
        "audio_ui_set_playlist(output->audio_ui, playlist_tracks, track_count,",
        "audio_ui_set_current_track(",
        "cdda_reader_current_track_timing(reader, &track_start,",
        "cdda_reader_track_number(reader, track)",
        "audio_overlay_publish_full(output, current_frame)",
    )
    for marker in helper_markers:
        require(marker in helper, f"missing helper Audio CD contract: {marker}")
    require('#define MEDIA_PLAYER_IDLE_PREFIX "idle:"' in protocol and
            'sources=file,iso,dvd,isomenu,dvdmenu,cdda,idle' in protocol and
            '#define MEDIA_PLAYER_CONTROL_PAUSE             0x11' in protocol and
            '#define MEDIA_PLAYER_CONTROL_PAUSE_READY       0x87' in protocol,
            "missing idle visualizer protocol capability")

    print("MediaPlayer loader menu/Main/helper contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
