
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
// additional DDR client at mpeg2_h262_ddram_arbiter in MediaPlayer_top_framebuffer.svh
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
flac_ddr_decoder #(.ENABLE_RESUME(1)) music_decoder(
 .resume_frame(album_config[140]),.resume_total(album_config[139:104]),.resume_min_block(album_config[103:88]),
 .resume_max_block(album_config[87:72]),.resume_sample(album_config[71:36]),.clk(clk_mpeg2),.reset(reset_mpeg2),.cancel(media_quiesce),
 .start(media_music_mode&&!media_quiesce&&!music_started),.start_ready(),.quiescent(media_music_idle),
 .input_data(media_fifo_data[7:0]),.input_valid(media_music_mode&&media_prefill_mpeg&&!mpeg2_stream_empty&&!media_eof_at_head),
 .input_end(media_eof_seen),.input_ready(media_music_input_ready),.metadata_valid(media_music_metadata),.total_samples(media_music_total),
 .pcm_valid(music_raw_valid),.pcm_ready(music_raw_ready),.pcm_eof(music_raw_eof),
 .pcm_left(music_raw_pcm[31:16]),.pcm_right(music_raw_pcm[15:0]),.error(media_music_decode_error),
 .mem_addr(music_mem_addr),.mem_data(music_mem_data),.mem_be(music_mem_be),.mem_read(music_mem_read),.mem_write(music_mem_write),
 .mem_busy(DDRAM_BUSY||!media_music_mode),.mem_q(DDRAM_DOUT),.mem_q_valid(DDRAM_DOUT_READY&&media_music_mode));

