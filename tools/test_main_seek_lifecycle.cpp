#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

enum class ControlEvent {
    ready,
    seek_continue
};

struct MainLifecycle {
    bool download_active = true;
    bool seek_pending = false;
    bool chapter_barrier = false;
    bool playback_paused = false;
    bool replay_ready = false;
    std::uint64_t submitted = 0;
    unsigned resets = 0;
    unsigned discards = 0;
    unsigned go_commands = 0;
    unsigned replay_launches = 0;
    unsigned releases = 0;

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
        "activity-command-error"
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
                 "clean_eof=replay-ready play=relaunch "
                 "failed_eof=released\n";
    return 0;
}
