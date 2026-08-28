// Isolated diagnostic: real extractor, clean queue and audio adapter;
// behavioral vendor FIFOs and ideal source, not a hardware timing model.
wire audio_metadata_valid;
wire [32:0] audio_metadata_pts;
generate if (AUDIO_TRANSPORT) begin: audio_transport
    reg aclk=0;
    always #20.345052083 aclk=~aclk;
    reg [7:0] transport_mem[0:MAX_STREAM_BYTES-1];
    integer transport_len=0,transport_index=0,host_stride=1,stop_cycles=180000000;
    integer trace_fd=0,write_samples=0,read_samples=0,starve_intervals=0;
    reg [1023:0] transport_path,audio_trace_path;
    wire input_ready,input_valid;
    wire [7:0] extracted_data,queued_data;
    wire extracted_valid,extracted_ready,metadata_valid,metadata_ready;
    wire [32:0] metadata_pts;
    wire queued_valid,pcm_valid,pcm_end,pcm_ready,pcm_stereo,pcm_rate,pcm_error;
    wire [15:0] pcm_l,pcm_r,out_l,out_r;
    wire full,empty,rd,underrun,complete;
    wire [12:0] used,read_used;
    wire [34:0] fifo_data;
    reg ended=0;
    reg [1:0] ended_sync=0;
    reg starvation_d=0,underrun_d=0,started_d=0;
    assign input_valid=transport_index<transport_len&&input_ready&&(total_cycles%host_stride==0);
    assign pcm_ready=!full;
    mpeg2_h262_inband_metadata extractor(
      .clk(clk),.reset(reset),.input_data(transport_mem[transport_index]),
      .input_valid(input_valid),.input_ready(input_ready),.input_end(transport_index==transport_len),
      .stream_data(extracted_data),.stream_valid(extracted_valid),.stream_ready(extracted_ready),
      .pts_90k(metadata_pts),.metadata_valid(metadata_valid),.metadata_ready(metadata_ready),
      .pcm_left(pcm_l),.pcm_right(pcm_r),.pcm_stereo(pcm_stereo),.pcm_rate_48k(pcm_rate),
      .pcm_valid(pcm_valid),.pcm_end(pcm_end),.pcm_ready(pcm_ready),.pcm_protocol_error(pcm_error));
    mpeg2_h262_clean_video_queue clean_queue(
      .clk(clk),.reset(reset),.input_data(extracted_data),.input_valid(extracted_valid),
      .input_ready(extracted_ready),.input_metadata_pts(metadata_pts),
      .input_metadata_valid(metadata_valid),.input_metadata_ready(metadata_ready),
      .output_data(queued_data),.output_valid(queued_valid),.output_ready(stream_ready),
      .output_metadata_pts(audio_metadata_pts),.output_metadata_valid(audio_metadata_valid));
    audio_pcm_fifo fifo(.reset(reset),.wr_clk(clk),.wr_data({pcm_end,pcm_rate,pcm_stereo,pcm_l,pcm_r}),
      .wr_en((pcm_valid||pcm_end)&&pcm_ready),.wr_full(full),.wr_used(used),
      .rd_clk(aclk),.rd_en(rd),.rd_data(fifo_data),.rd_empty(empty),.rd_used(read_used));
    audio_pcm_output_adapter adapter(.clk(aclk),.reset(reset),.fifo_data(fifo_data),
      .fifo_empty(empty),.fifo_used(read_used),.source_ended(ended_sync[1]),.fifo_rd(rd),
      .audio_l(out_l),.audio_r(out_r),.underrun(underrun),.playback_complete(complete));
    assign stream_data=queued_data;
    assign stream_valid=queued_valid;
    wire [31:0] clean_used_debug=clean_queue.video_write_position-clean_queue.video_read_position;
    wire [3:0] extractor_state_debug=extractor.state;
    wire started_debug=adapter.started;
    task log_audio(input string event_name);
      $fdisplay(trace_fd,"%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
        total_cycles,event_name,stream_index,transport_index,write_samples,read_samples,
        used,clean_used_debug,
        decoder_ready,presentation_hold,destination_ownership_hold,
        input_ready,extractor_state_debug,started_debug,underrun,pcm_error);
    endtask
    initial begin
      if(!$value$plusargs("TRANSPORT=%s",transport_path)||
         !$value$plusargs("TRANSPORT_LEN=%d",transport_len)||
         !$value$plusargs("AUDIO_TRACE=%s",audio_trace_path))$fatal(1,"audio transport args");
      if(transport_len<1||transport_len>MAX_STREAM_BYTES)$fatal(1,"transport bounds");
      if($value$plusargs("HOST_STRIDE=%d",host_stride))begin end
      if($value$plusargs("AUDIO_STOP_CYCLES=%d",stop_cycles))begin end
      if(host_stride<1)$fatal(1,"invalid stride");
      $readmemh(transport_path,transport_mem,0,transport_len-1);
      trace_fd=$fopen(audio_trace_path,"w");if(!trace_fd)$fatal(1,"audio trace open");
      $fdisplay(trace_fd,"cycle,event,video_byte,transport_byte,audio_written,audio_read,audio_used,clean_used,decoder_ready,presentation_hold,destination_hold,input_ready,extractor_state,started,underrun,pcm_error");
    end
    always @(posedge clk) if(!reset) begin
      if(input_valid)transport_index<=transport_index+1;
      if(queued_valid)begin
        if(stream_index>=stream_len||queued_data!==stream_mem[stream_index])$fatal(1,"clean-byte mismatch");
        stream_index<=stream_index+1;
      end
      if((pcm_valid||pcm_end)&&pcm_ready)begin
        if(pcm_end)ended<=1;else write_samples<=write_samples+1;
      end
      if(pcm_error)$fatal(1,"PCM protocol fault");
      if(total_cycles%60000==0)log_audio("SAMPLE");
      if(total_cycles>=stop_cycles)begin
        log_audio("STOP");$display("AUDIO_PREFIX_RESULT cycle=%0d video=%0d transport=%0d underrun=%0d starvation_intervals=%0d writes=%0d reads=%0d",total_cycles,stream_index,transport_index,underrun,starve_intervals,write_samples,read_samples);$finish;
      end
    end
    always @(posedge aclk) begin
      if(reset)ended_sync<=0;else ended_sync<={ended_sync[0],ended};
      if(!reset)begin
        if(rd&&!empty&&!fifo_data[34])read_samples<=read_samples+1;
        if(adapter.started&&!started_d)begin log_audio("START");$fflush(trace_fd);end
        if(adapter.starvation_waiting&&!starvation_d)begin
          starve_intervals<=starve_intervals+1;log_audio("EMPTY");$fflush(trace_fd);
        end
        if(!adapter.starvation_waiting&&starvation_d)begin log_audio("REFILL");$fflush(trace_fd);end
        if(underrun&&!underrun_d)begin log_audio("UNDERRUN");$fflush(trace_fd);end
        started_d<=adapter.started;starvation_d<=adapter.starvation_waiting;underrun_d<=underrun;
      end
    end
    final $fclose(trace_fd);
end else begin
    assign audio_metadata_valid=0;assign audio_metadata_pts=0;
end endgenerate
