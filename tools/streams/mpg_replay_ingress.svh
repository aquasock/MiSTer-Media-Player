// Real PS demux, codec queues, MP2 decoder/sink and video PTS scheduling.
// Host and PCM CDC queues are bounded behavioral models, not vendor CDC proof.
reg replay_sys_clk=0;always #25 replay_sys_clk=~replay_sys_clk;
reg replay_audio_clk=0;always #20.345052083333 replay_audio_clk=~replay_audio_clk;
reg replay_start=0,replay_ack=0,replay_wr=0;
reg [12:0] replay_addr=0;reg [15:0] replay_data=0;
wire [31:0] replay_lba;wire [5:0] replay_blocks;wire replay_rd;
wire [8:0] replay_byte;wire replay_valid;wire [3:0] replay_source_error;
reg [8:0] replay_reservoir[0:32767];integer replay_head=0,replay_tail=0;
reg replay_prefill=0,replay_end=0;
wire replay_ready;
media_file_reader replay_reader(.clk(replay_sys_clk),.reset(reset),.start(replay_start),
 .cancel(1'b0),.suspend(1'b0),.file_size({32'd0,stream_len[31:0]}),.start_offset(64'd0),
 .sd_lba(replay_lba),.sd_blk_cnt(replay_blocks),.sd_rd(replay_rd),.sd_ack(replay_ack),
 .sd_buff_wr(replay_wr),.sd_buff_addr(replay_addr),.sd_buff_dout(replay_data),
 .stream_data(replay_byte),.stream_valid(replay_valid),
 .stream_ready(replay_tail-replay_head<32768),.error(replay_source_error));
initial begin wait(!reset);@(negedge replay_sys_clk);replay_start=1;
 @(negedge replay_sys_clk);replay_start=0;end
always @(posedge replay_sys_clk) if(!reset&&replay_valid&&replay_tail-replay_head<32768) begin
 replay_reservoir[replay_tail%32768]<=replay_byte;replay_tail<=replay_tail+1;
 if(replay_tail-replay_head>=4095||replay_byte[8]) replay_prefill<=1;
end
wire replay_input_valid=!reset&&replay_prefill&&replay_head<replay_tail&&!replay_reservoir[replay_head%32768][8];
always @(posedge clk) if(!reset&&replay_prefill&&replay_head<replay_tail) begin
 if(replay_reservoir[replay_head%32768][8]) begin replay_end<=1;replay_head<=replay_head+1;end
 else if(replay_ready) replay_head<=replay_head+1;
end
integer replay_n,replay_base,replay_j,replay_requests=0,replay_stall=40000;
initial begin
 if($value$plusargs("HOST_STALL=%d",replay_stall))begin end
 forever begin
  wait(replay_rd);replay_n=(replay_blocks+1)*256;replay_base=replay_lba*512;replay_requests++;
  repeat(replay_requests%10==0?replay_stall:200)@(negedge replay_sys_clk);
  replay_ack=1;
  for(replay_j=0;replay_j<replay_n;replay_j++)begin
   @(negedge replay_sys_clk);replay_wr=0;@(negedge replay_sys_clk);replay_addr=replay_j;
   replay_data={replay_base+replay_j*2+1<stream_len?stream_mem[replay_base+replay_j*2+1]:8'd0,
                replay_base+replay_j*2<stream_len?stream_mem[replay_base+replay_j*2]:8'd0};replay_wr=1;
  end
  @(negedge replay_sys_clk);replay_wr=0;replay_ack=0;repeat(10)@(negedge replay_sys_clk);
 end
end
wire [7:0] rvb,rab;wire rvv,rvr,rve,rapv,rav,rar,rvpv,rps,rde;
wire [32:0] rvp,rap;
mpeg2_program_stream_ingress #(.ENABLE_AUDIO(1)) replay_demux(
 clk,reset,replay_reservoir[replay_head%32768][7:0],replay_input_valid,replay_ready,replay_end,
 rvb,rvv,rvr,rve,rvp,rvpv,rab,rav,rar,rap,rapv,rps,rde);
wire [41:0] raq;wire raqv,raqr,rae;wire [10:0] ra_level;
av_stream_fifo replay_audio_queue(clk,reset,{rapv,rap,rab},rav,rar,raq,raqv,raqr,rae,ra_level);
wire rpv,rpe,rpi;wire signed [15:0] rpl,rpr;wire [32:0] rpp;wire rppv;wire [31:0] rframes;
reg [66:0] replay_pcm[0:4095];integer replay_pcm_wr=0,replay_pcm_rd=0;
wire replay_pcm_ready=replay_pcm_wr-replay_pcm_rd<4096;
reg replay_pcm_eof=0;
wire replay_pop,replay_under,replay_terr,replay_finished;
wire signed [15:0] replay_l,replay_r;wire [31:0] replay_played;
reg replay_origin_valid=0;reg [32:0] replay_origin=0;
wire [32:0] replay_target=replay_origin+9000+playback_test.seek_elapsed;
wire replay_seek_audio;wire [32:0] replay_target_audio;
video_config_cdc #(.WIDTH(34)) replay_audio_control(.src_clk(clk),.dst_clk(replay_audio_clk),
 .src_data({seek_override,replay_target}),.dst_data({replay_seek_audio,replay_target_audio}));
mp2_decoder #(.ENABLE_SEEK_SKIP(1)) replay_mp2(
 .clk(clk),.reset(reset),.input_data(raq[7:0]),.input_valid(raqv),.input_ready(raqr),
 .input_end(rve&&rae),.input_pts(raq[40:8]),.input_pts_valid(raq[41]),
 .pcm_valid(rpv),.pcm_ready(replay_pcm_ready),.pcm_left(rpl),.pcm_right(rpr),.pcm_pts(rpp),
 .pcm_pts_valid(rppv),.error(rpe),.idle(rpi),.frames_decoded(rframes),
 .seek(seek_override&&!$test$plusargs("NO_AUDIO_BYPASS")),.seek_target(replay_target));
mp2_pcm_output #(.ENABLE_PLAYBACK_CONTROL(1)) replay_sink(
 replay_audio_clk,reset,1'b0,replay_seek_audio,replay_target_audio,replay_origin_valid,replay_origin,
 replay_pcm[replay_pcm_rd%4096],replay_pcm_wr==replay_pcm_rd,replay_pop,
 replay_l,replay_r,replay_under,replay_terr,replay_finished,replay_played);
always @(posedge clk) if(!reset)begin
 if(rpv&&replay_pcm_ready)begin replay_pcm[replay_pcm_wr%4096]<={1'b0,rppv,rpp,rpl,rpr};replay_pcm_wr++;end
 else if(rve&&rae&&rpi&&!replay_pcm_eof&&replay_pcm_ready)begin
  replay_pcm[replay_pcm_wr%4096]<=67'h40000000000000000;replay_pcm_wr++;replay_pcm_eof<=1;end
end
always @(posedge replay_audio_clk)if(!reset&&replay_pop)replay_pcm_rd++;
wire [42:0] rvq;wire rvqv,rvqr,rvready;
wire [28:0] raddr;wire [63:0] rdin;wire rrd,rwr;reg [63:0] rdq;reg rdqv=0;
reg [63:0] replay_vmem[0:1048575];wire [20:0] rv_level;
reg replay_veof=0;
assign rvr=rvready;
mpeg2_av_ddr_fifo replay_video_queue(clk,reset,{rve,rvpv,rvp,rvb},
 rvv||(rve&&!replay_veof),rvready,rvq,rvqv,rvqr,raddr,rdin,rrd,rwr,1'b0,rdq,rdqv,rv_level);
always @(posedge clk)begin
 rdqv<=0;
 if(!reset)begin
  if(rve&&rvready)replay_veof<=1;
  if(rwr)replay_vmem[raddr[19:0]]<=rdin;
  if(rrd)begin rdq<=replay_vmem[raddr[19:0]];rdqv<=1;end
 end
end
wire [7:0] reb;wire rev,rer,ree,rmv;wire [32:0] rmp;
mpeg2_pes_metadata_expand replay_expand(clk,reset,rvq,rvqv,rvqr,reb,rev,rer,ree);
mpeg2_h262_inband_metadata replay_metadata(.clk(clk),.reset(reset),.input_data(reb),
 .input_valid(rev),.input_ready(rer),.input_end(ree),.stream_data(stream_data),
 .stream_valid(stream_valid),.stream_ready(stream_ready),.metadata_valid(rmv),.pts_90k(rmp));
always @(posedge clk)if(!reset)begin
 if(stream_valid)stream_index<=stream_index+1;
 if(rmv&&!replay_origin_valid)begin replay_origin<=rmp-9000;replay_origin_valid<=1;end
 if(frontend.syntax_error)$fatal(1,"MPG_REPLAY_SYNTAX_ERROR source=%0d byte=%0d",frontend.syntax_error_source,stream_index);
 if(replay_source_error||rde||rpe)$fatal(1,"MPG_REPLAY_ERROR reader=%d demux=%d mp2=%d",replay_source_error,rde,rpe);
end
wire rbpv;wire [32:0] rbp;
mpeg2_pes_picture_pts replay_bind(clk,reset,stream_data,stream_valid,rmv,rmp,rbpv,rbp);
wire replay_display_valid,replay_candidate_valid,replay_candidate_scratch,replay_candidate_bank;
wire [1:0] replay_candidate_frame;wire [32:0] replay_display_pts,replay_candidate_pts;
wire replay_candidate_pts_valid,replay_timestamp_active,replay_timestamp_due;
mpeg2_h262_picture_timestamp replay_timestamp(.clk(clk),.reset(reset),.metadata_valid(rbpv),.metadata_pts(rbp),
 .picture_start(non_b_picture_start||b_picture_start),.picture_is_b(b_picture_start),
 .decode_scratch_bank(decode_scratch_bank),.b_picture_complete(b_success),.active_frame_bank(active_bank),
 .display_frame_bank(display_frame_bank),.display_scratch(display_scratch),.display_scratch_bank(display_scratch_bank),
 .candidate_frame_valid(replay_candidate_valid),.candidate_frame_scratch(replay_candidate_scratch),
 .candidate_scratch_bank(replay_candidate_bank),.candidate_frame_bank(replay_candidate_frame),
 .display_pts(replay_display_pts),.display_pts_valid(replay_display_valid),
 .candidate_pts(replay_candidate_pts),.candidate_pts_valid(replay_candidate_pts_valid));
// Production audio-derived STC pulse and its decoder-domain synchronizer.
wire replay_tick_audio;
reg [2:0] replay_tick_sync=0;
wire replay_tick=replay_tick_sync[2:1]==2'b01;
mpeg2_h262_system_time_clock replay_stc(.clk(replay_audio_clk),.reset(reset),
 .run(!replay_seek_audio),.load_valid(1'b0),.load_value(33'd0),.tick_90k(replay_tick_audio));
always @(posedge clk) if(reset)replay_tick_sync<=0;
 else replay_tick_sync<={replay_tick_sync[1:0],replay_tick_audio};
mpeg2_h262_pts_presentation_timeline #(.ENABLE_PLAYBACK_CONTROL(1)) replay_timeline(
 .clk(clk),.reset(reset),.tick_90k(replay_tick),.hold_time(seek_override),
 .rebase(playback_test.rebase),.rebase_pts(replay_target),.metadata_valid(rmv),.metadata_pts(rmp-33'd9000),
 .candidate_valid(replay_candidate_pts_valid),.candidate_pts(replay_candidate_pts),
 .candidate_active(replay_timestamp_active),.candidate_due(replay_timestamp_due));

reg [1:0] replay_audio_errors_q=0;
always @(posedge clk)if(!reset)begin
 replay_audio_errors_q<={replay_terr,replay_under};
 if(replay_audio_errors_q!={replay_terr,replay_under})
  $display("MPG_REPLAY_AUDIO_ERROR cycle=%0d seeking=%0d underrun=%0d timestamp=%0d video_ram=%0d audio_ram=%0d pcm=%0d target=%0d",total_cycles,seek_override,replay_under,replay_terr,rv_level,ra_level,replay_pcm_wr-replay_pcm_rd,replay_target);
end
