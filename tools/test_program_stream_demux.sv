`timescale 1ns/1ps

// Unit test for rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv. Builds a
// synthetic Program Stream (MPEG-2 pack header with stuffing, a video PES
// with a PTS, an audio PES with a PTS, a skipped private-stream packet, and
// MPEG_program_end_code) and checks the two elementary outputs, their PTS
// values, and that in_ready backpressures correctly when a consumer stalls.
module test_program_stream_demux;

reg clk=0, reset=1;
reg [7:0] in_data=0;
reg in_valid=0;
wire in_ready;

reg video_ready=1, audio_ready=1;
wire [7:0] video_data, audio_data;
wire video_valid, audio_valid;
wire [32:0] video_pts, audio_pts;
wire video_pts_valid, audio_pts_valid;
wire stream_end, demux_error;

always #5 clk = ~clk;

mpeg2_h262_program_stream_demux dut(
    .clk(clk), .reset(reset),
    .in_data(in_data), .in_valid(in_valid), .in_ready(in_ready),
    .video_data(video_data), .video_valid(video_valid), .video_ready(video_ready),
    .video_pts(video_pts), .video_pts_valid(video_pts_valid),
    .audio_data(audio_data), .audio_valid(audio_valid), .audio_ready(audio_ready),
    .audio_pts(audio_pts), .audio_pts_valid(audio_pts_valid),
    .stream_end(stream_end), .demux_error(demux_error)
);

task fail; input [8*160-1:0] message; begin $display("FAIL: %0s",message); $fatal(1); end endtask

// --- Build the synthetic stream as a byte queue -----------------------
reg [7:0] stream [0:4095];
integer len;

task push; input [7:0] b; begin stream[len]=b; len=len+1; end endtask

task push_pts_bytes; input [3:0] prefix; input [32:0] pts;
begin
    push({prefix, pts[32:30], 1'b1});
    push(pts[29:22]);
    push({pts[21:15], 1'b1});
    push(pts[14:7]);
    push({pts[6:0], 1'b1});
end
endtask

integer i;
integer video_len_pos, audio_len_pos;

initial begin
    len = 0;

    // MPEG-2 pack_header: 0x000001BA, then '01' marker byte, 8 more fixed
    // bytes, then a stuffing-length byte requesting 2 stuffing bytes.
    push(8'h00); push(8'h00); push(8'h01); push(8'hba);
    push(8'b0100_0100); // SCR marker form
    for (i=0;i<8;i=i+1) push(8'h00);
    push(8'h02); // stuffing_length = 2
    push(8'hff); push(8'hff);

    // Video PES: stream_id 0xE0, PTS-only optional header, payload "VID".
    push(8'h00); push(8'h00); push(8'h01); push(8'he0);
    video_len_pos = len; push(8'h00); push(8'h00); // length placeholder
    push(8'b10_00_0000); // '10' marker, no scrambling/priority/alignment
    push(8'b1000_0000);  // PTS_DTS_flags=10, rest of header-flags byte 0
    push(8'd5);          // header_data_length = 5 (just the PTS)
    push_pts_bytes(4'b0010, 33'd90000);
    push("V"); push("I"); push("D");
    stream[video_len_pos]   = ((len - video_len_pos - 2) >> 8) & 8'hff;
    stream[video_len_pos+1] = (len - video_len_pos - 2) & 8'hff;

    // Private stream (0xBD): should be fully skipped.
    push(8'h00); push(8'h00); push(8'h01); push(8'hbd);
    push(8'h00); push(8'h04);
    push(8'hde); push(8'had); push(8'hbe); push(8'hef);

    // Audio PES: stream_id 0xC0, PTS-only optional header, payload "AUD1".
    push(8'h00); push(8'h00); push(8'h01); push(8'hc0);
    audio_len_pos = len; push(8'h00); push(8'h00);
    push(8'b10_00_0000);
    push(8'b1000_0000); // PTS_DTS_flags=10
    push(8'd5);
    push_pts_bytes(4'b0010, 33'd45000);
    push("A"); push("U"); push("D"); push(8'h31);
    stream[audio_len_pos]   = ((len - audio_len_pos - 2) >> 8) & 8'hff;
    stream[audio_len_pos+1] = (len - audio_len_pos - 2) & 8'hff;

    // MPEG_program_end_code.
    push(8'h00); push(8'h00); push(8'h01); push(8'hb9);

    $display("built %0d-byte synthetic Program Stream", len);
end

// --- Drive the input, honoring in_ready --------------------------------
integer pos;
task drive_all; input integer stall_after; input integer stall_cycles;
integer stalled;
begin
    pos = 0; stalled = 0;
    reset = 1;
    repeat(4) @(posedge clk);
    reset = 0;
    while (pos < len) begin
        @(negedge clk);
        if (stall_after >= 0 && pos == stall_after && !stalled) begin
            in_valid = 0;
            repeat(stall_cycles) @(negedge clk);
            stalled = 1;
        end
        in_data  = stream[pos];
        in_valid = 1;
        @(posedge clk);
        while (!in_ready) @(posedge clk);
        pos = pos + 1;
    end
    @(negedge clk); in_valid = 0;
end
endtask

// --- Collect elementary output bytes ------------------------------------
reg [7:0] got_video [0:63]; integer got_video_len;
reg [7:0] got_audio [0:63]; integer got_audio_len;
reg got_video_pts_seen, got_audio_pts_seen;
reg [32:0] got_video_pts, got_audio_pts;
integer got_stream_end;

always @(posedge clk) begin
    if (video_valid) begin got_video[got_video_len] = video_data; got_video_len = got_video_len + 1; end
    if (audio_valid) begin got_audio[got_audio_len] = audio_data; got_audio_len = got_audio_len + 1; end
    if (video_pts_valid) begin got_video_pts = video_pts; got_video_pts_seen = 1; end
    if (audio_pts_valid) begin got_audio_pts = audio_pts; got_audio_pts_seen = 1; end
    if (stream_end) got_stream_end = got_stream_end + 1;
end

task check_results;
begin
    if (got_video_len !== 3 || got_video[0] !== "V" || got_video[1] !== "I" || got_video[2] !== "D")
        fail("video elementary bytes did not decode to VID");
    if (got_audio_len !== 4 || got_audio[0] !== "A" || got_audio[1] !== "U" || got_audio[2] !== "D" || got_audio[3] !== 8'h31)
        fail("audio elementary bytes did not decode to AUD1");
    if (!got_video_pts_seen || got_video_pts !== 33'd90000)
        fail("video PTS did not decode to 90000");
    if (!got_audio_pts_seen || got_audio_pts !== 33'd45000)
        fail("audio PTS did not decode to 45000");
    if (got_stream_end !== 1)
        fail("stream_end did not pulse exactly once at MPEG_program_end_code");
    if (demux_error)
        fail("demux_error asserted on a well-formed stream");
end
endtask

initial begin
    #1; // let the stream-building initial block run first
    wait(len > 0);

    // Pass 1: no backpressure.
    got_video_len=0; got_audio_len=0; got_video_pts_seen=0; got_audio_pts_seen=0; got_stream_end=0;
    drive_all(-1, 0);
    repeat(4) @(posedge clk);
    check_results;
    $display("PASS (no backpressure)");

    // Pass 2: stall the audio consumer mid-packet to prove in_ready gates
    // the whole input stream on downstream backpressure, not just on the
    // stalled stream's own bytes.
    got_video_len=0; got_audio_len=0; got_video_pts_seen=0; got_audio_pts_seen=0; got_stream_end=0;
    audio_ready = 1;
    fork
        begin
            @(posedge audio_valid);
            audio_ready = 0;
            repeat(20) @(posedge clk);
            audio_ready = 1;
        end
        drive_all(-1, 0);
    join
    repeat(4) @(posedge clk);
    check_results;
    $display("PASS (with mid-stream audio backpressure)");

    // Pass 3: the legacy MPEG-1 PES optional-header form (leading 0xFF
    // stuffing, a bare PTS/PTS+DTS marker, no header_data_length field at
    // all) - built from the exact byte sequence pulled from the project's
    // own primary test file ("01 - Pee Strike.mpg"), which entry 983's
    // hardware test found this demux could not parse at all.
    build_legacy_stream;
    got_video_len=0; got_audio_len=0; got_video_pts_seen=0; got_audio_pts_seen=0; got_stream_end=0;
    drive_all(-1, 0);
    repeat(4) @(posedge clk);
    if (got_video_len !== 6 || got_video[0] !== "S" || got_video[1] !== "E" ||
        got_video[2] !== "Q" || got_video[3] !== "H" || got_video[4] !== "D" || got_video[5] !== "R")
        fail("legacy-form video payload did not decode to SEQHDR");
    if (!got_video_pts_seen || got_video_pts !== 33'd48003)
        fail("legacy-form PTS did not decode to 48003 (the real file's actual first video PTS)");
    if (demux_error)
        fail("demux_error asserted on the real-file-derived legacy-form stream");
    $display("PASS (legacy MPEG-1 PES optional-header form, real-file byte pattern)");

    // Pass 4: legacy form with two leading 0xFF stuffing bytes and a
    // PTS-only marker (no DTS) - exercises S_PES_LEGACY_STUFF, which Pass 3
    // never touches since the real file's own marker has no stuffing
    // ahead of it.
    build_legacy_stuffed_stream;
    got_video_len=0; got_audio_len=0; got_video_pts_seen=0; got_audio_pts_seen=0; got_stream_end=0;
    drive_all(-1, 0);
    repeat(4) @(posedge clk);
    if (got_video_len !== 4 || got_video[0] !== "V" || got_video[1] !== "I" ||
        got_video[2] !== "D" || got_video[3] !== "1")
        fail("legacy-form-with-stuffing video payload did not decode to VID1");
    if (!got_video_pts_seen || got_video_pts !== 33'd12345)
        fail("legacy-form-with-stuffing PTS did not decode to 12345");
    if (demux_error)
        fail("demux_error asserted on the stuffed legacy-form stream");
    $display("PASS (legacy form with leading stuffing bytes, PTS-only)");

    // Pass 5: legacy form with the 2-byte STD_buffer_scale/size field
    // present ahead of the timestamp marker - exercises S_PES_LEGACY_STD2.
    build_legacy_std_stream;
    got_video_len=0; got_audio_len=0; got_video_pts_seen=0; got_audio_pts_seen=0; got_stream_end=0;
    drive_all(-1, 0);
    repeat(4) @(posedge clk);
    if (got_video_len !== 4 || got_video[0] !== "V" || got_video[1] !== "I" ||
        got_video[2] !== "D" || got_video[3] !== "2")
        fail("legacy-form-with-STD video payload did not decode to VID2");
    if (!got_video_pts_seen || got_video_pts !== 33'd67890)
        fail("legacy-form-with-STD PTS did not decode to 67890");
    if (demux_error)
        fail("demux_error asserted on the STD-field legacy-form stream");
    $display("PASS (legacy form with STD_buffer_scale/size field, PTS-only)");

    $display("PASS: program stream demux decodes video/audio elementary bytes and PTS correctly");
    $finish;
end

task build_legacy_stuffed_stream;
begin
    len = 0;
    push(8'h00); push(8'h00); push(8'h01); push(8'he0);
    video_len_pos = len; push(8'h00); push(8'h00);
    push(8'hff); push(8'hff); // two stuffing bytes ahead of the marker
    push_pts_bytes(4'b0010, 33'd12345); // PTS-only marker, no DTS
    push("V"); push("I"); push("D"); push("1");
    stream[video_len_pos]   = ((len - video_len_pos - 2) >> 8) & 8'hff;
    stream[video_len_pos+1] = (len - video_len_pos - 2) & 8'hff;
    push(8'h00); push(8'h00); push(8'h01); push(8'hb9);
    $display("built %0d-byte stuffed legacy-form synthetic Program Stream", len);
end
endtask

task build_legacy_std_stream;
begin
    len = 0;
    push(8'h00); push(8'h00); push(8'h01); push(8'he0);
    video_len_pos = len; push(8'h00); push(8'h00);
    push(8'h4a); push(8'h5b); // 2-byte STD_buffer_scale/size field (0x4X marker)
    push_pts_bytes(4'b0010, 33'd67890); // PTS-only marker, no DTS
    push("V"); push("I"); push("D"); push("2");
    stream[video_len_pos]   = ((len - video_len_pos - 2) >> 8) & 8'hff;
    stream[video_len_pos+1] = (len - video_len_pos - 2) & 8'hff;
    push(8'h00); push(8'h00); push(8'h01); push(8'hb9);
    $display("built %0d-byte STD-field legacy-form synthetic Program Stream", len);
end
endtask

// Builds a short Program Stream using the exact pack-header/PES-header
// byte pattern captured from "01 - Pee Strike.mpg" offsets 0x00-0x2D
// (pack header, system header, and a video PES's legacy PTS+DTS marker),
// but with a short synthetic 6-byte payload ("SEQHDR") in place of the
// real ~2000-byte picture data, so the test stays small.
task build_legacy_stream;
begin
    len = 0;

    // Pack header (MPEG-2 form, as the real file uses): identical in kind
    // to Pass 1's, bytes taken directly from the captured file.
    push(8'h00); push(8'h00); push(8'h01); push(8'hba);
    push(8'h21); push(8'h00); push(8'h01); push(8'h00);
    push(8'h01); push(8'h80); push(8'haa); push(8'hd3);

    // System header: real captured bytes verbatim.
    push(8'h00); push(8'h00); push(8'h01); push(8'hbb);
    push(8'h00); push(8'h0c);
    push(8'h80); push(8'haa); push(8'hd3); push(8'h04); push(8'h21); push(8'hff);
    push(8'he0); push(8'he0); push(8'he6); push(8'hc0); push(8'hc0); push(8'h20);

    // Video PES: real stream_id/legacy PTS+DTS bytes verbatim, but a short
    // synthetic payload and a length field recomputed to match.
    push(8'h00); push(8'h00); push(8'h01); push(8'he0);
    video_len_pos = len; push(8'h00); push(8'h00);
    push_pts_bytes(4'b0011, 33'd48003); // PTS+DTS marker, matches the real byte 0x31
    push_pts_bytes(4'b0001, 33'd45000); // DTS marker, matches the real byte 0x11
    push("S"); push("E"); push("Q"); push("H"); push("D"); push("R");
    stream[video_len_pos]   = ((len - video_len_pos - 2) >> 8) & 8'hff;
    stream[video_len_pos+1] = (len - video_len_pos - 2) & 8'hff;

    push(8'h00); push(8'h00); push(8'h01); push(8'hb9);

    $display("built %0d-byte legacy-form synthetic Program Stream", len);
end
endtask

initial begin
    #5000000; // 5ms simulated-time watchdog
    fail("simulation timed out - demux FSM likely stuck");
end

endmodule
