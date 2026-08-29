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
#include <cctype>
#include <cstring>
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
    char extensions[] = "M2VMPGMP3WAVFLC";
    char flac[] = "track.flac", upper_flac[] = "TRACK.FLAC";
    char flc[] = "track.flc", flv[] = "track.flv";
    assert(user_io_ext_idx(flac, extensions) == 4);
    assert(user_io_ext_idx(upper_flac, extensions) == 4);
    assert(user_io_ext_idx(flc, extensions) != 4);
    assert(user_io_ext_idx(flv, extensions) != 4);
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
#include <algorithm>
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
static bool fail_open = false, fail_burst = false;
static unsigned mock_tx_calls = 0, releases = 0, closes = 0;
static unsigned source_offset = 0, step_quota = 2048, step_us = 11, step_calls = 0, odd_steps = 0;
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
    for (int i = 0; i < n; ++i) static_cast<uint8_t *>(buf)[i] = uint8_t((source_offset + i) * 29 + 7);
    source_offset += n;
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
static unsigned user_io_status_get(const char *) { return 0; }
static void user_io_set_index(unsigned char) {}
static void user_io_file_info(const char *) {}
int mediaplayer_start_source(const char *, unsigned char);
static int user_io_file_tx_data_step(const uint8_t *data, uint32_t size,
    media_burst_state *state, media_burst_stats *stats, uint32_t *consumed, fpga_spi_profile *) {
    ++step_calls; state->mode = 2; *consumed = 0; stats->queries = 1;
    fake_us += step_us;
    if (fail_burst) { stats->error = 3; return 0; }
    unsigned n = std::min(size, std::min(2048u, step_quota));
    if (!n) return 1;
    assert(n <= 2048); odd_steps += n & 1;
    delivered.insert(delivered.end(), data, data + n); ++mock_tx_calls;
    stats->fast_bytes = n; stats->batches = 1; stats->queries = 2; *consumed = n;
    return 1;
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
    source_offset = 0; step_quota = 2048; step_us = 11; step_calls = odd_steps = 0;
    releases = closes = 0; correct_core = true; fail_open = fail_burst = false;
    diagnostic_open("file:test.m2v", 1); helper_fd = 42; helper_pid = -1;
    download_active = 1; download_assert_us = fake_us;
}
static void pump() {
    unsigned polls=0;
    while (helper_fd >= 0) {
        assert(++polls < 100000); auto before=step_calls;
        fake_us += 17; mediaplayer_poll(); assert(step_calls-before <= 8);
    }
}
static void exact_bytes(size_t expected) {
    assert(delivered.size() == expected && submitted_bytes == expected);
    for (size_t i=0; i<expected; ++i) assert(delivered[i] == uint8_t(i*29+7));
}
int main() {
    assert(mediaplayer_handles_file("track.mp3"));
    assert(mediaplayer_handles_file("TRACK.MP3"));
    assert(mediaplayer_handles_file("track.wav"));
    assert(mediaplayer_handles_file("TRACK.WAV"));
    assert(mediaplayer_handles_file("track.flac"));
    assert(mediaplayer_handles_file("TRACK.FLAC"));
    assert(mediaplayer_handles_file("movie.m2v"));
    assert(mediaplayer_handles_file("movie.mpg"));
    assert(mediaplayer_handles_file("movie.mpeg"));
    assert(!mediaplayer_handles_file("track.flc"));
    assert(!mediaplayer_handles_file("track.flv"));
    assert(!mediaplayer_handles_file("track.mp3.txt"));
    session(); pipe_reads={-EAGAIN}; mediaplayer_poll();
    assert(helper_fd==42 && releases==0 && !step_calls && would_block_events==1);
    for (int i=0; i<65; ++i) pipe_reads.push_back(16384);
    pipe_reads.push_back(3); pipe_reads.push_back(0);
    mediaplayer_poll(); assert(mock_tx_calls==8 && pipe_reads.size()==66);
    pump(); exact_bytes(65*16384+3);
    assert(read_events==66 && odd_steps==1 && releases==1 && !pending_size);
    assert(transfer_profile.fast_bytes==delivered.size() && transfer_profile.slow_bytes==0);
    assert(log_text.find("profile_version=2 transport=credit_step_v1")!=std::string::npos);
    assert(occurrences("first_byte latency_us=")==1 && occurrences("profile_summary ")==1);
    assert(log_text.find("finish reason=eof")!=std::string::npos);
    auto saved=step_calls; mediaplayer_poll(); assert(step_calls==saved);
    puts("PASS loader: complete 66-read stream, bounded steps, exact bytes, terminal padding, EOF and idle");

    session(); step_quota=0; pipe_reads={16384,2,0};
    for (int i=0;i<100;++i) mediaplayer_poll();
    assert(pipe_reads.size()==2 && delivered.empty() && pending_size==16384 && !pending_offset);
    assert(step_calls==100 && !releases);
    step_quota=64; mediaplayer_poll(); assert(delivered.size()==512 && pipe_reads.size()==2);
    step_quota=2048; pump(); exact_bytes(16386);
    puts("PASS loader: 100 zero-credit yields, limited-credit resume, no extra reads or byte loss");

    session(); pipe_reads={1,-EAGAIN,3,5,-EINTR,2,0}; pump(); exact_bytes(11);
    assert(odd_steps==1 && read_events==4 && would_block_events==2);
    session(); pipe_reads={1,0}; step_quota=0;
    mediaplayer_poll(); assert(!step_calls && pipe_reads.size()==1);
    mediaplayer_poll(); assert(pending_eof && !releases && pipe_reads.empty());
    for(int i=0;i<10;++i) mediaplayer_poll();
    assert(!releases && delivered.empty());
    step_quota=2048; pump(); exact_bytes(1); assert(odd_steps==1 && releases==1);
    puts("PASS loader: odd short reads across EAGAIN/EINTR, EOF retained while credit blocked, one final pad");

    session(); pipe_reads={16384,0}; step_us=600;
    auto before=fake_us; mediaplayer_poll();
    assert(mock_tx_calls==4 && pending_offset==8192 && fake_us-before<2700);
    pump(); exact_bytes(16384);
    puts("PASS loader: 2ms work budget checked between bounded steps independently of diagnostic logging");

    session(); pipe_reads={16384,16384,0}; step_quota=64; mediaplayer_poll();
    saved=delivered.size(); fail_burst=true; mediaplayer_poll();
    assert(helper_fd==-1 && releases==1 && pipe_reads.size()==2 && delivered.size()==saved);
    assert(!pending_size && !pending_offset && log_text.find("stop reason=transport-fault")!=std::string::npos);
    mediaplayer_poll(); assert(delivered.size()==saved);
    session(); pipe_reads={16384,0}; step_quota=0; mediaplayer_poll();
    correct_core=false; mediaplayer_poll(); assert(releases==1 && !pending_size && delivered.empty());
    session(); pipe_reads={16384,0}; step_quota=0; mediaplayer_poll();
    mediaplayer_stop(); assert(releases==1 && !pending_size && !pending_offset);
    session(); pipe_reads={7,0}; pump(); exact_bytes(7);
    assert(odd_steps==1 && occurrences("profile_summary ")==1);
    session(); pipe_reads={-EIO}; mediaplayer_poll();
    assert(releases==1 && log_text.find("read failed errno=5 ")!=std::string::npos);
    puts("PASS loader: faults never retry, cancel/core change clear pending bytes, clean warm restart and read errors");

    for(unsigned trial=1;trial<=24;++trial) {
        session(); unsigned seed=trial, total=0, polls=0;
        for(unsigned i=0;i<50;++i) {
            seed=seed*1664525u+1013904223u;
            unsigned n=1+(seed%127); total+=n; pipe_reads.push_back(n);
            if(i%7==0) pipe_reads.push_back(-EAGAIN);
        }
        pipe_reads.push_back(0);
        while(helper_fd>=0) {
            assert(++polls<10000); seed=seed*1664525u+1013904223u;
            step_quota=(seed%5==0)?0:2*(1+seed%64);
            auto before=step_calls; mediaplayer_poll(); assert(step_calls-before<=8);
        }
        exact_bytes(total); assert(odd_steps==(total&1u) && releases==1);
    }
    puts("PASS loader: 24 seeded short-read/credit-stall sequences preserve every byte and final padding");

    session(); diagnostic_close(); log_text.clear(); fail_open=true;
    diagnostic_open("file:test.m2v",1); helper_fd=42; download_active=1;
    step_quota=0; pipe_reads={16384,0}; mediaplayer_poll();
    assert(log_text.empty() && pending_size==16384 && !delivered.size());
    step_quota=2048; step_us=600; before=fake_us; mediaplayer_poll();
    assert(delivered.size()==8192 && fake_us-before==2400);
    pump(); exact_bytes(16384); assert(log_text.empty());
    puts("PASS loader: missing diagnostic endpoint preserves zero-credit yield, time budget and data");
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
static bool guarded, force_zero, reset_status, change_status;
static unsigned capacity = 16384, drain_period = 97, fault_kind, fast_rises;
static uint32_t sink_words;
static uint16_t sink_digest;
static unsigned status_fault;
static bool case_bulk;
#undef assert
#define assert(c) do { if (!(c)) { fprintf(stderr, "RTL check failed: %s line=%d size=%u bulk=%d latency=%u stalls=%u cycle=%llu accepted=%zu occupancy=%u\n", #c, __LINE__, case_size, case_bulk, latency, stall_mode, (unsigned long long)cycles, accepted.size(), occupancy); abort(); } } while (0)
static void tick() {
    ++cycles;
    // Two-word test sink: hold full until a deliberately slow consumer drains.
    // Also vary wait independently, including the shared vs_wait gate.
    dut->ioctl_burst_credit = force_zero || occupancy + 32 >= capacity ? 0 : std::min(4096u, capacity - occupancy - 32);
    dut->ioctl_burst_words = reset_status ? 0 : sink_words;
    dut->ioctl_burst_digest = reset_status ? 0 : sink_digest;
    dut->ioctl_burst_ready = dut->ioctl_download && status_fault != 1;
    dut->ioctl_burst_fault = status_fault == 2;
    if (status_fault == 3) dut->ioctl_burst_credit = 4097;
    if (status_fault == 4) dut->ioctl_burst_words ^= 1;
    if (status_fault == 5) dut->ioctl_burst_digest ^= 1;
    dut->io_wait = guarded ? occupancy >= capacity : stall_mode && (occupancy >= 2 || (stall_mode == 2 && cycles % 113 < 37));
    dut->vs_wait = !guarded && stall_mode == 2 && cycles % 211 < 29;
    dut->clk_sys = 0; dut->eval();
    const bool wr = dut->ioctl_wr;
    const uint16_t data = dut->ioctl_dout;
    dut->clk_sys = 1; dut->eval();
    if (wr) {
        accepted.push_back(data);
        ++sink_words; sink_digest = uint16_t((sink_digest << 1) | (sink_digest >> 15)) ^ data;
        if (stall_mode || guarded) { ++occupancy; max_occupancy = std::max(max_occupancy, occupancy); assert(occupancy <= (guarded ? capacity : 2)); }
    }
    if (occupancy && cycles % drain_period == 0) --occupancy;
}
static void fpga_gpo_write(uint32_t v) {
    gpo_copy = v; dut->gp_out = v;
    for (unsigned i=0; i<latency; ++i) tick();
}
static void fpga_gpo_writeN(uint32_t v) {
    if (v & SSPI_STROBE) {
        ++fast_rises;
        if (fast_rises == 3) {
            if (fault_kind == 1) v &= ~SSPI_STROBE; // Drop one rising strobe.
            if (fault_kind == 2) v ^= 1; // Alter one received payload bit.
            if (fault_kind == 3) reset_status = true;
            if (fault_kind == 4) status_fault = 2;
        }
    }
    // Production writeN does not update Main's cached GPO value.
    const auto cached = gpo_copy; fpga_gpo_write(v); gpo_copy = cached;
}
static uint32_t fpga_gpo_read() { return gpo_copy; }
static int fpga_gpi_read() {
    assert(++reads < 10000000);
    for (unsigned i=0; i<latency; ++i) tick();
    const unsigned data = dut->fp_dout ^ (change_status && dut->fp_dout == 0x4D50 ? 1 : 0);
    return (dut->io_ack ? SSPI_ACK : 0) | data;
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
    sink_words = 0; sink_digest = 0; fast_rises = 0; reset_status = false; status_fault = 0;
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
    unsigned burst_cases = 0;
    guarded = true; stall_mode = 0;
    for (unsigned delay : {1u, 2u, 5u, 13u}) for (unsigned cap : {64u, 16384u})
    for (unsigned size : {0u, 1u, 2u, 3u, 8193u, 32769u}) for (unsigned offset : {0u, 1u}) {
        latency = delay; capacity = cap; case_size = size;
        begin_session(); media_burst_state state = {}; media_burst_stats stats = {};
        std::vector<uint8_t> storage(size + 2), bytes(size);
        for (unsigned i=0; i<size; ++i) storage[i+offset] = bytes[i] = uint8_t(i*37+19);
        assert(user_io_file_tx_data_burst(storage.data()+offset, size, &state, &stats, nullptr));
        for (int i=0; i<8; ++i) tick();
        assert(accepted == packed(bytes) && !stats.error);
        assert(stats.fast_bytes + stats.slow_bytes == size);
        assert(state.mode == (size ? (TEST_WIDE && TEST_BURST ? 2u : 1u) : 0u));
        if (!TEST_WIDE || !TEST_BURST || offset) assert(!stats.fast_bytes);
        else if (size >= 2) assert(stats.fast_bytes && stats.queries > stats.batches);
        ++burst_cases;
    }
    if (TEST_WIDE && TEST_BURST) {
        latency = 1; capacity = 64; begin_session();
        // A full sink plus zero credit must use acknowledged progress and drain.
        occupancy = capacity; force_zero = true;
        std::vector<uint8_t> bytes(16, 0x39); media_burst_state state = {}; media_burst_stats stats = {};
        assert(user_io_file_tx_data_burst(bytes.data(), bytes.size(), &state, &stats, nullptr));
        assert(!stats.fast_bytes && stats.slow_bytes == bytes.size() && accepted == packed(bytes));
        force_zero = false;
        // Count wrap and coherent snapshot even if live inputs change mid-query.
        begin_session(); sink_words = 0xfffffffcu; sink_digest = 0x1234;
        state = {}; stats = {};
        assert(user_io_file_tx_data_burst(bytes.data(), bytes.size(), &state, &stats, nullptr));
        assert(state.words == 4 && state.digest == sink_digest);
        EnableFpga(); const auto before_words = sink_words; const auto before_digest = sink_digest;
        assert(spi_w(0x57) == 0x4D50); sink_words += 999; sink_digest ^= 0x8888;
        assert(spi_w(0) == 0xB001); const auto credit = spi_w(0); assert(credit <= 4096);
        uint32_t snapshot = spi_w(0); snapshot |= uint32_t(spi_w(0)) << 16;
        assert(snapshot == before_words && spi_w(0) == before_digest && spi_w(0) == 1);
        DisableFpga();
        // Each uncertain first batch is rejected without sending a second batch.
        for (unsigned fault : {1u, 2u, 3u, 4u}) {
            capacity = 16384; begin_session(); fault_kind = fault; state = {}; stats = {};
            bytes.resize(16384);
            assert(!user_io_file_tx_data_burst(bytes.data(), bytes.size(), &state, &stats, nullptr));
            assert(stats.error && stats.batches == 1 && stats.fast_bytes == 8192 && fast_rises == 4096);
            assert(accepted.size() == (fault == 1 ? 4095u : 4096u));
            fault_kind = 0;
        }
        for (unsigned fault : {1u, 2u, 3u, 4u, 5u, 6u}) {
            begin_session(); state = {}; stats = {};
            assert(user_io_file_tx_data_burst(bytes.data(), 16, &state, &stats, nullptr));
            const auto count = accepted.size(); status_fault = fault; change_status = fault == 6; stats = {};
            assert(!user_io_file_tx_data_burst(bytes.data(), 16, &state, &stats, nullptr));
            assert(stats.error && accepted.size() == count && !stats.fast_bytes && !stats.slow_bytes);
            change_status = false;
        }
        puts("PASS guarded fault cases: zero/full credits, counter wrap, coherent snapshot, lost/corrupt word, reset, overflow, invalid credit/count/digest/capability, no second batch");
    }
    printf("PASS burst RTL wide=%d capability=%d: %u cases; credit bounds, alignment, odd tails, legacy discovery, minimum one-cycle posted writes\n", TEST_WIDE, TEST_BURST, burst_cases);
    if (!TEST_WIDE || !TEST_BURST) {
        latency=1; capacity=64; begin_session(); media_burst_state state={};
        media_burst_stats stats={}; uint32_t n=0; std::vector<uint8_t> bytes(17,0x71);
        assert(user_io_file_tx_data_step(bytes.data(),bytes.size(),&state,&stats,&n,nullptr));
        for(unsigned i=0;i<8;++i)tick();
        assert(n==17 && stats.slow_bytes==17 && !stats.fast_bytes && accepted==packed(bytes));
        puts("PASS step legacy: existing acknowledged semantics retained");
    }
    if (TEST_WIDE && TEST_BURST) {
        unsigned step_cases=0;
        for (unsigned cap : {64u,16384u}) for (unsigned offset : {0u,1u})
        for (unsigned size : {1u,2u,3u,2049u,16385u}) {
            capacity=cap; latency=1; begin_session();
            std::vector<uint8_t> storage(size+1),bytes(size);
            for(unsigned i=0;i<size;++i) storage[i+offset]=bytes[i]=uint8_t(i*17+5);
            media_burst_state state={}; uint32_t at=0; unsigned calls=0;
            while(at<size) {
                assert(++calls<100000); media_burst_stats stats={}; uint32_t n=999;
                assert(user_io_file_tx_data_step(storage.data()+offset+at,size-at,&state,&stats,&n,nullptr));
                assert(n<=2048 && stats.batches<=1 && stats.queries<=2 && !stats.slow_bytes);
                assert((n==0)==(stats.batches==0)); at+=n;
                for(unsigned i=0;i<200;++i)tick();
            }
            assert(accepted==packed(bytes) && state.words==accepted.size()); ++step_cases;
        }
        capacity=64; begin_session(); force_zero=true;
        media_burst_state state={}; std::vector<uint8_t> bytes(4096,0x39);
        for(unsigned i=0;i<100;++i) {
            media_burst_stats stats={}; uint32_t n=99;
            assert(user_io_file_tx_data_step(bytes.data(),bytes.size(),&state,&stats,&n,nullptr));
            assert(!n && !stats.batches && stats.queries==1 && accepted.empty());
        }
        force_zero=false;
        // State must still be checked after a yield, before any payload is sent.
        status_fault=4; media_burst_stats stats={}; uint32_t n=99;
        assert(!user_io_file_tx_data_step(bytes.data(),bytes.size(),&state,&stats,&n,nullptr));
        assert(!n && accepted.empty());
        for(unsigned fault : {1u,2u,3u,4u}) {
            capacity=16384; begin_session(); state={}; stats={}; fault_kind=fault;
            assert(!user_io_file_tx_data_step(bytes.data(),bytes.size(),&state,&stats,&n,nullptr));
            assert(!n && stats.error && stats.batches==1 && stats.fast_bytes==2048);
            assert(fast_rises==1024); fault_kind=0;
        }
        begin_session(); sink_words=0xfffffffcu; sink_digest=0x1234; state={}; stats={};
        assert(user_io_file_tx_data_step(bytes.data(),16,&state,&stats,&n,nullptr));
        assert(n==16 && state.words==4 && state.digest==sink_digest);
        printf("PASS step RTL: %u resume cases, unaligned/odd tails, 100 zero-credit yields, post-yield integrity, uncertain batch rejection, counter wrap\n",step_cases);
    }
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
    header = '''module bridge #(parameter WIDE=1, parameter MEDIA_BURST=1)(
input clk_sys, input [31:0] gp_out, input io_wait, input vs_wait,
input [14:0] ioctl_burst_credit, input [31:0] ioctl_burst_words,
input [15:0] ioctl_burst_digest, input ioctl_burst_ready, input ioctl_burst_fault,
output reg [15:0] fp_dout,
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
    return header + handshake + fio.replace("reg [15:0] fp_dout;", "") + "\nendmodule\n", hashes


def run(main_source: Path, compiler: str, sanitize: bool, rtl: bool = False) -> dict:
    def upstream(name: str) -> str:
        return subprocess.check_output(["git", "-C", str(main_source), "show", f"{PIN}:{name}"], text=True)

    with tempfile.TemporaryDirectory(prefix="main-profile-test-") as temporary:
        work = Path(temporary)
        for name in ("file_io.cpp", "menu.cpp", "user_io.cpp", "user_io.h", "fpga_io.cpp", "fpga_io.h"):
            (work / name).write_text(upstream(name))
        patch = ROOT / "host/main_mister/0001-mediaplayer-arm-loader.patch"
        subprocess.run(["git", "apply", "--check", str(patch)], cwd=work, check=True)
        subprocess.run(["git", "apply", str(patch)], cwd=work, check=True)
        fpga = (work / "fpga_io.cpp").read_text()
        io = (work / "user_io.cpp").read_text()
        struct = re.search(r"struct fpga_spi_profile\n\{.*?\n\};", (work / "fpga_io.h").read_text(), re.S)[0]
        burst_structs = "\n".join(re.search(r"struct " + n + r"\n\{.*?\n\};", (work / "user_io.h").read_text(), re.S)[0]
                                  for n in ("media_burst_state", "media_burst_stats"))
        (work / "fpga_io.h").write_text("#pragma once\n#include <stdint.h>\n" + struct + "\n" + burst_structs + "\n")
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
        transport += function(io, "user_io_file_tx_data_ack")
        transport += function(io, "user_io_ext_idx") + TRANSPORT_TESTS
        loader = (work / "support/mediaplayer/mediaplayer.cpp").read_text()
        menu = (work / "menu.cpp").read_text()
        if 'strcpy(ext, "M2VMPGMP3WAVFLC")' not in menu:
            raise RuntimeError("MediaPlayer file picker does not expose MP3, WAV and FLAC")
        file_io = (work / "file_io.cpp").read_text()
        if '!strcasecmp(e, "FLC")' not in file_io or '!strcasecmp(fext, "flac")' not in file_io:
            raise RuntimeError("MediaPlayer FLC alias is not mapped exactly to .flac")
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
            result = subprocess.run([str(executable)], check=True, text=True, capture_output=True, timeout=180)
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
            source += function(io, "user_io_file_tx_data") + function(io, "user_io_file_tx_data_ack")
            source += burst_structs + "\n" + re.search(r"struct media_burst_status\n\{.*?\n\};", io, re.S)[0] + "\n"
            source += function(fpga, "fpga_spi_fast_block_write")
            for name in ("media_burst_query", "media_burst_account", "user_io_file_tx_data_burst", "user_io_file_tx_data_step"):
                source += function(io, name)
            source += RTL_TESTS
            (work / "bridge_test.cpp").write_text(source)
            for wide, capability in ((0, 1), (1, 0), (1, 1)):
                obj = work / f"obj{wide}_{capability}"
                command = ["verilator", "--cc", "--exe", "--build", "-j", "4", "-Wno-fatal",
                           "--top-module", "bridge", f"-GWIDE={wide}", f"-GMEDIA_BURST={capability}", "--Mdir", str(obj),
                           "-CFLAGS", f"-std=c++14 -O2 -DTEST_WIDE={wide} -DTEST_BURST={capability}",
                           str(work / "bridge.sv"), str(work / "bridge_test.cpp")]
                built = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                if built.returncode:
                    raise RuntimeError(built.stdout)
                result = subprocess.run([str(obj / "Vbridge")], text=True, capture_output=True, timeout=300)
                if result.returncode:
                    raise RuntimeError(result.stdout + result.stderr)
                reports[f"rtl_wide_{wide}_capability_{capability}"] = result.stdout
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
