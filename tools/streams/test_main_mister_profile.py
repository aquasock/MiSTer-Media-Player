#!/usr/bin/env python3
"""Exercise the real integration patch with deterministic host/register mocks.

Run on the build PC with --main-source pointing at a Main_MiSTer checkout
containing the pinned commit. No checkout is changed; no hardware is accessed.
The compiler runs transport equivalence against upstream and the complete media
loader with fake pipe, clock and log endpoints. --rtl additionally exercises the
real host functions against handshake/download blocks extracted from current RTL.
This checks software invariants, not physical bridge throughput or timing.
"""

from __future__ import annotations

import argparse
import hashlib
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
// Low-phase payload changes intentionally differ. Compare every rising-edge
// payload, every ACK read and command/select framing, not those redundant writes.
static std::vector<uint64_t> observable_trace() {
    std::vector<uint64_t> result;
    for (auto v : trace) if ((v >> 40) || (v & SSPI_STROBE)) result.push_back(v);
    return result;
}
static unsigned writes() {
    unsigned n = 0; for (auto v : trace) n += !(v >> 40); return n;
}
int main() {
    unsigned cases = 0;
    for (int wide : {0, 1}) for (unsigned size : {0u, 1u, 2u, 3u, 17u, 16383u, 16384u}) {
        fio_size = wide;
        std::vector<uint8_t> bytes(size), unaligned(size + 1);
        for (unsigned i = 0; i < size; ++i) unaligned[i+1] = bytes[i] = uint8_t(i * 37 + 19);
        const unsigned words = wide ? (size + 1) / 2 : size;
        std::deque<int> input;
        uint64_t high = 0, low = 0, high_words = 0, low_words = 0;
        uint64_t max_high = 0, max_low = 0;
        for (unsigned w = 0; w < words; ++w) {
            unsigned h = w % 4, l = w % 13 == 0 ? 97 : (w * 3) % 5;
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
        assert(responses.empty() && writes() == 3 * words);
        const auto expected = observable_trace(); const auto final_gpo = gpo_copy;
        for (bool sampled : {false, true}) {
            reset_io(input); fpga_spi_profile profile = {};
            user_io_file_tx_data_ack(size ? unaligned.data()+1 : nullptr, size, sampled ? &profile : nullptr);
            assert(responses.empty() && observable_trace() == expected && resets == 0);
            assert(writes() == (words ? 2 * words + 1 : 0));
            assert(gpo_copy == final_gpo && !(gpo_copy & SSPI_STROBE));
            if (sampled) {
                assert(profile.words == words && profile.high_reads == high && profile.low_reads == low);
                assert(profile.high_wait_words == high_words && profile.low_wait_words == low_words);
                assert(profile.high_max_reads == max_high && profile.low_max_reads == max_low);
                assert(profile.uninitialized == 0);
            } else assert(profile.words == 0 && profile.high_reads == 0 && profile.low_reads == 0);
            ++cases;
        }
    }
    // Abort the bulk loop if the reset handler unexpectedly returns in this mock.
    // Cover either ACK phase at first, interior and final word without a further rise.
    for (bool sampled : {false, true}) for (unsigned fault_word : {0u, 2u, 4u}) for (bool low_phase : {false, true}) {
        std::deque<int> input;
        for (unsigned i=0; i<fault_word; ++i) { input.push_back(SSPI_ACK); input.push_back(0); }
        if (low_phase) input.push_back(SSPI_ACK);
        input.push_back(-1); reset_io(input);
        const uint8_t bytes[] = {1,2,3,4,5,6,7,8,9,10}; fpga_spi_profile profile = {};
        fpga_spi_write_ack(bytes, sizeof(bytes), 1, sampled ? &profile : nullptr);
        assert(resets == 1 && responses.empty());
        unsigned rises=0; for (auto v:trace) rises += !(v >> 40) && (v & SSPI_STROBE) != 0;
        assert(rises == fault_word + 1);
        if (sampled) assert(profile.uninitialized == 1 && profile.words == fault_word);
        ++cases;
    }
    assert(cases == 40);
    puts("PASS transport: 40 cases; word/ACK/framing equivalence, 3N to 2N+1 writes, final GPO, unaligned/odd tails and reset exits");
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
static void user_io_file_tx_data_ack(const uint8_t *data, uint32_t size, fpga_spi_profile *p) {
    if (p) {
        sampled_events.push_back(mock_tx_calls + 1); p->words = (size + 1) / 2;
        p->high_reads = p->words * 2; p->low_reads = p->words;
        p->high_wait_words = p->words; p->high_max_reads = 2; p->low_max_reads = 1;
    }
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
    assert(log_text.find("transport=ack_bulk_preload_v1") != std::string::npos);
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


RTL_PRELUDE = r'''
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <vector>
#include <algorithm>
#include "Vbridge.h"
static const uint32_t SSPI_STROBE = 1u << 17, SSPI_ACK = 1u << 17;
static const int FIO_FILE_TX_DAT = 0x54;
static std::unique_ptr<Vbridge> dut;
static uint32_t gpo_copy;
static int fio_size = TEST_WIDE;
static unsigned latency, stall_mode, occupancy, max_occupancy, reads, resets;
static uint64_t cycles;
static std::vector<uint16_t> accepted;
static unsigned case_size;
static bool case_bulk;
#undef assert
#define assert(c) do { if (!(c)) { fprintf(stderr, "RTL check failed: %s line=%d size=%u bulk=%d latency=%u stalls=%u cycle=%llu accepted=%zu occupancy=%u\n", #c, __LINE__, case_size, case_bulk, latency, stall_mode, (unsigned long long)cycles, accepted.size(), occupancy); abort(); } } while (0)
static void tick() {
    ++cycles;
    // Two-word test sink: hold full until a deliberately slow consumer drains.
    // Also vary wait independently, including the shared vs_wait gate.
    dut->io_wait = stall_mode && (occupancy >= 2 || (stall_mode == 2 && cycles % 113 < 37));
    dut->vs_wait = stall_mode == 2 && cycles % 211 < 29;
    dut->clk_sys = 0; dut->eval();
    const bool wr = dut->ioctl_wr;
    const uint16_t data = dut->ioctl_dout;
    dut->clk_sys = 1; dut->eval();
    if (wr) {
        accepted.push_back(data);
        if (stall_mode) { ++occupancy; max_occupancy = std::max(max_occupancy, occupancy); assert(occupancy <= 2); }
    }
    if (occupancy && cycles % 97 == 0) --occupancy;
}
static void fpga_gpo_write(uint32_t v) {
    gpo_copy = v; dut->gp_out = v;
    for (unsigned i=0; i<latency; ++i) tick();
}
static uint32_t fpga_gpo_read() { return gpo_copy; }
static int fpga_gpi_read() {
    assert(++reads < 10000000);
    for (unsigned i=0; i<latency; ++i) tick();
    return dut->io_ack ? SSPI_ACK : 0;
}
static void fpga_wait_to_reset() { ++resets; assert(false); }
static void EnableFpga() { fpga_gpo_write(gpo_copy | (1u << 18)); }
static void DisableFpga() { fpga_gpo_write(gpo_copy & ~(1u << 18)); }
uint16_t fpga_spi(uint16_t);
static void spi8(int v) { fpga_spi(uint16_t(v)); }
'''

RTL_TESTS = r'''
static void begin_session() {
    dut.reset(new Vbridge); accepted.clear(); occupancy = max_occupancy = reads = resets = 0; cycles = 0;
    gpo_copy = 0x80000000; dut->gp_out = gpo_copy;
    for (int i=0; i<12; ++i) tick();
    EnableFpga(); spi8(0x53); fpga_spi(1); DisableFpga();
    for (int i=0; i<8; ++i) tick();
    assert(dut->ioctl_download);
}
static std::vector<uint16_t> packed(const std::vector<uint8_t> &bytes) {
    std::vector<uint16_t> result;
    for (size_t i=0; i<bytes.size();) {
        uint16_t v=bytes[i++]; if (TEST_WIDE && i<bytes.size()) v |= uint16_t(bytes[i++]) << 8;
        result.push_back(v);
    }
    return result;
}
int main() {
    unsigned cases=0, backpressured=0;
    for (unsigned delay : {1u, 2u, 5u, 13u}) for (unsigned stalls : {0u, 1u, 2u})
    for (unsigned size : {0u, 1u, 2u, 3u, 17u, 4097u, 16384u}) for (bool sample : {false, true}) {
        latency=delay; stall_mode=stalls;
        std::vector<uint8_t> bytes(size), tail(17);
        for (unsigned i=0; i<size; ++i) bytes[i]=uint8_t(i*37+19);
        for (unsigned i=0; i<tail.size(); ++i) tail[i]=uint8_t(i*13+77);
        auto expected=packed(bytes); const auto ending=packed(tail);
        expected.insert(expected.end(), ending.begin(), ending.end());
        for (bool bulk : {false, true}) {
            case_size = size; case_bulk = bulk;
            begin_session(); fpga_spi_profile profile={};
            for (const auto *chunk : {&bytes, &tail}) {
                if (bulk) user_io_file_tx_data_ack(chunk->data(), chunk->size(), sample ? &profile : nullptr);
                else user_io_file_tx_data(chunk->data(), chunk->size());
            }
            for (int i=0; i<8; ++i) tick();
            assert(accepted == expected && resets == 0 && dut->ioctl_download);
            assert(!(gpo_copy & SSPI_STROBE) && !dut->io_ack);
            assert(dut->ioctl_addr == (expected.size()-1)*(TEST_WIDE ? 2 : 1));
            if (bulk && sample) assert(profile.words == expected.size());
            if (max_occupancy == 2) ++backpressured;
            EnableFpga(); spi8(0x53); fpga_spi(0); DisableFpga();
            for (int i=0; i<8; ++i) tick();
            assert(!dut->ioctl_download && accepted == expected);
        }
        ++cases;
    }
    assert(cases == 168 && backpressured > 0);
    dut.reset(); // Destroy the last model before Verilator's thread-local context.
    printf("PASS RTL wide=%d: %u cases, upstream and bulk; four bridge latencies, full sink, independent waits, consecutive chunks, odd tails, download release\n", TEST_WIDE, cases);
}
'''


def rtl_module() -> tuple[str, dict]:
    """Extract existing production clock/ACK and FIO blocks, not a rewritten model."""
    top = (ROOT / "sys/sys_top.v").read_text()
    hps = (ROOT / "sys/hps_io.sv").read_text()
    handshake = top[top.index("reg  io_ack;"):top.index("`ifdef MISTER_DUAL_SDRAM", top.index("reg  io_ack;"))]
    fio = hps[hps.index("localparam FIO_FILE_TX      ="):hps.index("\nendmodule", hps.index("localparam FIO_FILE_TX      ="))]
    # Move only the ACK declaration into the module port list.
    handshake = handshake.replace("reg  io_ack;\n", "", 1)
    header = '''module bridge #(parameter WIDE=1)(
input clk_sys, input [31:0] gp_out, input io_wait, input vs_wait,
output reg io_ack, output reg ioctl_wr, output reg ioctl_download,
output reg [(WIDE ? 15 : 7):0] ioctl_dout, output reg [26:0] ioctl_addr);
localparam DW = WIDE ? 15 : 7;
wire [15:0] io_din = gp_outr[15:0];
wire io_clk = gp_outr[17];
wire fp_enable = ~gp_outr[19] & gp_outr[18];
reg ioctl_upload, ioctl_rd;
reg [31:0] ioctl_file_ext;
reg [15:0] ioctl_index;
wire [DW:0] ioctl_din = 0;
'''
    hashes = {"sys_top_handshake_sha256": hashlib.sha256(handshake.encode()).hexdigest(),
              "hps_io_fio_block_sha256": hashlib.sha256(fio.encode()).hexdigest()}
    return header + handshake + fio + "\nendmodule\n", hashes


def run(main_source: Path, compiler: str, sanitize: bool, rtl: bool = False) -> dict:
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
        assert ordinary == function(fpga, "fpga_spi"), "Ordinary non-media ACK path changed"
        assert function(upstream("user_io.cpp"), "user_io_file_tx_data") == function(io, "user_io_file_tx_data")
        transport = TRANSPORT_PRELUDE + struct + "\n" + ordinary
        transport += "static uint16_t spi_w(uint16_t w) { return fpga_spi(w); }\n"
        transport += "static uint8_t spi_b(uint8_t w) { return uint8_t(fpga_spi(w)); }\n"
        transport += function(upstream("spi.cpp"), "spi_write")
        bulk = function(fpga, "fpga_spi_next_word")
        bulk += "template<bool Profile>\n" + function(fpga, "fpga_spi_write_ack_impl")
        bulk += function(fpga, "fpga_spi_write_ack")
        transport += bulk
        transport += function(io, "user_io_file_tx_data")
        transport += function(io, "user_io_file_tx_data_ack") + TRANSPORT_TESTS
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
        rtl_hashes = {}
        if rtl:
            module, rtl_hashes = rtl_module()
            (work / "bridge.sv").write_text(module)
            source = RTL_PRELUDE + struct + "\n" + ordinary
            source += "static uint16_t spi_w(uint16_t w) { return fpga_spi(w); }\n"
            source += "static uint8_t spi_b(uint8_t w) { return uint8_t(fpga_spi(w)); }\n"
            source += function(upstream("spi.cpp"), "spi_write") + bulk
            source += function(io, "user_io_file_tx_data") + function(io, "user_io_file_tx_data_ack") + RTL_TESTS
            (work / "bridge_test.cpp").write_text(source)
            for wide in (0, 1):
                obj = work / f"obj{wide}"
                command = ["verilator", "--cc", "--exe", "--build", "-j", "4", "-Wno-fatal",
                           "--top-module", "bridge", f"-GWIDE={wide}", "--Mdir", str(obj),
                           "-CFLAGS", f"-std=c++14 -O2 -DTEST_WIDE={wide}",
                           str(work / "bridge.sv"), str(work / "bridge_test.cpp")]
                built = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                if built.returncode:
                    raise RuntimeError(built.stdout)
                result = subprocess.run([str(obj / "Vbridge")], text=True, capture_output=True)
                if result.returncode:
                    raise RuntimeError(result.stdout + result.stderr)
                reports[f"rtl_wide_{wide}"] = result.stdout
                print(result.stdout, end="")
        return {"pinned_main_commit": PIN, "compiler": compiler, "sanitizers": sanitize,
                "rtl_blocks": rtl_hashes, "reports": reports}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--main-source", required=True, type=Path)
    ap.add_argument("--compiler", default="g++")
    ap.add_argument("--sanitize", action="store_true")
    ap.add_argument("--rtl", action="store_true", help="also test against extracted RTL with Verilator (not sanitizer-instrumented)")
    ap.add_argument("--report", type=Path)
    args = ap.parse_args()
    report = run(args.main_source.resolve(), args.compiler, args.sanitize, args.rtl)
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
