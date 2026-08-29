//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE,
        SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS,
        SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_SL = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

// AUDIO_FORK_POINT[PCM_OUT]: advisory v0.5.0 handoff, not a permanent ABI.
// Replace these zeroes only at the top-level PCM/output boundary.  Keep codec
// decode behind a codec-independent PCM valid/ready contract so MP2/MP3/AC-3
// (and standalone-audio codecs) remain separate from MiSTer output formatting.
// Prefer serialized/time-multiplexed arithmetic: the integrated core values DSP
// headroom more than parallel per-codec datapaths.  AUDIO_S/MIX policy belongs
// here or in a sibling output adapter, not inside the H.262 video decoder.
// Entry 395: route the codec-independent PCM proof path into MiSTer's signed
// 16-bit audio ports. Mono duplication and sample-rate scheduling remain in
// the output adapter; future codecs will see only the valid/ready contract.
wire [15:0] audio_pcm_output_l;
wire [15:0] audio_pcm_output_r;
assign AUDIO_S = 1'b1;
assign AUDIO_L = audio_pcm_output_l;
assign AUDIO_R = audio_pcm_output_r;
assign AUDIO_MIX = 2'd0;

// Entry 617: S/PDIF AC-3 passthrough. The helper packs IEC 61937 bursts and
// sends them down the ordinary PCM path, so the only thing this bit changes in
// fabric is routing: the bursts must reach the S/PDIF pin unaltered and HDMI
// must be muted rather than fed noise. Main reads the same status bit to pass
// --audio-out to the helper, because the decoder runs there and only it can
// choose whether to decode or pass through.
assign AUDIO_SPDIF_MODE = status[126];

// kate - Commit 180 displaces the LED_DISK file-load indicator again so it can
// blink the progress_error conjunct sub-code, exactly as Commit 176 did and
// Commit 177 reverted.  The assignment now lives with the rest of the blink
// machinery in MediaPlayer_top_07.svh; restore this line when the diagnostic
// is retired.
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
	"MediaPlayer;;",
	"F1,M2V,Open MPEG-2 Video;",
	"-;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[124],HDMI scaler deinterlacer,Weave,Bob;",
	"O[123],Native timing pattern,Off,On;",
	"O[125],Native pattern motion,Static,Moving;",
	"O[120],Interlaced output,Native 480i,800x600 Diagnostic;",
	"O[3:1],Audio test,Off,44.1k Mono,44.1k Stereo,48k Mono,48k Stereo;",
	"O[126],Audio output,HDMI,S/PDIF AC-3;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"v,2;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

// AUDIO_FORK_POINT[STREAM_SPLIT]: advisory v0.5.0 handoff, not a permanent ABI.
// ioctl_* currently carries one raw .m2v elementary video stream.  A future
// HPS/container/DVD demux should split compressed audio and video ABOVE this
// decoder boundary: keep mpeg2_stream_* video-only and add a sibling audio FIFO
// with its own data/valid/ready backpressure.  Do not route audio bytes through
// mpeg2_h262_frontend or mpeg2_h262_two_picture_probe in MediaPlayer_top_02.svh;
// those modules and their parser/reference state are deliberately video-private.
// ARM -> FPGA MPEG-2 elementary-stream transfer.
wire        ioctl_download;
wire [15:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        mpeg2_stream_full;
wire [14:0] mpeg2_burst_credit;
wire        mpeg2_burst_ready, mpeg2_burst_fault;
wire [31:0] mpeg2_burst_words;
wire [15:0] mpeg2_burst_digest;
wire        mpeg2_stream_empty;
wire [7:0]  mpeg2_fifo_data;
wire [7:0]  mpeg2_stream_data;
wire [7:0]  mpeg2_new_extracted_stream_data;
wire        mpeg2_new_system_input_ready;
wire        mpeg2_new_system_input_valid;
wire        mpeg2_stream_rd;
wire        mpeg2_stream_wr;
wire        mpeg2_new_decode_stream_valid;
wire        mpeg2_new_extracted_stream_valid;
wire        mpeg2_new_clean_video_input_ready;
wire        mpeg2_new_stream_ready;
wire        mpeg2_new_decoder_stream_ready;
wire        mpeg2_new_b_presentation_hold;
wire        mpeg2_new_p_destination_ownership_hold;
wire [32:0] mpeg2_new_extracted_pts_90k;
wire        mpeg2_new_extracted_metadata_valid;
wire        mpeg2_new_extracted_metadata_ready;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .MEDIA_BURST(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(0),
	.ps2_key(ps2_key),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.ioctl_wait(ioctl_download && mpeg2_stream_full),
	.ioctl_burst_credit(mpeg2_burst_credit),
	.ioctl_burst_words(mpeg2_burst_words),
	.ioctl_burst_digest(mpeg2_burst_digest),
	.ioctl_burst_ready(mpeg2_burst_ready && ioctl_download && ioctl_index[5:0] == 6'd1),
	.ioctl_burst_fault(mpeg2_burst_fault)
);

///////////////////////   CLOCKS   ///////////////////////////////

// AUDIO_FORK_POINT[CLOCK_RESET]: advisory v0.5.0 handoff, not a permanent ABI.
// Add audio as a sibling clock/reset consumer.  Reusing clk_mpeg2 is acceptable
// only if its throughput and timing remain suitable; otherwise add an explicit
// audio clock domain and synchronize reset release/CDC using the same discipline
// below.  Audio FIFO readiness must not be ANDed into mpeg2_new_stream_ready:
// routine A/V synchronization belongs above the two independent decoder pipes.
wire clk_sys;
wire clk_video;
wire clk_mpeg2;
wire clk_mpeg2_mem;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_video),
	.outclk_2(clk_mpeg2),
	.outclk_3(clk_mpeg2_mem)
);

// kate - Phase 1P CDC/reset closure.
//
// RESET, status[0], and buttons[1] originate outside the MPEG/video clock
// domains.  Treat their OR as an asynchronous reset request, then synchronize
// reset RELEASE independently into each destination domain.  Assertion is
// asynchronous into these small synchronizer chains, so even a short request
// is stretched until the destination clock has observed it.
//
// This is an implementation/timing-safety change, not an H.262 requirement.
wire reset_request = RESET | status[0] | buttons[1];

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_mpeg2_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_video_sync;

always @(posedge clk_mpeg2 or posedge reset_request) begin
	if (reset_request)
		reset_mpeg2_sync <= 3'b111;
	else
		reset_mpeg2_sync <= {reset_mpeg2_sync[1:0], 1'b0};
end

always @(posedge clk_video or posedge reset_request) begin
	if (reset_request)
		reset_video_sync <= 3'b111;
	else
		reset_video_sync <= {reset_video_sync[1:0], 1'b0};
end

wire reset_mpeg2_base = reset_mpeg2_sync[2];
wire reset_video = reset_video_sync[2];

// Entry 237: every ioctl_download rising edge is a new elementary-stream
// session.  Rearm all MPEG-domain state for the same behavior as a first load,
// while leaving the dual-clock FIFO and video timing on their existing reset
// boundaries.  The rearm output is also an input-read gate below, preventing
// the first newly visible FIFO byte from being consumed on a reset edge.
wire mpeg2_download_rearm_reset;
mpeg2_h262_download_rearm mpeg2_h262_download_rearm
(
	.clk            (clk_mpeg2),
	.reset          (reset_mpeg2_base),
	.download_async (ioctl_download),
	.rearm_reset    (mpeg2_download_rearm_reset)
);

wire reset_mpeg2 = reset_mpeg2_base || mpeg2_download_rearm_reset;

// Entry 395: atomic Audio mode changes cross from clk_sys to clk_mpeg2 and
// CLK_AUDIO through dedicated DCFIFO mailboxes. Entry 410 sends the same reset
// event on every new file download so embedded PCM replay cannot inherit FIFO,
// source, scheduler or underrun state from the prior session.
wire [2:0] audio_test_mode = status[3:1];
reg  [2:0] audio_test_mode_prev;
reg        audio_download_prev;
reg  [4:0] audio_fifo_reset_stretch;

wire audio_mode_change_sys = (audio_test_mode != audio_test_mode_prev);
wire audio_download_start_sys = ioctl_download && !audio_download_prev;
wire audio_control_event_sys =
	audio_mode_change_sys || audio_download_start_sys;

always @(posedge clk_sys or posedge reset_request) begin
	if (reset_request) begin
		audio_test_mode_prev   <= 3'd0;
		audio_download_prev    <= 1'b0;
		audio_fifo_reset_stretch <= 5'd0;
	end
	else begin
		audio_test_mode_prev <= audio_test_mode;
		audio_download_prev  <= ioctl_download;
		if (audio_control_event_sys)
			audio_fifo_reset_stretch <= 5'd31;
		else if (audio_fifo_reset_stretch != 5'd0)
			audio_fifo_reset_stretch <= audio_fifo_reset_stretch - 5'd1;
	end
end

wire audio_fifo_reset_request =
	reset_request || (audio_fifo_reset_stretch != 5'd0);

reg  [2:0] audio_mode_pending_data;
reg        audio_mode_pending_valid;
wire       audio_mode_src_full;
wire       audio_mode_src_empty;
wire [2:0] audio_mode_src_data;
wire       audio_mode_src_wr;
wire       audio_mode_src_rd;
wire       audio_restart_out_full;
wire       audio_restart_out_empty;
wire       audio_restart_out_data;
wire       audio_restart_out_wr;
wire       audio_restart_out_rd;

wire audio_mode_send =
	audio_mode_pending_valid &&
	!audio_mode_src_full &&
	!audio_restart_out_full;

assign audio_mode_src_wr = audio_mode_send;
assign audio_restart_out_wr = audio_mode_send;

always @(posedge clk_sys or posedge reset_request) begin
	if (reset_request) begin
		audio_mode_pending_data  <= 3'd0;
		audio_mode_pending_valid <= 1'b0;
	end
	else if (audio_mode_pending_valid) begin
		if (audio_mode_send) begin
			if (audio_control_event_sys) begin
				audio_mode_pending_data  <= audio_test_mode;
				audio_mode_pending_valid <= 1'b1;
			end
			else begin
				audio_mode_pending_valid <= 1'b0;
			end
		end
		else if (audio_control_event_sys) begin
			audio_mode_pending_data <= audio_test_mode;
		end
	end
	else if (audio_control_event_sys) begin
		audio_mode_pending_data  <= audio_test_mode;
		audio_mode_pending_valid <= 1'b1;
	end
end

dcfifo #(
	.lpm_numwords         (4),
	.lpm_showahead        ("ON"),
	.lpm_type             ("dcfifo"),
	.lpm_width            (3),
	.lpm_widthu           (2),
	.overflow_checking    ("ON"),
	.underflow_checking   ("ON"),
	.use_eab              ("ON"),
	.rdsync_delaypipe     (4),
	.wrsync_delaypipe     (4),
	.write_aclr_synch     ("ON"),
	.read_aclr_synch      ("ON")
) audio_mode_src_fifo
(
	.aclr    (reset_request),
	.data    (audio_mode_pending_data),
	.wrclk   (clk_sys),
	.wrreq   (audio_mode_src_wr),
	.wrfull  (audio_mode_src_full),
	.q       (audio_mode_src_data),
	.rdclk   (clk_mpeg2),
	.rdreq   (audio_mode_src_rd),
	.rdempty (audio_mode_src_empty)
);

dcfifo #(
	.lpm_numwords         (4),
	.lpm_showahead        ("ON"),
	.lpm_type             ("dcfifo"),
	.lpm_width            (1),
	.lpm_widthu           (2),
	.overflow_checking    ("ON"),
	.underflow_checking   ("ON"),
	.use_eab              ("OFF"),
	.rdsync_delaypipe     (4),
	.wrsync_delaypipe     (4),
	.write_aclr_synch     ("ON"),
	.read_aclr_synch      ("ON")
) audio_restart_out_fifo
(
	.aclr    (reset_request),
	.data    (1'b1),
	.wrclk   (clk_sys),
	.wrreq   (audio_restart_out_wr),
	.wrfull  (audio_restart_out_full),
	.q       (audio_restart_out_data),
	.rdclk   (CLK_AUDIO),
	.rdreq   (audio_restart_out_rd),
	.rdempty (audio_restart_out_empty)
);

assign audio_mode_src_rd = !audio_mode_src_empty;
assign audio_restart_out_rd = !audio_restart_out_empty;

reg [6:0] audio_src_reset_count;
reg [2:0] audio_mode_src;

always @(posedge clk_mpeg2) begin
	if (reset_mpeg2_base) begin
		audio_src_reset_count <= 7'd127;
		audio_mode_src        <= 3'd0;
	end
	else begin
		if (audio_src_reset_count != 7'd0)
			audio_src_reset_count <= audio_src_reset_count - 7'd1;

		if (!audio_mode_src_empty) begin
			audio_src_reset_count <= 7'd127;
			audio_mode_src        <= audio_mode_src_data;
		end
	end
end

wire reset_audio_src =
	reset_mpeg2_base || (audio_src_reset_count != 7'd0);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_audio_out_sync;
reg [6:0] audio_out_reset_count;

always @(posedge CLK_AUDIO or posedge reset_request) begin
	if (reset_request)
		reset_audio_out_sync <= 3'b111;
	else
		reset_audio_out_sync <= {reset_audio_out_sync[1:0], 1'b0};
end

wire reset_audio_out_system = reset_audio_out_sync[2];

always @(posedge CLK_AUDIO) begin
	if (reset_audio_out_system)
		audio_out_reset_count <= 7'd127;
	else if (!audio_restart_out_empty)
		audio_out_reset_count <= 7'd127;
	else if (audio_out_reset_count != 7'd0)
		audio_out_reset_count <= audio_out_reset_count - 7'd1;
end

wire reset_audio_out =
	reset_audio_out_system || (audio_out_reset_count != 7'd0);

wire               audio_pcm_valid;
wire               audio_pcm_ready;
wire signed [15:0] audio_pcm_left;
wire signed [15:0] audio_pcm_right;
wire               audio_pcm_stereo;
wire               audio_pcm_rate_48k;
wire               audio_pcm_end;
wire               audio_pcm_fifo_full;
wire               audio_pcm_fifo_empty;
wire [34:0]        audio_pcm_fifo_data;
wire [13:0]        audio_pcm_fifo_used;
wire [13:0]        audio_pcm_fifo_read_used;
wire               audio_pcm_fifo_rd;
wire               audio_pcm_underrun;
wire               audio_pcm_playback_complete;

wire               audio_test_valid;
wire signed [15:0] audio_test_left;
wire signed [15:0] audio_test_right;
wire               audio_test_stereo;
wire               audio_test_rate_48k;
wire               mpeg2_new_inband_pcm_valid;
wire               mpeg2_new_inband_pcm_end;
wire [15:0]        mpeg2_new_inband_pcm_left;
wire [15:0]        mpeg2_new_inband_pcm_right;
wire               mpeg2_new_inband_pcm_stereo;
wire               mpeg2_new_inband_pcm_rate_48k;
wire               mpeg2_new_inband_pcm_ready;
wire [13:0]        mpeg2_new_inband_pcm_sample_count;
wire               mpeg2_new_inband_pcm_protocol_error;

wire audio_embedded_mode = (audio_mode_src == 3'd0);
wire audio_pcm_accepted = audio_pcm_valid && audio_pcm_ready;

reg audio_pcm_session_seen;
reg audio_pcm_source_ended;

always @(posedge clk_mpeg2) begin
	if (reset_mpeg2 || reset_audio_src) begin
		audio_pcm_session_seen <= 1'b0;
		audio_pcm_source_ended <= 1'b0;
	end
	else if (audio_embedded_mode && audio_pcm_accepted) begin
		audio_pcm_session_seen <= 1'b1;
		if (audio_pcm_end)
			audio_pcm_source_ended <= 1'b1;
	end
end

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] audio_pcm_source_ended_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] audio_pcm_complete_sync;

always @(posedge CLK_AUDIO) begin
	if (reset_audio_out)
		audio_pcm_source_ended_sync <= 2'b00;
	else
		audio_pcm_source_ended_sync <=
			{audio_pcm_source_ended_sync[0], audio_pcm_source_ended};
end

always @(posedge clk_mpeg2) begin
	if (reset_mpeg2 || reset_audio_src)
		audio_pcm_complete_sync <= 2'b00;
	else
		audio_pcm_complete_sync <=
			{audio_pcm_complete_sync[0], audio_pcm_playback_complete};
end

wire audio_pcm_terminal_pending =
	audio_embedded_mode &&
	audio_pcm_session_seen &&
	!audio_pcm_complete_sync[1];

assign audio_pcm_ready = !audio_pcm_fifo_full;
assign mpeg2_new_inband_pcm_ready =
	audio_embedded_mode ? audio_pcm_ready : 1'b1;
assign audio_pcm_valid = audio_embedded_mode ?
	(mpeg2_new_inband_pcm_valid || mpeg2_new_inband_pcm_end) :
	audio_test_valid;
assign audio_pcm_end =
	audio_embedded_mode && mpeg2_new_inband_pcm_end;
assign audio_pcm_left = audio_embedded_mode ?
	$signed(mpeg2_new_inband_pcm_left) : audio_test_left;
assign audio_pcm_right = audio_embedded_mode ?
	$signed(mpeg2_new_inband_pcm_right) : audio_test_right;
assign audio_pcm_stereo = audio_embedded_mode ?
	mpeg2_new_inband_pcm_stereo : audio_test_stereo;
assign audio_pcm_rate_48k = audio_embedded_mode ?
	mpeg2_new_inband_pcm_rate_48k : audio_test_rate_48k;

audio_pcm_test_source audio_pcm_test_source
(
	.clk      (clk_mpeg2),
	.reset    (reset_audio_src),
	.mode     (audio_mode_src),
	.ready    (!audio_embedded_mode && audio_pcm_ready),
	.valid    (audio_test_valid),
	.left     (audio_test_left),
	.right    (audio_test_right),
	.stereo   (audio_test_stereo),
	.rate_48k (audio_test_rate_48k)
);

audio_pcm_fifo audio_pcm_fifo
(
	.reset    (audio_fifo_reset_request),
	.wr_clk   (clk_mpeg2),
	.wr_data  ({audio_pcm_end, audio_pcm_rate_48k, audio_pcm_stereo,
	            audio_pcm_left, audio_pcm_right}),
	.wr_en    (audio_pcm_valid && audio_pcm_ready),
	.wr_full  (audio_pcm_fifo_full),
	.wr_used  (audio_pcm_fifo_used),
	.rd_clk   (CLK_AUDIO),
	.rd_en    (audio_pcm_fifo_rd),
	.rd_data  (audio_pcm_fifo_data),
	.rd_empty (audio_pcm_fifo_empty),
	.rd_used  (audio_pcm_fifo_read_used)
);

audio_pcm_output_adapter audio_pcm_output_adapter
(
	.clk        (CLK_AUDIO),
	.reset      (reset_audio_out),
	.fifo_data  (audio_pcm_fifo_data),
	.fifo_empty (audio_pcm_fifo_empty),
	.fifo_used  (audio_pcm_fifo_read_used),
	.source_ended(audio_pcm_source_ended_sync[1]),
	.fifo_rd    (audio_pcm_fifo_rd),
	.audio_l    (audio_pcm_output_l),
	.audio_r    (audio_pcm_output_r),
	.underrun   (audio_pcm_underrun),
	.playback_complete(audio_pcm_playback_complete)
);

reg [6:0] audio_pcm_fifo_peak;
reg [1:0] audio_pcm_underrun_sync;

// Entry 693: audio starves because the shared transport byte path halts while
// the clean video queue is full, so the quantity that sizes the audio FIFO is
// how long a single block lasts.  Measure it here, where the stall is visible,
// rather than inferring it from a drained FIFO.  The first-error snapshot
// latch reports only the first underrun, so count them instead: a run that
// still starves must say how often, not merely that it did.
reg [31:0] transport_block_longest;
reg [31:0] transport_block_current;
reg [15:0] transport_block_count;
reg [15:0] audio_pcm_underrun_count;
reg [13:0] audio_pcm_fifo_floor;
reg        audio_pcm_floor_armed;

wire transport_blocked =
	mpeg2_new_system_input_valid && !mpeg2_new_system_input_ready;

always @(posedge clk_mpeg2) begin
	if (reset_mpeg2) begin
		audio_pcm_fifo_peak      <= 7'd0;
		audio_pcm_underrun_sync <= 2'b00;
		transport_block_longest  <= 32'd0;
		transport_block_current  <= 32'd0;
		transport_block_count    <= 16'd0;
		audio_pcm_underrun_count <= 16'd0;
		audio_pcm_fifo_floor     <= 14'h3FFF;
		audio_pcm_floor_armed    <= 1'b0;
	end
	else begin
		audio_pcm_underrun_sync <=
			{audio_pcm_underrun_sync[0], audio_pcm_underrun};
		if (audio_pcm_fifo_full || |audio_pcm_fifo_used[13:7])
			audio_pcm_fifo_peak <= 7'h7F;
		else if (audio_pcm_fifo_used[6:0] > audio_pcm_fifo_peak)
			audio_pcm_fifo_peak <= audio_pcm_fifo_used[6:0];

		// Each rising edge of the synchronised underrun is one starvation.
		if (audio_pcm_underrun_sync[0] && !audio_pcm_underrun_sync[1] &&
		    !(&audio_pcm_underrun_count))
			audio_pcm_underrun_count <= audio_pcm_underrun_count + 1'b1;

		// A block is one continuous run of stalled transport bytes.  Close it
		// on the falling edge so only completed runs enter the maximum.
		if (transport_blocked) begin
			if (!(&transport_block_current))
				transport_block_current <= transport_block_current + 1'b1;
		end
		else if (|transport_block_current) begin
			if (transport_block_current > transport_block_longest)
				transport_block_longest <= transport_block_current;
			if (!(&transport_block_count))
				transport_block_count <= transport_block_count + 1'b1;
			transport_block_current <= 32'd0;
		end

		// Track the floor only once the FIFO has filled at least once, so the
		// empty start of a session is not reported as the minimum.
		if (audio_pcm_fifo_used[13:11] != 3'd0)
			audio_pcm_floor_armed <= 1'b1;
		if (audio_pcm_floor_armed && audio_pcm_fifo_used < audio_pcm_fifo_floor)
			audio_pcm_fifo_floor <= audio_pcm_fifo_used;
	end
end

// kate - Phase 1Ob: the streaming H.262 bitreader continues to own input
// backpressure while picture_data() advances across every slice of the first
// supported I-picture.  Slice boundaries remain inside the bitreader so no
// alignment or payload bytes are discarded.
// Before the first slice is selected, bytes flow continuously for start-code/header
// parsing.  During slice parsing the bitreader stalls this FIFO whenever its
// current payload byte has not been fully consumed, including IQ/IDCT waits.
assign mpeg2_stream_wr =
	ioctl_download &&
	ioctl_wr &&
	(ioctl_index[5:0] == 6'd1) &&
	!mpeg2_stream_full;

// Phase 1V: the decoder owns syntax/persistence backpressure, while the top
// level additionally pauses between a persisted B and completion of its proven
// scratch->future-reference presentation transaction. This prevents a later
// P/B pair from overtaking the two-vblank display-order operation.
// kate - Commit 162 adds a second, P-only ownership pause after the following
// picture header has been consumed and classified.  It never blocks the header
// needed to distinguish a consecutive P from a following B.
assign mpeg2_new_stream_ready =
	!mpeg2_download_rearm_reset &&
	mpeg2_new_decoder_stream_ready &&
	!mpeg2_new_b_presentation_hold &&
	!mpeg2_new_p_destination_ownership_hold;

// Entry 217: downstream raster and DDR errors are sticky, but their engines
// cannot produce the persistence acknowledgement that normally releases the
// parser.  Drain the transport after any such fatal result without presenting
// discarded bytes as valid decoder input.  This lets ioctl_download retire so
// the existing post-load LED snapshot can report the first failure.
// Entry 369: synchronise the file-transfer lifetime into the decoder domain
// so the metadata extractor can flush its residual window.  Without this
// the final three bytes of every stream would stay in the window and the
// sequence_end_code would never reach the decoder.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_download_active_sync;
always @(posedge clk_mpeg2 or posedge reset_mpeg2_base) begin
	if (reset_mpeg2_base)
		mpeg2_download_active_sync <= 3'b000;
	else
		mpeg2_download_active_sync <=
			{mpeg2_download_active_sync[1:0],ioctl_download};
end

wire mpeg2_new_system_input_end =
	!mpeg2_download_active_sync[2] &&
	!mpeg2_download_rearm_reset &&
	mpeg2_stream_empty;

wire mpeg2_new_transport_fatal_error =
	mpeg2_new_syntax_error ||
	mpeg2_new_phase1_probe_error ||
	mpeg2_new_pred_error ||
	mpeg2_new_inverse_quant_error ||
	mpeg2_new_inverse_quant_unsupported_matrix ||
	mpeg2_new_idct_error ||
	mpeg2_new_recon_error ||
	mpeg2_new_ddr_store_error ||
	mpeg2_new_ddr_cache_error ||
	mpeg2_new_b_presentation_error;

mpeg2_h262_stream_transport_gate mpeg2_h262_stream_transport_gate
(
	.clk              (clk_mpeg2),
	.reset            (reset_mpeg2),
	.fifo_empty       (mpeg2_stream_empty),
	.decoder_ready    (mpeg2_new_system_input_ready),
	.fatal_error      (mpeg2_new_transport_fatal_error),
	.fifo_read        (mpeg2_stream_rd),
	.decoder_valid    (mpeg2_new_system_input_valid)
);

mpeg2_h262_inband_metadata mpeg2_h262_inband_metadata
(
	.clk                (clk_mpeg2),
	.reset              (reset_mpeg2),
	.input_data         (mpeg2_fifo_data),
	.input_valid        (mpeg2_new_system_input_valid),
	.input_ready        (mpeg2_new_system_input_ready),
	.input_end          (mpeg2_new_system_input_end),
	.stream_data        (mpeg2_new_extracted_stream_data),
	.stream_valid       (mpeg2_new_extracted_stream_valid),
	.stream_ready       (mpeg2_new_clean_video_input_ready),
	.pts_90k            (mpeg2_new_extracted_pts_90k),
	.picture_structure  (mpeg2_new_inband_picture_structure),
	.top_field_first    (mpeg2_new_inband_top_field_first),
	.repeat_first_field (mpeg2_new_inband_repeat_first_field),
	.progressive_frame  (mpeg2_new_inband_progressive_frame),
	.metadata_valid     (mpeg2_new_extracted_metadata_valid),
	.metadata_ready     (mpeg2_new_extracted_metadata_ready),
	.metadata_count     (mpeg2_new_inband_count),
	.pcm_left           (mpeg2_new_inband_pcm_left),
	.pcm_right          (mpeg2_new_inband_pcm_right),
	.pcm_stereo         (mpeg2_new_inband_pcm_stereo),
	.pcm_rate_48k       (mpeg2_new_inband_pcm_rate_48k),
	.pcm_valid          (mpeg2_new_inband_pcm_valid),
	.pcm_end            (mpeg2_new_inband_pcm_end),
	.pcm_ready          (mpeg2_new_inband_pcm_ready),
	.pcm_sample_count   (mpeg2_new_inband_pcm_sample_count),
	.pcm_protocol_error (mpeg2_new_inband_pcm_protocol_error)
);

wire mpeg2_new_clean_video_pending;
mpeg2_h262_clean_video_queue mpeg2_h262_clean_video_queue
(
	.clk                   (clk_mpeg2),
	.reset                 (reset_mpeg2),
	.input_data            (mpeg2_new_extracted_stream_data),
	.input_valid           (mpeg2_new_extracted_stream_valid),
	.input_ready           (mpeg2_new_clean_video_input_ready),
	.input_metadata_pts    (mpeg2_new_extracted_pts_90k),
	.input_metadata_valid  (mpeg2_new_extracted_metadata_valid),
	.input_metadata_ready  (mpeg2_new_extracted_metadata_ready),
	.output_data           (mpeg2_stream_data),
	.output_valid          (mpeg2_new_decode_stream_valid),
	.output_ready          (mpeg2_new_stream_ready),
	.output_pending_debug  (mpeg2_new_clean_video_pending),
	.output_metadata_pts   (mpeg2_new_inband_pts_90k),
	.output_metadata_valid (mpeg2_new_inband_valid)
);

mpeg2_stream_fifo mpeg2_stream_fifo
(
	// kate - DCFIFO owns reset-release synchronization for wr_clk and rd_clk.
	.reset    (reset_request),

	.wr_clk   (clk_sys),
	.wr_data  (mpeg2_stream_wr ? ioctl_dout : 16'd0),
	.wr_en    (mpeg2_stream_wr),
	.wr_full  (mpeg2_stream_full),
	.wr_attempt(ioctl_download && ioctl_wr && ioctl_index[5:0] == 6'd1),
	.burst_credit(mpeg2_burst_credit),
	.burst_ready(mpeg2_burst_ready),
	.burst_fault(mpeg2_burst_fault),
	.burst_words(mpeg2_burst_words),
	.burst_digest(mpeg2_burst_digest),

	.rd_clk   (clk_mpeg2),
	.rd_en    (mpeg2_stream_rd),
	.rd_data  (mpeg2_fifo_data),
	.rd_empty (mpeg2_stream_empty)
);

// AUDIO_FORK_POINT[DDR_CLIENT]: advisory v0.5.0 handoff, not a permanent ABI.
// If audio eventually needs external buffering, integrate it as an explicit
// additional DDR client at mpeg2_h262_ddram_arbiter in MediaPlayer_top_06.svh
// (or a successor system arbiter).  Allocate a separate address region and
// preserve the video writer/reader/prediction response ownership and the
// [17:16] frame-region protection.  Never reuse P/B prediction request signals
// as an implicit audio transport.  Prefer on-chip FIFO/RAM when practical.
// The DDR service and Phase 1S/1T clients run in the decoder clock domain.
assign DDRAM_CLK = clk_mpeg2;

///////////////////////   VIDEO TIMING   /////////////////////////

// AUDIO_FORK_POINT[AV_SYNC]: advisory v0.5.0 handoff, not a permanent ABI.
// Future A/V synchronization should observe the presentation side, not H.262
// syntax state.  Useful starting signals are display_v_pos here plus
// mpeg2_new_swap_window_pulse / mpeg2_new_b_presentation_complete in
// MediaPlayer_top_04.svh and the actual framebuffer swap in _06.svh.  Export a
// clean video-present/timebase event to a higher-level A/V controller; let that
// controller use timestamps/buffer occupancy/drop-repeat policy rather than
// directly stalling either codec's internal parser for normal synchronization.
wire [11:0] display_h_pos;
wire [11:0] display_v_pos;
wire        display_pixel_ce;
wire        display_pixel_en;
wire        display_h_sync;
wire        display_v_sync;
wire        display_field;
wire        display_field_window;
wire        display_frame_window;
wire        display_field_swap_window;
wire        display_native_interlaced;
wire        display_native_timing_pattern;
wire        display_native_timing_pattern_moving;
wire        display_hdmi_bob_deinterlace;
wire        mpeg2_new_native_active_mpeg2;

// MiSTer's scaler consumes this request only on its processed HDMI path.
// Direct video continues to carry the core's native interlaced timing.
assign HDMI_BOB_DEINT = display_hdmi_bob_deinterlace;

wire [7:0]  fb_video_r;
wire [7:0]  fb_video_g;
wire [7:0]  fb_video_b;
wire        fb_video_de;
wire        fb_video_hs;
wire        fb_video_vs;
wire [7:0]  native_pattern_r;
wire [7:0]  native_pattern_g;
wire [7:0]  native_pattern_b;
wire        native_pattern_de;
wire        native_pattern_hs;
wire        native_pattern_vs;
wire [7:0]  presentation_base_r;
wire [7:0]  presentation_base_g;
wire [7:0]  presentation_base_b;
wire        presentation_base_de;
wire        presentation_base_hs;
wire        presentation_base_vs;
wire [7:0]  cadence_video_r;
wire [7:0]  cadence_video_g;
wire [7:0]  cadence_video_b;
wire        cadence_snapshot_ready;

// ---------------------------------------------------------------------------
// Entry 389: presentation time base.
//
// The 90 kHz System Time Clock of H.222.0 is anchored to CLK_AUDIO (24.576
// MHz), the same domain sys/audio_out.sv clocks samples out on, so externally
// decoded audio will be consumed drift-free by construction once the PCM sink
// exists.  Entry 425 correction: this is no longer true.  Since the PTS
// timeline was wired in at MediaPlayer_top_05.svh, presentation is not
// free-running -- mpeg2_h262_pts_presentation_timeline drives the scheduler's
// timestamp admission gate, so timestamped pictures wait for this clock.
//
// Only a single bit crosses domains.  A multi-bit counter synchronised into
// clk_mpeg2 could tear across a carry, and a 33-bit gray decode would be a
// 33-level XOR chain -- a new timing problem on a design that just spent this
// development run recovering margin.  Instead the clock emits single-bit
// 90 kHz and 1 Hz pulses.  Each crosses through an ordinary synchroniser; the
// former advances the decoder-domain presentation timeline and the latter
// remains the cadence profiler's human-readable seconds counter.
// ---------------------------------------------------------------------------
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] stc_audio_reset_sync;
always @(posedge CLK_AUDIO or posedge reset_mpeg2_base) begin
	if (reset_mpeg2_base) stc_audio_reset_sync <= 2'b11;
	else                  stc_audio_reset_sync <= {stc_audio_reset_sync[0],1'b0};
end
wire stc_audio_reset = stc_audio_reset_sync[1];

wire        stc_pulse_1hz;
wire        stc_tick_90k_audio;
wire [32:0] stc_90k_value;

mpeg2_h262_system_time_clock mpeg2_h262_system_time_clock
(
	.clk           (CLK_AUDIO),
	.reset         (stc_audio_reset),
	.run           (1'b1),
	.load_valid    (1'b0),
	.load_value    (33'd0),
	.stc_90k       (stc_90k_value),
	.tick_90k      (stc_tick_90k_audio),
	.stc_180k_half (),
	.pulse_1hz     (stc_pulse_1hz)
);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] stc_pulse_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] stc_tick_90k_sync;
reg [13:0] mpeg2_new_stc_seconds;
wire mpeg2_new_stc_tick_90k =
	(stc_tick_90k_sync[2:1] == 2'b01);
always @(posedge clk_mpeg2) begin
	if (reset_mpeg2) begin
		stc_pulse_sync        <= 3'b000;
		stc_tick_90k_sync     <= 3'b000;
		mpeg2_new_stc_seconds <= 14'd0;
	end
	else begin
		stc_pulse_sync <= {stc_pulse_sync[1:0],stc_pulse_1hz};
		stc_tick_90k_sync <= {stc_tick_90k_sync[1:0],stc_tick_90k_audio};
		if (stc_pulse_sync[2:1] == 2'b01)
			mpeg2_new_stc_seconds <= mpeg2_new_stc_seconds + 14'd1;
	end
end
