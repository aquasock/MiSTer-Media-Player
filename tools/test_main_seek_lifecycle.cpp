#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

enum class ControlEvent {
    ready,
    seek_continue
};

enum class NavigationEvent {
    ready,
    menu_continue
};

enum class PipeReadEvent {
    would_block,
    interrupted
};

struct MainLifecycle {
    bool download_active = true;
    bool seek_pending = false;
    bool navigation_pending = false;
    bool chapter_barrier = false;
    bool stream_boundary_pending = false;
    bool playback_paused = false;
    bool pause_pending = false;
    bool pause_ready = false;
    bool pause_pipe_empty = false;
    bool replay_ready = false;
    std::uint64_t submitted = 0;
    unsigned resets = 0;
    unsigned discards = 0;
    unsigned go_commands = 0;
    unsigned replay_launches = 0;
    unsigned releases = 0;
    unsigned buffered_bytes = 0;
    unsigned transfer_calls = 0;
    unsigned pause_commands = 0;
    bool stream_boundary_pipe_empty = false;

    void submit(std::uint64_t bytes)
    {
        if (!chapter_barrier)
            submitted += bytes;
        else
            discards += static_cast<unsigned>(bytes);
    }

    void request_seek()
    {
        if (seek_pending || chapter_barrier)
            throw "overlapping seek";
        seek_pending = true;
    }

    void request_navigation()
    {
        if (navigation_pending || chapter_barrier)
            throw "overlapping navigation";
        navigation_pending = true;
    }

    void control(ControlEvent event)
    {
        if (!seek_pending)
            throw "unexpected seek decision";
        if (event == ControlEvent::seek_continue) {
            seek_pending = false;
            return;
        }
        seek_pending = false;
        download_active = false;
        ++resets;
        chapter_barrier = true;
        download_active = true;
        ++go_commands;
        chapter_barrier = false;
    }

    void navigation_control(NavigationEvent event)
    {
        if (!navigation_pending)
            throw "unexpected navigation decision";
        navigation_pending = false;
        if (event == NavigationEvent::menu_continue)
            return;
        download_active = false;
        ++resets;
        chapter_barrier = true;
        download_active = true;
        ++go_commands;
        chapter_barrier = false;
    }

    void stream_boundary()
    {
        if (stream_boundary_pending)
            throw "duplicate stream boundary";
        stream_boundary_pending = true;
        stream_boundary_pipe_empty = false;
    }

    void buffer(unsigned bytes)
    {
        buffered_bytes += bytes;
    }

    void short_pipe_read(PipeReadEvent event)
    {
        if (event == PipeReadEvent::interrupted)
            return;
        if (!stream_boundary_pending || !buffered_bytes) {
            if (stream_boundary_pending && !buffered_bytes)
                stream_boundary_pipe_empty = true;
            return;
        }
        submit(buffered_bytes);
        ++transfer_calls;
        buffered_bytes = 0;
    }

    void stream_boundary_drained()
    {
        if (!stream_boundary_pending || !stream_boundary_pipe_empty ||
            buffered_bytes)
            throw "incomplete stream boundary drain";
        download_active = false;
        ++resets;
        download_active = true;
        ++go_commands;
        stream_boundary_pending = false;
        stream_boundary_pipe_empty = false;
    }

    void request_audio_pause()
    {
        if (playback_paused || pause_pending)
            throw "overlapping audio pause";
        pause_pending = true;
        pause_ready = false;
        pause_pipe_empty = false;
        ++pause_commands;
    }

    void pause_helper_ready()
    {
        if (!pause_pending)
            throw "pause ready without request";
        pause_ready = true;
    }

    void pause_read(unsigned bytes)
    {
        if (!pause_pending)
            throw "pause drain without request";
        pause_pipe_empty = false;
        submit(bytes);
    }

    void pause_pipe_quiescent()
    {
        if (!pause_pending)
            throw "pause quiescence without request";
        pause_pipe_empty = true;
    }

    void pause_finish()
    {
        if (!pause_pending || !pause_ready || !pause_pipe_empty)
            return;
        pause_pending = false;
        pause_ready = false;
        pause_pipe_empty = false;
        playback_paused = true;
    }

    void resume_audio()
    {
        if (!playback_paused || pause_pending)
            throw "audio resume outside paused state";
        playback_paused = false;
        ++go_commands;
    }

    void helper_eof(bool clean, bool file_source)
    {
        if (clean && file_source) {
            replay_ready = true;
            playback_paused = true;
        } else {
            download_active = false;
            replay_ready = false;
            playback_paused = false;
            ++releases;
        }
    }

    void play()
    {
        if (!replay_ready)
            throw "play without replay-ready state";
        download_active = false;
        ++resets;
        download_active = true;
        replay_ready = false;
        playback_paused = false;
        pause_pending = false;
        pause_ready = false;
        pause_pipe_empty = false;
        ++replay_launches;
    }

    void stop()
    {
        if (download_active) {
            download_active = false;
            ++releases;
        }
        replay_ready = false;
        playback_paused = false;
        pause_pending = false;
        pause_ready = false;
        pause_pipe_empty = false;
    }
};

struct IdleLifecycle {
    bool core_active = false;
    bool helper_active = false;
    bool idle_session = false;
    bool idle_retry_blocked = false;
    unsigned idle_launches = 0;
    unsigned media_takeovers = 0;

    void poll()
    {
        if (!core_active) {
            helper_active = false;
            idle_session = false;
            idle_retry_blocked = false;
            return;
        }
        if (!helper_active && !idle_retry_blocked) {
            helper_active = true;
            idle_session = true;
            ++idle_launches;
        }
    }

    void start_media()
    {
        helper_active = true;
        idle_session = false;
        idle_retry_blocked = false;
        ++media_takeovers;
    }

    void playback_eof()
    {
        helper_active = false;
        idle_session = false;
    }

    void idle_error()
    {
        if (!idle_session)
            throw "idle error outside idle session";
        helper_active = false;
        idle_session = false;
        idle_retry_blocked = true;
    }
};

static int require(bool condition, const char *message)
{
    if (condition)
        return 0;
    std::cerr << "main lifecycle: " << message << '\n';
    return 1;
}

static int require_patch_markers(const char *path)
{
    static const char *const markers[] = {
        "MEDIA_CONTROL_SEEK_CONTINUE = 0x85",
        "MEDIA_CONTROL_STREAM_BOUNDARY = 0x86",
        "MEDIA_CONTROL_USER_ACTIVITY = 0x10",
        "MEDIA_CONTROL_PAUSE = 0x11",
        "MEDIA_CONTROL_PAUSE_READY = 0x87",
        "seek_pending = true;",
        "seek continued without reset",
        "seek target ready; download reset",
        "retain_clean_eof = !idle && seek_controls;",
        "if (!idle) playback_source_spec = requested_source;",
        "bool retain = clean && retain_clean_eof;",
        "if (!was_idle) replay_ready = arm_replay;",
        "input != MEDIAPLAYER_INPUT_PLAY_PAUSE || !replay_ready",
        "retain ? \"eof-replay-ready\" : \"eof\"",
        "replay ready and paused; press Play to restart",
        "if (audio_visualizer_controls)",
        "audio pause requested submitted=%llu",
        "audio pause helper ready submitted=%llu buffered=%u",
        "audio playback paused submitted=%llu",
        "pause_barrier_finish();",
        "if (helper_fd < 0 || chapter_barrier) return;",
        "navigation_pending = true;\n+\t\tif (!send_control(command))",
        "read_errno == EINTR)\n+\t\t\t\treturn;",
        "if ((!stream_boundary_pending && !pause_pending) ||",
        "stream_boundary_pending ?\n+\t\t\t\t                     \"DVD stream boundary\" : \"audio pause\"",
        "DVD stream boundary released after drain",
        "if (playback_paused && !stream_boundary_pending) return;",
        "if (!pending_eof && !stream_boundary_pending && !pause_pending)",
        "return mediaplayer_start_session(\"idle:\", MEDIAPLAYER_STREAM_INDEX, true);",
        "telemetry_enabled = !idle && user_io_status_get(\"[125]\");",
        "if (idle_session)",
        "if (was_idle) idle_retry_blocked = true;",
        "if (block_idle_retry) idle_retry_blocked = true;",
        "if (!idle_retry_blocked && !mediaplayer_start_idle())"
    };
    std::ifstream input(path);

    if (!input)
        return require(false, "cannot open Main patch");
    std::string patch((std::istreambuf_iterator<char>(input)),
                      std::istreambuf_iterator<char>());
    int failed = 0;

    for (const char *marker : markers)
        failed |= require(patch.find(marker) != std::string::npos,
                          marker);
    failed |= require(
        patch.find("if (command != MEDIA_CONTROL_MENU_ACTIVATE &&") ==
            std::string::npos,
        "directional menu command bypasses the navigation decision");
    return failed;
}

int main(int argc, char **argv)
{
    int failed = 0;

    if (argc != 2) {
        std::cerr << "usage: " << argv[0] << " MAIN_PATCH\n";
        return 2;
    }

    MainLifecycle boundary;
    boundary.submit(4096);
    boundary.request_seek();
    boundary.submit(8192);
    boundary.control(ControlEvent::seek_continue);
    boundary.submit(16384);
    failed |= require(boundary.download_active,
                      "no-op seek released download");
    failed |= require(!boundary.seek_pending && !boundary.chapter_barrier,
                      "no-op seek left a pending state");
    failed |= require(boundary.resets == 0 && boundary.discards == 0 &&
                          boundary.go_commands == 0,
                      "no-op seek reset or discarded output");
    failed |= require(boundary.submitted == 28672,
                      "no-op seek stopped submitted output");

    boundary.request_seek();
    boundary.submit(2048);
    boundary.control(ControlEvent::ready);
    boundary.submit(4096);
    failed |= require(boundary.download_active && !boundary.seek_pending &&
                          !boundary.chapter_barrier,
                      "valid seek did not leave playback active");
    failed |= require(boundary.resets == 1 && boundary.go_commands == 1,
                      "valid seek did not use exactly one reset and GO");
    failed |= require(boundary.discards == 0,
                      "seek decision phase discarded active output");

    MainLifecycle directional_continue_boundary;
    directional_continue_boundary.submit(4096);
    directional_continue_boundary.request_navigation();
    directional_continue_boundary.submit(8192);
    directional_continue_boundary.navigation_control(
        NavigationEvent::menu_continue);
    directional_continue_boundary.submit(16384);
    failed |= require(directional_continue_boundary.download_active &&
                          !directional_continue_boundary.navigation_pending &&
                          !directional_continue_boundary.chapter_barrier,
                      "directional continuation left a pending state");
    failed |= require(directional_continue_boundary.resets == 0 &&
                          directional_continue_boundary.discards == 0 &&
                          directional_continue_boundary.go_commands == 0,
                      "directional continuation reset or discarded output");
    failed |= require(directional_continue_boundary.submitted == 28672,
                      "directional continuation stopped submitted output");

    MainLifecycle navigation_hop_boundary;
    navigation_hop_boundary.submit(4096);
    navigation_hop_boundary.request_navigation();
    navigation_hop_boundary.submit(8192);
    navigation_hop_boundary.navigation_control(NavigationEvent::ready);
    navigation_hop_boundary.submit(16384);
    failed |= require(navigation_hop_boundary.download_active &&
                          !navigation_hop_boundary.navigation_pending &&
                          !navigation_hop_boundary.chapter_barrier,
                      "navigation hop did not leave playback active");
    failed |= require(navigation_hop_boundary.resets == 1 &&
                          navigation_hop_boundary.go_commands == 1,
                      "navigation hop did not use one reset and GO");
    failed |= require(navigation_hop_boundary.discards == 0 &&
                          navigation_hop_boundary.submitted == 28672,
                      "navigation decision phase lost submitted output");

    MainLifecycle ordinary_lone_byte;
    ordinary_lone_byte.buffer(1);
    ordinary_lone_byte.short_pipe_read(PipeReadEvent::would_block);
    failed |= require(ordinary_lone_byte.buffered_bytes == 1 &&
                          ordinary_lone_byte.transfer_calls == 0 &&
                          ordinary_lone_byte.submitted == 0,
                      "ordinary lone byte was padded in the middle of a stream");

    MainLifecycle automatic_boundary;
    automatic_boundary.submit(224682);
    automatic_boundary.buffer(1);
    automatic_boundary.stream_boundary();
    automatic_boundary.short_pipe_read(PipeReadEvent::interrupted);
    failed |= require(automatic_boundary.stream_boundary_pending &&
                          automatic_boundary.buffered_bytes == 1 &&
                          automatic_boundary.transfer_calls == 0 &&
                          automatic_boundary.resets == 0 &&
                          automatic_boundary.go_commands == 0,
                      "interrupted boundary read changed the odd tail");
    automatic_boundary.short_pipe_read(PipeReadEvent::would_block);
    failed |= require(automatic_boundary.stream_boundary_pending &&
                          !automatic_boundary.stream_boundary_pipe_empty &&
                          automatic_boundary.buffered_bytes == 0 &&
                          automatic_boundary.transfer_calls == 1 &&
                          automatic_boundary.submitted == 224683 &&
                          automatic_boundary.resets == 0 &&
                          automatic_boundary.go_commands == 0,
                      "quiescent boundary did not submit its exact odd tail");
    automatic_boundary.short_pipe_read(PipeReadEvent::would_block);
    failed |= require(automatic_boundary.stream_boundary_pipe_empty,
                      "drained boundary did not observe an empty pipe");
    automatic_boundary.stream_boundary_drained();
    automatic_boundary.submit(9035621);
    failed |= require(automatic_boundary.download_active &&
                          !automatic_boundary.stream_boundary_pending &&
                          automatic_boundary.resets == 1 &&
                          automatic_boundary.go_commands == 1 &&
                          automatic_boundary.discards == 0 &&
                          automatic_boundary.submitted == 9260304,
                      "automatic boundary did not drain, reset once, and resume");

    MainLifecycle audio_pause;
    audio_pause.submit(4096);
    audio_pause.request_audio_pause();
    audio_pause.pause_read(8192);
    audio_pause.pause_pipe_quiescent();
    audio_pause.pause_finish();
    failed |= require(audio_pause.pause_pending &&
                          !audio_pause.playback_paused,
                      "audio pause completed before helper readiness");
    audio_pause.pause_helper_ready();
    audio_pause.pause_finish();
    failed |= require(!audio_pause.pause_pending &&
                          audio_pause.playback_paused &&
                          audio_pause.pause_commands == 1 &&
                          audio_pause.submitted == 12288,
                      "audio pause did not drain through ready and quiescence");
    audio_pause.resume_audio();
    audio_pause.submit(16384);
    failed |= require(!audio_pause.playback_paused &&
                          audio_pause.go_commands == 1 &&
                          audio_pause.submitted == 28672,
                      "audio resume did not release with one GO");

    boundary.helper_eof(true, true);
    failed |= require(boundary.download_active && boundary.replay_ready &&
                          boundary.playback_paused,
                      "clean file EOF did not arm paused replay");
    boundary.play();
    failed |= require(boundary.download_active && !boundary.replay_ready &&
                          !boundary.playback_paused &&
                          boundary.replay_launches == 1 &&
                          boundary.resets == 2,
                      "Play did not relaunch clean file from a fresh reset");

    MainLifecycle stopped_boundary;
    stopped_boundary.helper_eof(true, true);
    stopped_boundary.stop();
    failed |= require(!stopped_boundary.download_active &&
                          !stopped_boundary.replay_ready &&
                          !stopped_boundary.playback_paused,
                      "explicit stop retained replay state");

    MainLifecycle core_change_boundary;
    core_change_boundary.helper_eof(true, true);
    core_change_boundary.stop();
    failed |= require(!core_change_boundary.download_active &&
                          !core_change_boundary.replay_ready,
                      "core change retained replay state");

    MainLifecycle dvd_boundary;
    dvd_boundary.helper_eof(true, false);
    failed |= require(!dvd_boundary.download_active &&
                          !dvd_boundary.replay_ready,
                      "non-file EOF changed DVD lifecycle");
    MainLifecycle failed_boundary;
    failed_boundary.helper_eof(false, true);
    failed |= require(!failed_boundary.download_active &&
                          !failed_boundary.replay_ready,
                      "failed EOF retained presentation");

    IdleLifecycle idle;
    idle.core_active = true;
    idle.poll();
    idle.poll();
    failed |= require(idle.helper_active && idle.idle_session &&
                          idle.idle_launches == 1,
                      "core entry did not launch exactly one idle session");
    idle.start_media();
    failed |= require(idle.helper_active && !idle.idle_session &&
                          idle.media_takeovers == 1,
                      "media did not replace the idle session");
    idle.playback_eof();
    idle.poll();
    failed |= require(idle.idle_session && idle.idle_launches == 2,
                      "playback EOF did not restore the idle session");
    idle.idle_error();
    idle.poll();
    idle.poll();
    failed |= require(!idle.helper_active && idle.idle_retry_blocked &&
                          idle.idle_launches == 2,
                      "failed idle session entered a restart loop");
    idle.start_media();
    idle.playback_eof();
    idle.poll();
    failed |= require(idle.idle_session && !idle.idle_retry_blocked &&
                          idle.idle_launches == 3,
                      "successful media cycle did not rearm idle startup");
    idle.core_active = false;
    idle.poll();
    failed |= require(!idle.helper_active && !idle.idle_session &&
                          !idle.idle_retry_blocked,
                      "core exit retained idle lifecycle state");
    failed |= require_patch_markers(argv[1]);
    if (failed)
        return 1;
    std::cout << "main seek lifecycle PASS no-op_resets=0 valid_resets=1 "
                 "directional_navigation=continue-or-ready "
                 "automatic_boundary=drain-reset-go "
                 "audio_pause=reveal-drain-hold-go "
                 "clean_eof=replay-ready play=relaunch "
                 "failed_eof=released idle=takeover-restart-guarded\n";
    return 0;
}
