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
    bool replay_ready = false;
    std::uint64_t submitted = 0;
    unsigned resets = 0;
    unsigned discards = 0;
    unsigned go_commands = 0;
    unsigned replay_launches = 0;
    unsigned releases = 0;
    unsigned buffered_bytes = 0;
    unsigned transfer_calls = 0;
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
        "seek_pending = true;",
        "seek continued without reset",
        "seek target ready; download reset",
        "retain_clean_eof = seek_controls;",
        "playback_source_spec = requested_source;",
        "bool retain = clean && retain_clean_eof;",
        "replay_ready = arm_replay;",
        "input != MEDIAPLAYER_INPUT_PLAY_PAUSE || !replay_ready",
        "retain ? \"eof-replay-ready\" : \"eof\"",
        "replay ready and paused; press Play to restart",
        "audio_visualizer_controls &&",
        "activity-command-error",
        "if (helper_fd < 0 || chapter_barrier) return;",
        "navigation_pending = true;\n+\t\tif (!send_control(command))",
        "read_errno == EINTR)\n+\t\t\t\treturn;",
        "if (!stream_boundary_pending ||\n+\t\t\t\t    pending_size == pending_offset)",
        "DVD stream boundary pipe quiescent odd_tail=%u",
        "DVD stream boundary released after drain",
        "if (playback_paused && !stream_boundary_pending) return;",
        "if (!pending_eof && !stream_boundary_pending) available &= ~1u;"
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
    failed |= require_patch_markers(argv[1]);
    if (failed)
        return 1;
    std::cout << "main seek lifecycle PASS no-op_resets=0 valid_resets=1 "
                 "directional_navigation=continue-or-ready "
                 "automatic_boundary=drain-reset-go "
                 "clean_eof=replay-ready play=relaunch "
                 "failed_eof=released\n";
    return 0;
}
