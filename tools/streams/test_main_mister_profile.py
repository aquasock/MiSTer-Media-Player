#!/usr/bin/env python3
"""Exercise the real integration patch with deterministic host/register mocks.

Run on the build PC with --main-source pointing at a Main_MiSTer checkout
containing the pinned commit. No checkout is changed; no hardware is accessed.
The compiler runs two harnesses: transfer trace equivalence against upstream,
and the complete patched media loader with fake pipe, clock and log endpoints.
This checks software invariants, not physical bridge throughput or timing.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile

PIN = "0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f"
ROOT = Path(__file__).resolve().parents[2]


def function(source: str, name: str) -> str:
    match = re.search(r"^[\w :*&]+\b" + re.escape(name) + r"\([^;]*?\)\n\{", source, re.M)
    if not match:
        raise ValueError(f"function not found: {name}")
    start = match.start()
    brace = source.index("{", match.start())
    depth = 1
    pos = brace + 1
    while depth:
        depth += (source[pos] == "{") - (source[pos] == "}")
        pos += 1
    return source[start:pos] + "\n"


TRANSPORT_PRELUDE = r'''
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <string>
#include <vector>
#include <algorithm>
static const uint32_t SSPI_STROBE = 1u << 17;
static const uint32_t SSPI_ACK = 1u << 17;
static const int FIO_FILE_TX_DAT = 0x54;
static uint32_t gpo_copy;
static int fio_size, resets;
static std::deque<int> responses;
static std::vector<uint64_t> trace;
static uint32_t fpga_gpo_read() { return gpo_copy; }
static void fpga_gpo_write(uint32_t v) { gpo_copy = v; trace.push_back(v); }
static int fpga_gpi_read() {
    assert(!responses.empty()); int v = responses.front(); responses.pop_front();
    trace.push_back((1ull << 40) | uint32_t(v)); return v;
}
static void fpga_wait_to_reset() { ++resets; }
static void EnableFpga() { trace.push_back(2ull << 40); }
static void DisableFpga() { trace.push_back(3ull << 40); }
static void spi8(int v) { trace.push_back((4ull << 40) | unsigned(v)); }
'''

TRANSPORT_TESTS = r'''
static void reset_io(const std::deque<int> &input) {
    responses = input; trace.clear(); resets = 0; gpo_copy = 0x80040000;
}
int main() {
    unsigned cases = 0;
    for (int wide : {0, 1}) for (unsigned size : {0u, 1u, 2u, 3u, 17u, 16384u}) {
        fio_size = wide;
        std::vector<uint8_t> bytes(size + 2);
        for (unsigned i = 0; i < size; ++i) bytes[i] = uint8_t(i * 37 + 19);
        const unsigned words = wide ? (size + 1) / 2 : size;
        std::deque<int> input;
        uint64_t high = 0, low = 0, high_words = 0, low_words = 0;
        uint64_t max_high = 0, max_low = 0;
        for (unsigned w = 0; w < words; ++w) {
            unsigned h = w % 4, l = (w * 3) % 5;
            for (unsigned i = 0; i < h; ++i) input.push_back(0);
            input.push_back(SSPI_ACK | (w & 65535));
            for (unsigned i = 0; i < l; ++i) input.push_back(SSPI_ACK);
            input.push_back(w & 65535);
            high += h + 1; low += l + 1;
            high_words += h != 0; low_words += l != 0;
            max_high = std::max(max_high, uint64_t(h + 1));
            max_low = std::max(max_low, uint64_t(l + 1));
        }
        reset_io(input);
        user_io_file_tx_data(bytes.data(), size);
        assert(responses.empty()); const auto expected = trace;
        reset_io(input); fpga_spi_profile profile = {};
        user_io_file_tx_data_profiled(bytes.data(), size, &profile);
        assert(responses.empty() && trace == expected && resets == 0);
        assert(profile.words == words && profile.high_reads == high && profile.low_reads == low);
        assert(profile.high_wait_words == high_words && profile.low_wait_words == low_words);
        assert(profile.high_max_reads == max_high && profile.low_max_reads == max_low);
        assert(profile.uninitialized == 0); ++cases;
    }
    // Both ACK loops must preserve the upstream uninitialized-FPGA handling.
    for (const auto &input : {std::deque<int>{-1}, std::deque<int>{int(SSPI_ACK), -1}}) {
        reset_io(input); uint16_t expected_value = fpga_spi(0x1234);
        const auto expected = trace; assert(resets == 1);
        reset_io(input); fpga_spi_profile profile = {};
        assert(fpga_spi_profiled(0x1234, &profile) == expected_value);
        assert(trace == expected && resets == 1 && profile.uninitialized == 1);
        ++cases;
    }
    puts("PASS transport: 14 cases; byte/word/framing/ACK traces match upstream, including delayed ACKs and odd tails");
    assert(cases == 14);
}
'''

LOADER_PRELUDE = r'''
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <string>
#include <strings.h>
#include <deque>
#include <vector>
#include <signal.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include "fpga_io.h"
static uint64_t fake_us = 100;
static std::string log_text;
static std::deque<int> pipe_reads;
static std::vector<uint8_t> delivered;
static std::vector<unsigned> sampled_events;
static bool correct_core = true;
static bool fail_open = false;
static unsigned mock_tx_calls = 0, releases = 0, closes = 0;
static int fake_clock(clockid_t, timespec *ts) {
    ts->tv_sec = fake_us / 1000000; ts->tv_nsec = (fake_us % 1000000) * 1000;
    errno = ERANGE; // A measurement must not overwrite a captured read errno.
    return 0;
}
static ssize_t fake_read(int fd, void *buf, size_t size) {
    assert(fd == 42 && !pipe_reads.empty());
    int n = pipe_reads.front(); pipe_reads.pop_front(); fake_us += 3;
    if (n < 0) { errno = -n; return -1; }
    assert(size_t(n) <= size);
    for (int i = 0; i < n; ++i) static_cast<uint8_t *>(buf)[i] = uint8_t(i * 29 + mock_tx_calls);
    return n;
}
static ssize_t fake_write(int fd, const void *buf, size_t size) {
    assert(fd == 99); log_text.append(static_cast<const char *>(buf), size); fake_us += 2;
    return size;
}
static int fake_open(const char *, int, ...) { return fail_open ? -1 : 99; }
static int fake_close(int) { ++closes; return 0; }
static int fake_fsync(int) { return 0; }
static const char *user_io_get_core_name(int = 0) { return correct_core ? "MediaPlayer" : "Other"; }
static const char *getFullPath(const char *p) { return p; }
static void user_io_set_download(int on) { if (!on) ++releases; }
static void user_io_set_index(unsigned char) {}
static void user_io_file_info(const char *) {}
int mediaplayer_start_source(const char *, unsigned char);
static void user_io_file_tx_data(const uint8_t *data, uint32_t size) {
    delivered.insert(delivered.end(), data, data + size); ++mock_tx_calls; fake_us += 11;
}
static void user_io_file_tx_data_profiled(const uint8_t *data, uint32_t size, fpga_spi_profile *p) {
    sampled_events.push_back(mock_tx_calls + 1); p->words = (size + 1) / 2;
    p->high_reads = p->words * 2; p->low_reads = p->words;
    p->high_wait_words = p->words; p->high_max_reads = 2; p->low_max_reads = 1;
    user_io_file_tx_data(data, size);
}
#define clock_gettime fake_clock
#define read fake_read
#define write fake_write
#define open fake_open
#define close fake_close
#define fsync fake_fsync
'''

LOADER_TESTS = r'''
static size_t occurrences(const std::string &needle) {
    size_t result = 0, at = 0;
    while ((at = log_text.find(needle, at)) != std::string::npos) { ++result; at += needle.size(); }
    return result;
}
static void session() {
    helper_fd = -1; helper_pid = -1; diagnostic_close(); log_text.clear();
    delivered.clear(); sampled_events.clear(); pipe_reads.clear(); mock_tx_calls = 0;
    releases = closes = 0; correct_core = true; fail_open = false;
    diagnostic_open("file:test.m2v", 1); helper_fd = 42; helper_pid = -1;
    download_active = 1; download_assert_us = fake_us;
}
int main() {
    session();
    pipe_reads = {-EAGAIN}; mediaplayer_poll();
    assert(would_block_events == 1 && helper_fd == 42 && releases == 0);
    assert(transfer_profile.polls == 1 && transfer_profile.read_us == 3);
    assert(transfer_profile.data_polls == 0 && mock_tx_calls == 0);
    const uint64_t after_empty = fake_us; fake_us += 500;
    for (int i = 0; i < 65; ++i) pipe_reads.push_back(16384);
    pipe_reads.push_back(3); pipe_reads.push_back(0);
    mediaplayer_poll();
    assert(mock_tx_calls == 4 && pipe_reads.size() == 63); // Four chunks, no fifth read.
    assert(transfer_profile.poll_interval >= fake_us - after_empty - 100);
    while (helper_fd >= 0) { fake_us += 17; mediaplayer_poll(); }
    assert(mock_tx_calls == 66 && delivered.size() == 65 * 16384 + 3);
    assert(read_events == 66 && submitted_bytes == delivered.size());
    assert(sampled_events == std::vector<unsigned>{64});
    size_t at = 0;
    for (unsigned event = 0; event < 66; ++event) {
        unsigned size = event == 65 ? 3 : 16384;
        for (unsigned i = 0; i < size; ++i) assert(delivered[at++] == uint8_t(i * 29 + event));
    }
    assert(transfer_profile.read_calls == 68 && transfer_profile.read_us == 68 * 3);
    assert(transfer_profile.tx_calls == 66 && transfer_profile.tx_us == 66 * 11);
    assert(transfer_profile.tx_max_us == 11 && transfer_profile.ack_chunks == 1);
    assert(transfer_profile.polls == 18 && transfer_profile.data_polls == 17);
    assert(transfer_profile.intervals == 17 && !transfer_profile.poll_active);
    assert(releases == 1 && diagnostic_fd == -1 && helper_fd == -1);
    assert(occurrences("first_read latency_us=") == 1 && occurrences("first_byte latency_us=") == 1);
    assert(occurrences("profile_ack event=64 ") == 1 && occurrences("profile_summary ") == 1);
    assert(log_text.find("read event=66 count=3 submitted=1064963 read_us=3 tx_us=11 ack_sample=0") != std::string::npos);
    assert(log_text.find("finish reason=eof") != std::string::npos);
    const auto saved = transfer_profile; const auto length = log_text.size();
    mediaplayer_poll(); diagnostic_close();
    assert(transfer_profile.polls == saved.polls && log_text.size() == length);
    puts("PASS loader: sampled 66-chunk session, EAGAIN, four-read budget, byte order, odd tail, EOF totals and idle no-op");

    // Reset sampling and all profiling totals on a warm session.
    session(); pipe_reads = {1, 0}; mediaplayer_poll();
    assert(transfer_profile.polls == 1 && transfer_profile.tx_calls == 1);
    assert(transfer_profile.intervals == 0 && sampled_events.empty());
    assert(occurrences("profile_summary ") == 1 && delivered.size() == 1);
    session(); pipe_reads = {-EIO}; mediaplayer_poll();
    assert(log_text.find("finish reason=read-error") != std::string::npos);
    assert(log_text.find("read failed errno=5 ") != std::string::npos);
    assert(transfer_profile.polls == 1 && transfer_profile.read_us == 3);
    assert(transfer_profile.tx_calls == 0 && releases == 1);
    session(); correct_core = false; mediaplayer_poll();
    assert(log_text.find("stop reason=core-changed") != std::string::npos);
    assert(transfer_profile.polls == 1 && transfer_profile.read_calls == 0 && releases == 1);
    session(); pipe_reads = {7, -EAGAIN}; mediaplayer_poll();
    mediaplayer_stop();
    assert(occurrences("profile_summary ") == 1 && releases == 1 && !transfer_profile.poll_active);
    puts("PASS loader: warm reset, read-error errno retention, core-change and external-stop exits");

    session(); diagnostic_close(); log_text.clear(); fail_open = true;
    diagnostic_open("file:test.m2v", 1); helper_fd = 42; download_active = 1;
    pipe_reads = {16384, 0}; const auto prior_polls = transfer_profile.polls;
    mediaplayer_poll();
    assert(log_text.empty() && sampled_events.empty() && transfer_profile.polls == prior_polls);
    assert(delivered.size() == 16384 && helper_fd == -1);
    puts("PASS loader: unavailable diagnostic endpoint preserves ordinary transfer without sampling");
}
'''


def run(main_source: Path, compiler: str, sanitize: bool) -> dict:
    def upstream(name: str) -> str:
        return subprocess.check_output(["git", "-C", str(main_source), "show", f"{PIN}:{name}"], text=True)

    with tempfile.TemporaryDirectory(prefix="main-profile-test-") as temporary:
        work = Path(temporary)
        for name in ("menu.cpp", "user_io.cpp", "user_io.h", "fpga_io.cpp", "fpga_io.h"):
            (work / name).write_text(upstream(name))
        patch = ROOT / "host/main_mister/0001-mediaplayer-arm-loader.patch"
        subprocess.run(["git", "apply", "--check", str(patch)], cwd=work, check=True)
        subprocess.run(["git", "apply", str(patch)], cwd=work, check=True)
        fpga = (work / "fpga_io.cpp").read_text()
        io = (work / "user_io.cpp").read_text()
        struct = re.search(r"struct fpga_spi_profile\n\{.*?\n\};", (work / "fpga_io.h").read_text(), re.S)[0]
        (work / "fpga_io.h").write_text("#pragma once\n#include <stdint.h>\n" + struct + "\n")
        ordinary = function(upstream("fpga_io.cpp"), "fpga_spi")
        assert ordinary == function(fpga, "fpga_spi"), "Unsampled ACK path changed"
        transport = TRANSPORT_PRELUDE + struct + "\n" + ordinary
        transport += "static uint16_t spi_w(uint16_t w) { return fpga_spi(w); }\n"
        transport += "static uint8_t spi_b(uint8_t w) { return uint8_t(fpga_spi(w)); }\n"
        transport += function(upstream("spi.cpp"), "spi_write")
        transport += function(fpga, "fpga_spi_profiled")
        transport += function(io, "user_io_file_tx_data")
        transport += function(io, "user_io_file_tx_data_profiled") + TRANSPORT_TESTS
        loader = (work / "support/mediaplayer/mediaplayer.cpp").read_text()
        loader = re.sub(r"^#include .*\n", "", loader, flags=re.M)
        reports = {}
        for name, source in (("transport", transport), ("loader", LOADER_PRELUDE + loader + LOADER_TESTS)):
            cpp = work / f"{name}_test.cpp"
            cpp.write_text(source)
            executable = work / name
            command = [compiler, "-std=c++14", "-O2", "-Wall", "-Wextra", "-Werror", "-I", str(work)]
            if sanitize:
                command += ["-fsanitize=address,undefined", "-fno-omit-frame-pointer"]
            subprocess.run(command + [str(cpp), "-o", str(executable)], check=True)
            result = subprocess.run([str(executable)], check=True, text=True, capture_output=True)
            reports[name] = result.stdout
            print(result.stdout, end="")
        return {"pinned_main_commit": PIN, "compiler": compiler, "sanitizers": sanitize, "reports": reports}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--main-source", required=True, type=Path)
    ap.add_argument("--compiler", default="g++")
    ap.add_argument("--sanitize", action="store_true")
    ap.add_argument("--report", type=Path)
    args = ap.parse_args()
    report = run(args.main_source.resolve(), args.compiler, args.sanitize)
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
