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
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

// Movie PCM is signed stereo, scheduled in the CLK_AUDIO domain by the MP2
// sink and passed through the normal MiSTer audio output/filter path.
wire [15:0] audio_pcm_output_l;
wire [15:0] audio_pcm_output_r;
assign AUDIO_S = 1'b1;
assign AUDIO_L = audio_pcm_output_l;
assign AUDIO_R = audio_pcm_output_r;
assign AUDIO_MIX = 2'd0;

assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

// The OSD alone selects display shape; sequence metadata never overrides it.
wire ar;
video_config_cdc #(.WIDTH(1)) aspect_config (
 .src_clk(clk_sys), .dst_clk(clk_video),
 .src_data(status[121]), .dst_data(ar)
);
assign VIDEO_ARX = ar ? 13'd16 : 13'd4;
assign VIDEO_ARY = ar ? 13'd9 : 13'd3;

`include "build_id.v"
// Status bits 3:1 remain reserved after removal of Audio test.
localparam CONF_STR = {
	"MediaPlayer;;",
	"S0,MPGFL*,Load media;",
`include "MediaPlayer_subtitle_menu.svh"
	"-;",
	"-;",
	"O[121],Aspect ratio,4:3,16:9;",
	"O[6],Refresh rate,59.94 Hz,50 Hz;",
	"O[5:4],Color matrix,Auto,BT.601,BT.709;",

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

// Mounted-file sector reads leave stock Main's menu polling responsive.
wire [1:0] media_img_mounted;
wire [63:0] media_img_size;
wire [31:0] media_sd_lba[2];
wire [5:0] media_sd_blocks[2];
wire [1:0] media_sd_rd,media_sd_ack,media_host_rd,media_reader_wr;
wire [12:0] media_sd_addr;
wire [15:0] media_sd_data;
wire [15:0] media_sd_unused[2];
assign media_sd_unused[0]=16'd0;
assign media_sd_unused[1]=16'd0;
wire media_sd_wr;
wire [8:0] media_stream_data,media_fifo_data;
wire [14:0] media_fifo_used;
wire [15:0] media_fifo_occupancy=mpeg2_stream_full ? 16'd32768 : {1'b0,media_fifo_used};
wire media_stream_valid,media_reader_idle;
wire media_prefill_mpeg,media_fatal_sys,media_reader_error_mpeg;
reg media_prefill=0;
wire media_reader_cancel,media_fifo_reset,media_reader_start;
wire media_decoder_reset,media_quiesce,media_ddr_idle;
wire [63:0] media_byte_position;
wire [31:0] media_generation;
wire [3:0] media_error;
reg media_mount_d=0,media_user_reset_d=0;
reg [63:0] media_file_size=0;
wire media_user_reset=status[0] | buttons[1];
wire media_eof_close,media_video_eof_close;
wire media_music_hint,media_music_hint_mpeg;
reg media_music_mode=0;
wire media_movie_ddr_idle,media_music_idle;
wire media_music_input_ready,media_music_metadata;
wire [35:0] media_music_total,media_music_total_sys;
wire [3:0] media_music_decode_error;
wire [37:0] media_music_status_sys;
wire [34:0] media_music_elapsed,media_music_duration;
wire [28:0] music_mem_addr,movie_mem_addr;
wire [63:0] music_mem_data,movie_mem_data;
wire [7:0] music_mem_be,movie_mem_be,movie_mem_burst;
wire music_mem_read,music_mem_write,movie_mem_read,movie_mem_write;
wire music_play_request=media_music_hint && media_file_size!=0;
assign PLAYER_MUSIC=music_play_request;
assign PLAYER_MUSIC_PAUSED=media_paused_sys;
assign PLAYER_PCM_RESET=reset_mpeg2 || !media_music_mode;
assign media_ddr_idle=media_music_mode?media_music_idle:media_movie_ddr_idle;
assign media_eof_close=media_video_eof_close || (music_play_request && !media_fifo_reset &&
 (media_music_status_sys[37] || media_music_status_sys[36] || media_music_error_sys));
wire media_music_error_sys;
video_config_cdc #(.WIDTH(1)) music_hint_cdc(.src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(media_music_hint),.dst_data(media_music_hint_mpeg));
video_config_cdc #(.WIDTH(1)) music_error_cdc(.src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(|media_music_decode_error),.dst_data(media_music_error_sys));
video_config_cdc #(.WIDTH(36)) music_total_cdc(.src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(media_music_total),.dst_data(media_music_total_sys));
video_config_cdc #(.WIDTH(38)) music_position_cdc(.src_clk(CLK_AUDIO_CD),.dst_clk(clk_sys),
 .src_data({PLAYER_MUSIC_FINISHED,PLAYER_MUSIC_ERROR,PLAYER_MUSIC_POSITION}),.dst_data(media_music_status_sys));
media_music_time music_time(.clk(clk_sys),.reset(RESET||media_new_file),
 .position(media_music_status_sys[35:0]),.total(media_music_total_sys),.elapsed_q(media_music_elapsed),.total_q(media_music_duration));
// The bus mode changes only while both previous clients have drained and
// the session is holding decoder reset. It stays fixed for all live requests.
always @(posedge clk_mpeg2)begin
 if(reset_mpeg2_base)media_music_mode<=0;
 else if(media_decoder_reset && media_music_idle && media_movie_ddr_idle)media_music_mode<=media_music_hint_mpeg;
end

wire media_external_new_file=(media_img_mounted[0] && !media_mount_d) ||
                            (media_user_reset && !media_user_reset_d);
wire media_new_file=media_external_new_file || media_eof_close;
wire media_paused_sys,media_seek_sys,media_seek_restart;
wire [34:0] media_target_sys,media_elapsed_sys,media_elapsed_q;
wire media_seek_done,media_seek_done_sys;
wire [36:0] media_control_mpeg;
wire media_paused=media_control_mpeg[36];
wire media_seeking=media_control_mpeg[35];
wire [34:0] media_target_q=media_control_mpeg[34:0];
wire media_search_restart,media_search_busy,media_probe_sys;
wire [40:0] media_start_offset,media_video_start;
wire [7:0] media_search_tag,media_search_echo;
wire [90:0] media_seek_config_mpeg;
wire [7:0] media_search_tag_mpeg=media_seek_config_mpeg[90:83];
wire media_probe_mpeg=media_seek_config_mpeg[82];
wire [40:0] media_start_offset_mpeg=media_seek_config_mpeg[81:41];
wire [40:0] media_video_start_mpeg=media_seek_config_mpeg[40:0];
wire media_movie_origin_valid;
wire [32:0] media_movie_origin;
wire media_point_found;
wire [32:0] media_point_pts;
wire [40:0] media_point_pack,media_point_sequence;
wire [159:0] media_probe_response_sys;
wire media_restart=media_new_file||media_search_restart;
video_config_cdc #(.WIDTH(91)) seek_file_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data({media_search_tag,media_probe_sys,media_start_offset,media_video_start}),
 .dst_data(media_seek_config_mpeg));
video_config_cdc #(.WIDTH(8)) seek_file_echo_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(media_search_tag_mpeg),.dst_data(media_search_echo));
video_config_cdc #(.WIDTH(160)) seek_probe_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),
 .src_data({media_search_tag_mpeg,av_is_ps,media_movie_origin_valid,media_movie_origin,
            media_point_found,av_raw_end,media_point_pts,media_point_pack,media_point_sequence}),
 .dst_data(media_probe_response_sys));
media_seek_search media_seek_search(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),.request(media_seek_restart),
 .program_stream(media_probe_response_sys[151]),.origin_valid(media_probe_response_sys[150]),
 .origin(media_probe_response_sys[149:117]),.target_q(media_target_sys),.file_size(media_file_size),
 .reader_start(media_reader_start),.reader_position(media_byte_position),
 .response_tag(media_probe_response_sys[159:152]),.point_found(media_probe_response_sys[116]),
 .probe_end(media_probe_response_sys[115]),.point_pts(media_probe_response_sys[114:82]),
 .point_pack(media_probe_response_sys[81:41]),.point_sequence(media_probe_response_sys[40:0]),
 .busy(media_search_busy),.probing(media_probe_sys),.restart(media_search_restart),
 .tag(media_search_tag),.start_offset(media_start_offset),.video_start(media_video_start));
(* preserve, altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] media_osd_sync=0;
always @(posedge clk_sys) media_osd_sync<={media_osd_sync[1:0],OSD_STATUS};
media_keyboard_control #(.RESTART_BOTH_DIRECTIONS(1),.ENABLE_SEEK_GATE(1)) media_keyboard_control(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),.enabled(media_file_size!=0 && !media_duration_busy),
 .seek_enabled(!media_music_hint),.osd_open(media_osd_sync[2]),.key(ps2_key),.elapsed_q(media_elapsed_sys),
 .seek_done(media_seek_done_sys && !media_search_busy),.restart_complete(media_reader_start && !media_probe_sys),
 .paused(media_paused_sys),.seek_active(media_seek_sys),
 .seek_target_q(media_target_sys),.restart(media_seek_restart));
video_config_cdc #(.WIDTH(37)) playback_control_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data({media_paused_sys,media_seek_sys,media_target_sys}),.dst_data(media_control_mpeg));
video_config_cdc #(.WIDTH(36)) playback_position_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),
 .src_data({media_seek_done,media_elapsed_q}),.dst_data({media_seek_done_sys,media_elapsed_sys}));
always @(posedge clk_sys) begin
    media_mount_d<=media_img_mounted[0];media_user_reset_d<=media_user_reset;
    if(RESET) media_file_size<=0;
    else if(media_img_mounted[0]) media_file_size<=media_img_size;
    else if(media_eof_close) media_file_size<=0;
end
// Duration preflight owns the same reader until every accepted response drains.
wire media_duration_busy,media_duration_start,media_duration_cancel,media_duration_ready;
wire media_duration_valid;
wire [34:0] media_duration_q;
wire [63:0] media_duration_size,media_duration_offset;
media_duration_probe #(.ENABLE_FLAC(1)) media_duration_probe(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),.file_size(media_file_size),
 .reader_idle(media_reader_idle),.reader_error(media_error),
 .stream_data(media_stream_data),.stream_valid(media_stream_valid),.stream_ready(media_duration_ready),
 .busy(media_duration_busy),.reader_start(media_duration_start),.reader_cancel(media_duration_cancel),
 .read_size(media_duration_size),.read_offset(media_duration_offset),
 .duration_valid(media_duration_valid),.duration_q(media_duration_q),.origin(),.music_file(media_music_hint));
assign PLAYER_UI_CLOCK=clk_sys;
media_ui_state player_ui_state(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),
 .loaded(media_file_size!=0 && !media_duration_busy && !media_fifo_reset),
 .paused(media_paused_sys),.seeking(media_seek_sys),
 .elapsed_q(media_music_hint?media_music_elapsed:media_elapsed_sys),.target_q(media_target_sys),
 .duration_q(media_music_hint?media_music_duration:media_duration_q),.duration_valid(media_music_hint?(media_music_total_sys!=0):media_duration_valid),.scene_state(PLAYER_UI_STATE));
media_session_control #(.ENABLE_START_READY(1)) media_session_control (
 .clk_sys(clk_sys),.clk_mpeg2(clk_mpeg2),.reset(RESET),.restart(media_restart),
 .reader_idle(media_reader_idle),.ddr_idle(media_ddr_idle),
 .start_ready(media_search_echo==media_search_tag && !media_duration_busy),
 .reader_cancel(media_reader_cancel),.fifo_reset(media_fifo_reset),
 .reader_start(media_reader_start),.quiesce(media_quiesce),
 .decoder_reset(media_decoder_reset),.generation(media_generation)
);
media_file_reader media_file_reader (
 .clk(clk_sys),.reset(RESET),.start(media_duration_busy ? media_duration_start : (media_reader_start && media_file_size!=0)),
 .cancel(media_duration_busy ? media_duration_cancel : (media_reader_cancel || media_fatal_sys)),.suspend(1'b0),
 .file_size(media_duration_busy ? media_duration_size : media_file_size),
 .start_offset(media_duration_busy ? media_duration_offset : {23'd0,media_start_offset}),
 .sd_lba(media_sd_lba[0]),.sd_blk_cnt(media_sd_blocks[0]),.sd_rd(media_sd_rd[0]),
 .sd_ack(media_sd_ack[0]),.sd_buff_wr(media_reader_wr[0]),
 .sd_buff_addr(media_sd_addr),.sd_buff_dout(media_sd_data),
 .stream_data(media_stream_data),.stream_valid(media_stream_valid),
 .stream_ready(media_duration_busy ? media_duration_ready : (!mpeg2_stream_full && !media_fifo_reset)),.idle(media_reader_idle),
 .byte_position(media_byte_position),.requests(),
 .completions(),.max_wait(),.error(media_error)
);
always @(posedge clk_sys) begin
 if(media_fifo_reset) media_prefill<=0;
 else begin
  if(media_fifo_used>=4096 || (media_stream_valid && media_stream_data[8])) media_prefill<=1;
 end
end
video_config_cdc #(.WIDTH(1)) media_prefill_config (
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(media_prefill),.dst_data(media_prefill_mpeg));
video_config_cdc #(.WIDTH(1)) media_fatal_config (
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(mpeg2_new_transport_fatal_error),.dst_data(media_fatal_sys));
// Reader failure participates in seek termination; preserve that functional
// event without carrying the former 256-bit statistics snapshot.
video_config_cdc #(.WIDTH(1)) reader_error_config (
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data(|media_error),.dst_data(media_reader_error_mpeg));
wire        mpeg2_stream_full;
wire        mpeg2_stream_empty;
wire [7:0]  mpeg2_fifo_data;
wire [7:0]  mpeg2_stream_data;
wire        mpeg2_new_system_input_ready;
wire        mpeg2_new_system_input_valid;
wire        mpeg2_stream_rd;
wire        mpeg2_stream_wr;
wire        mpeg2_new_decode_stream_valid;
wire        mpeg2_new_stream_ready;
wire        mpeg2_new_decoder_stream_ready;
wire        mpeg2_new_b_presentation_hold;
wire        mpeg2_new_p_destination_ownership_hold;

media_sd_owner mounted_file_owner(.clk(clk_sys),.reset(RESET),.request(media_sd_rd),.ack(media_sd_ack),
 .buff_wr(media_sd_wr),.host_request(media_host_rd),.reader_wr(media_reader_wr));
wire[36:0] subtitle_elapsed_q;
wire subtitle_before_start,subtitle_retime;
media_subtitle_time subtitle_time(.clk(clk_sys),.reset(RESET||media_new_file),
 .elapsed_q(media_elapsed_sys),.offset_code(status[119:113]),.speed_code(status[112:106]),
 .subtitle_q(subtitle_elapsed_q),.before_start(subtitle_before_start),.restart(subtitle_retime));
media_subtitles subtitles(.clk(clk_sys),.reset(RESET),.new_movie(media_new_file),
 .mount(media_img_mounted[1]),.mount_size(media_img_size),
 .loaded(PLAYER_UI_STATE[74]),.seeking(media_seek_sys||subtitle_retime),.enabled(!status[120]&&!subtitle_before_start),
 .suspend(media_duration_busy || media_seek_sys || (media_fifo_occupancy<16'd8192 && !media_reader_idle)),
 .elapsed_q(subtitle_elapsed_q),.epoch(PLAYER_UI_STATE[90:75]),
 .sd_lba(media_sd_lba[1]),.sd_blocks(media_sd_blocks[1]),.sd_rd(media_sd_rd[1]),
 .sd_ack(media_sd_ack[1]),.sd_wr(media_reader_wr[1]),.sd_addr(media_sd_addr),.sd_data(media_sd_data),
 .command(PLAYER_SUBTITLE_COMMAND),.command_ack(PLAYER_SUBTITLE_ACK),.warning());

hps_io #(.CONF_STR(CONF_STR), .CONF_STR_BRAM(1), .WIDE(1), .VDNUM(2)) hps_io
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

    .img_mounted(media_img_mounted),.img_size(media_img_size),
    .sd_lba(media_sd_lba),.sd_blk_cnt(media_sd_blocks),
    .sd_rd(media_host_rd),.sd_wr(2'b0),.sd_ack(media_sd_ack),
    .sd_buff_addr(media_sd_addr),.sd_buff_dout(media_sd_data),
    .sd_buff_din(media_sd_unused),.sd_buff_wr(media_sd_wr),
    .ioctl_wait(1'b0)

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
// User reset restarts a session through the DDR-drain handshake.
wire reset_request = RESET;

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

wire reset_mpeg2 = reset_mpeg2_base || media_decoder_reset;

// The first scheduled frame starts playback. EOF closure follows the same
// reset/drain path as a fresh load and restores startup message behavior.
wire media_new_file_mpeg;
video_config_cdc #(.WIDTH(1)) playback_hide_reset_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(media_new_file_hold),.dst_data(media_new_file_mpeg));
reg media_new_file_hold=0;
always @(posedge clk_sys) begin
 if(RESET||media_new_file) media_new_file_hold<=1;
 else if(media_reader_start) media_new_file_hold<=0;
end
reg playback_started = 0;
always @(posedge clk_mpeg2) begin
    if (reset_mpeg2_base || media_new_file_mpeg) playback_started <= 0;
    else if (mpeg2_new_framebuffer_swap_reset_count != 0 || (media_music_mode && music_started)) playback_started <= 1;
end
video_config_cdc #(.WIDTH(1)) playback_osd_config (
 .src_clk(clk_mpeg2), .dst_clk(clk_sys),
 .src_data(playback_started), .dst_data(OSD_HIDE_MESSAGE)
);


// kate - Phase 1Ob: the streaming H.262 bitreader continues to own input
// backpressure while picture_data() advances across every slice of the first
// supported I-picture.  Slice boundaries remain inside the bitreader so no
// alignment or payload bytes are discarded.
// Before the first slice is selected, bytes flow continuously for start-code/header
// parsing.  During slice parsing the bitreader stalls this FIFO whenever its
// current payload byte has not been fully consumed, including IQ/IDCT waits.
assign mpeg2_stream_wr = !media_duration_busy && media_stream_valid && !mpeg2_stream_full && !media_fifo_reset;
assign mpeg2_fifo_data=media_fifo_data[7:0];
wire media_eof_at_head=!mpeg2_stream_empty && media_fifo_data[8];
wire media_data_read;
reg media_eof_seen=0;
always @(posedge clk_mpeg2) begin
    if(reset_mpeg2) media_eof_seen<=0;
    else if(media_prefill_mpeg && media_eof_at_head) media_eof_seen<=1;
end
assign mpeg2_stream_rd=!reset_mpeg2 && media_prefill_mpeg && (media_eof_at_head || (media_music_mode ? (!mpeg2_stream_empty && media_music_input_ready) : media_data_read));

// Phase 1V: the decoder owns syntax/persistence backpressure, while the top
// level additionally pauses between a persisted B and completion of its proven
// scratch->future-reference presentation transaction. This prevents a later
// P/B pair from overtaking the two-vblank display-order operation.
// kate - Commit 162 adds a second, P-only ownership pause after the following
// picture header has been consumed and classified.  It never blocks the header
// needed to distinguish a consecutive P from a following B.
assign mpeg2_new_stream_ready =
	!media_decoder_reset &&
	mpeg2_new_decoder_stream_ready &&
	!mpeg2_new_b_presentation_hold &&
	!mpeg2_new_p_destination_ownership_hold;

// EOF is an ordered FIFO token, never a gap between host sector requests.
wire mpeg2_new_system_input_end = media_eof_seen && !reset_mpeg2 && !media_music_mode;

wire [7:0] mpeg2_ingress_data;
wire mpeg2_ingress_valid, mpeg2_ingress_ready, mpeg2_ingress_end;
wire mpeg2_demux_error;

wire mpeg2_new_transport_fatal_error =
    mpeg2_demux_error || mp2_error ||
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
	.fifo_empty       (media_music_mode || mpeg2_stream_empty || media_eof_at_head || reset_mpeg2 || !media_prefill_mpeg),
	.decoder_ready    (mpeg2_new_system_input_ready),
	.fatal_error      (mpeg2_new_transport_fatal_error),
	.fifo_read        (media_data_read),
	.decoder_valid    (mpeg2_new_system_input_valid)
);

// Container parsing consumes the same ordered bytes from the new transport.
wire [7:0] av_video_byte, av_audio_byte;
wire av_video_valid,av_video_ready,av_ingress_end,av_is_ps;
wire [32:0] av_video_pts,av_audio_pts;
wire [7:0] av_raw_video,av_raw_audio;
wire av_raw_valid,av_raw_pts_valid,av_raw_audio_valid,av_raw_end,av_raw_error;
wire [32:0] av_raw_pts;
wire [40:0] av_file_position,av_pack_position;
wire av_discard_video=media_probe_mpeg || av_file_position<media_video_start_mpeg;
wire av_filter_ready;
wire av_raw_ready=av_discard_video || av_filter_ready;
reg av_gate_pts_valid=0;
reg [32:0] av_gate_pts=0;
always @(posedge clk_mpeg2) begin
 if(reset_mpeg2) av_gate_pts_valid<=0;
 else if(av_raw_valid && av_raw_ready) begin
  if(!av_discard_video) av_gate_pts_valid<=0;
  else if(av_raw_pts_valid) begin av_gate_pts_valid<=1;av_gate_pts<=av_raw_pts;end
 end
end
media_seek_video_filter media_seek_video_filter(
 .clk(clk_mpeg2),.reset(reset_mpeg2),.resync_start(media_video_start_mpeg!=0),
 .input_data({(av_raw_pts_valid || av_gate_pts_valid),
              (av_raw_pts_valid ? av_raw_pts : av_gate_pts),av_raw_video}),
 .input_valid(av_raw_valid && !av_discard_video),.input_end(av_raw_end && !media_probe_mpeg),
 .input_ready(av_filter_ready),.output_data({av_video_pts_valid,av_video_pts,av_video_byte}),
 .output_valid(av_video_valid),.output_end(av_ingress_end),.output_ready(av_video_ready));
assign av_audio_byte=av_raw_audio;
assign av_audio_valid=av_raw_audio_valid && !media_probe_mpeg;
assign mpeg2_demux_error=av_raw_error && !media_probe_mpeg;
media_seek_point media_seek_point(
 .clk(clk_mpeg2),.clear(reset_mpeg2_base || media_new_file_mpeg),.reset(reset_mpeg2),
 .data(av_raw_video),.valid(av_is_ps && av_raw_valid && av_raw_ready),
 .pts_valid(av_raw_pts_valid),.pts(av_raw_pts),
 .file_position(av_file_position),.pack_position(av_pack_position),
 .origin_valid(media_movie_origin_valid),.origin(media_movie_origin),
 .found(media_point_found),.point_pts(media_point_pts),
 .point_pack(media_point_pack),.point_sequence(media_point_sequence));
wire av_video_pts_valid,av_audio_pts_valid,av_audio_valid,av_audio_ready;
mpeg2_program_stream_ingress #(.ENABLE_AUDIO(1),.APPEND_RAW_END(1),.ENABLE_FILE_POSITION(1)) mpeg2_program_stream_ingress (
    .clk(clk_mpeg2), .reset(reset_mpeg2),
    .input_data(mpeg2_fifo_data), .input_valid(mpeg2_new_system_input_valid),
    .input_ready(mpeg2_new_system_input_ready), .input_end(mpeg2_new_system_input_end),
    .force_program_stream(media_start_offset_mpeg!=0),.start_file_position(media_start_offset_mpeg),
    .video_file_position(av_file_position),.video_pack_position(av_pack_position),
    .output_data(av_raw_video), .output_valid(av_raw_valid),
    .output_ready(av_raw_ready), .output_end(av_raw_end),
    .video_pts(av_raw_pts),.video_pts_valid(av_raw_pts_valid),
    .audio_data(av_raw_audio),.audio_valid(av_raw_audio_valid),.audio_ready(media_probe_mpeg || av_audio_ready),
    .audio_pts(av_audio_pts),.audio_pts_valid(av_audio_pts_valid),.is_program_stream(av_is_ps),
    .demux_error(av_raw_error)
);

`include "MediaPlayer_av.svh"

mpeg2_h262_inband_metadata mpeg2_h262_inband_metadata
(
	.clk                (clk_mpeg2),
	.reset              (reset_mpeg2),
	.input_data         (mpeg2_ingress_data),
	.input_valid        (mpeg2_ingress_valid),
	.input_ready        (mpeg2_ingress_ready),
	.input_end          (mpeg2_ingress_end),
	.stream_data        (mpeg2_stream_data),
	.stream_valid       (mpeg2_new_decode_stream_valid),
	.stream_ready       (mpeg2_new_stream_ready),
	.pts_90k            (mpeg2_new_inband_pts_90k),
	.picture_structure  (),
	.top_field_first    (),
	.repeat_first_field (),
	.progressive_frame  (),
	.metadata_valid     (mpeg2_new_inband_valid),
	.metadata_count     ()
);

mpeg2_stream_fifo mpeg2_stream_fifo
(
	// kate - DCFIFO owns reset-release synchronization for wr_clk and rd_clk.
	.reset    (media_fifo_reset),

	.wr_clk   (clk_sys),
	.wr_data  (media_stream_data),
	.wr_en    (mpeg2_stream_wr),
	.wr_full  (mpeg2_stream_full),
    .wr_used(media_fifo_used),

	.rd_clk   (clk_mpeg2),
	.rd_en    (mpeg2_stream_rd),
	.rd_data  (media_fifo_data),
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
assign DDRAM_ADDR=media_music_mode?music_mem_addr:movie_mem_addr;
assign DDRAM_DIN=media_music_mode?music_mem_data:movie_mem_data;
assign DDRAM_BE=media_music_mode?music_mem_be:movie_mem_be;
assign DDRAM_BURSTCNT=media_music_mode?8'd1:movie_mem_burst;
assign DDRAM_RD=media_music_mode?music_mem_read:movie_mem_read;
assign DDRAM_WE=media_music_mode?music_mem_write:movie_mem_write;
reg music_started=0;
always @(posedge clk_mpeg2)begin
 if(reset_mpeg2)music_started<=0;
 else if(media_music_mode&&!media_quiesce)music_started<=1;
end
flac_ddr_decoder music_decoder(.clk(clk_mpeg2),.reset(reset_mpeg2),.cancel(media_quiesce),
 .start(media_music_mode&&!media_quiesce&&!music_started),.start_ready(),.quiescent(media_music_idle),
 .input_data(media_fifo_data[7:0]),.input_valid(media_music_mode&&media_prefill_mpeg&&!mpeg2_stream_empty&&!media_eof_at_head),
 .input_end(media_eof_seen),.input_ready(media_music_input_ready),.metadata_valid(media_music_metadata),.total_samples(media_music_total),
 .pcm_valid(PLAYER_PCM_VALID),.pcm_ready(PLAYER_PCM_READY),.pcm_eof(PLAYER_PCM_DATA[32]),
 .pcm_left(PLAYER_PCM_DATA[31:16]),.pcm_right(PLAYER_PCM_DATA[15:0]),.error(media_music_decode_error),
 .mem_addr(music_mem_addr),.mem_data(music_mem_data),.mem_be(music_mem_be),.mem_read(music_mem_read),.mem_write(music_mem_write),
 .mem_busy(DDRAM_BUSY||!media_music_mode),.mem_q(DDRAM_DOUT),.mem_q_valid(DDRAM_DOUT_READY&&media_music_mode));

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
wire        display_pixel_en;
wire        display_h_sync;
wire        display_v_sync;

wire [7:0]  fb_video_r;
wire [7:0]  fb_video_g;
wire [7:0]  fb_video_b;
wire        fb_video_de;
wire        fb_video_hs;
wire        fb_video_vs;

// ---------------------------------------------------------------------------
// Audio-clock-derived 90 kHz ticks drive video presentation and EOF timing.
// The clock itself remains active; profiler-only whole-second reporting is gone.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] stc_audio_reset_sync;
always @(posedge CLK_AUDIO or posedge reset_mpeg2_base) begin
	if (reset_mpeg2_base) stc_audio_reset_sync <= 2'b11;
	else                  stc_audio_reset_sync <= {stc_audio_reset_sync[0],1'b0};
end
wire stc_audio_reset = stc_audio_reset_sync[1];

wire        stc_tick_90k_audio;

mpeg2_h262_system_time_clock mpeg2_h262_system_time_clock
(
	.clk           (CLK_AUDIO),
	.reset         (stc_audio_reset),
	.run           (!(media_paused_audio || media_seeking_audio)),
	.load_valid    (1'b0),
	.load_value    (33'd0),
	.stc_90k       (),
	.tick_90k      (stc_tick_90k_audio),
	.stc_180k_half (),
	.pulse_1hz     ()
);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] stc_tick_90k_sync;
wire mpeg2_new_stc_tick_90k=(stc_tick_90k_sync[2:1]==2'b01);
always @(posedge clk_mpeg2) begin
 if(reset_mpeg2) stc_tick_90k_sync<=0;
 else stc_tick_90k_sync<={stc_tick_90k_sync[1:0],stc_tick_90k_audio};
end
