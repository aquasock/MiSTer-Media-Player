// Entry 688: simulation-only integration of the production in-band extractor,
// 64 KiB clean-video queue, 8192-frame audio FIFO and output adapter. Vendor
// FIFOs are behavioral models supplied by the runner, so this proves delivery
// order and capacity rather than FPGA clock-domain timing.
wire audio_metadata_valid;
wire [32:0] audio_metadata_pts;
wire audio_transport_complete;

generate if(AUDIO_TRANSPORT) begin: audio_transport
    reg audio_clk=0;
    always #20.345052083 audio_clk=~audio_clk;

    reg [7:0] transport_mem[0:MAX_STREAM_BYTES-1];
    integer transport_len=0,transport_index=0,host_stride=1;
    integer stop_cycles=0,trace_fd=0;
    integer written_frames=0,read_frames=0,starvation_intervals=0;
    integer max_audio_used=0;
    reg [1023:0] transport_path,audio_trace_path;
    wire transport_ready;
    wire transport_valid=(transport_index<transport_len)&&
        ((total_cycles%host_stride)==0);
    wire [7:0] transport_data=(transport_index<transport_len)?
        transport_mem[transport_index]:8'd0;
    wire transport_ended=transport_index==transport_len;
    wire [7:0] extracted_data,queued_data;
    wire extracted_valid,extracted_ready,metadata_valid,metadata_ready;
    wire [32:0] metadata_pts;
    wire queued_valid,pcm_valid,pcm_end,pcm_ready,pcm_stereo,pcm_rate;
    wire pcm_error,audio_full,audio_empty,audio_read,audio_underrun;
    wire [15:0] pcm_left,pcm_right,audio_left,audio_right;
    wire [12:0] audio_used,audio_read_used;
    wire [34:0] audio_data;
    reg playback_started=0;
    wire playback_complete;
    reg source_ended=0;
    reg [1:0] source_ended_sync=0;
    reg underrun_d=0;

    assign pcm_ready=!audio_full;
    assign stream_data=queued_data;
    assign stream_valid=queued_valid;
    assign audio_transport_complete=playback_complete;

    mpeg2_h262_inband_metadata extractor(
        .clk(clk),.reset(reset),.input_data(transport_data),
        .input_valid(transport_valid),.input_ready(transport_ready),
        .input_end(transport_ended),.stream_data(extracted_data),
        .stream_valid(extracted_valid),.stream_ready(extracted_ready),
        .pts_90k(metadata_pts),.metadata_valid(metadata_valid),
        .metadata_ready(metadata_ready),.pcm_left(pcm_left),
        .pcm_right(pcm_right),.pcm_stereo(pcm_stereo),
        .pcm_rate_48k(pcm_rate),.pcm_valid(pcm_valid),.pcm_end(pcm_end),
        .pcm_ready(pcm_ready),.pcm_protocol_error(pcm_error));
    mpeg2_h262_clean_video_queue clean_queue(
        .clk(clk),.reset(reset),.input_data(extracted_data),
        .input_valid(extracted_valid),.input_ready(extracted_ready),
        .input_metadata_pts(metadata_pts),
        .input_metadata_valid(metadata_valid),
        .input_metadata_ready(metadata_ready),.output_data(queued_data),
        .output_valid(queued_valid),.output_ready(stream_ready),
        .output_metadata_pts(audio_metadata_pts),
        .output_metadata_valid(audio_metadata_valid));
    audio_pcm_fifo audio_fifo(
        .reset(reset),.wr_clk(clk),
        .wr_data({pcm_end,pcm_rate,pcm_stereo,pcm_left,pcm_right}),
        .wr_en((pcm_valid||pcm_end)&&pcm_ready),.wr_full(audio_full),
        .wr_used(audio_used),.rd_clk(audio_clk),.rd_en(audio_read),
        .rd_data(audio_data),.rd_empty(audio_empty),.rd_used(audio_read_used));
    audio_pcm_output_adapter audio_adapter(
        .clk(audio_clk),.reset(reset),.fifo_data(audio_data),
        .fifo_empty(audio_empty),.fifo_used(audio_read_used),
        .source_ended(source_ended_sync[1]),.fifo_rd(audio_read),
        .audio_l(audio_left),.audio_r(audio_right),
        .underrun(audio_underrun),.playback_complete(playback_complete));

    wire [31:0] clean_used_debug=
        clean_queue.video_write_position-clean_queue.video_read_position;
    wire [3:0] extractor_state_debug=extractor.state;

    task trace_audio(input string event_name);
        $fdisplay(trace_fd,
            "%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
            total_cycles,event_name,stream_index,transport_index,
            written_frames,read_frames,audio_used,clean_used_debug,
            decoder_ready,presentation_hold,destination_ownership_hold,
            transport_ready,extractor_state_debug,playback_started,
            audio_underrun,pcm_error);
    endtask

    initial begin
        if(!$value$plusargs("TRANSPORT=%s",transport_path)||
           !$value$plusargs("TRANSPORT_LEN=%d",transport_len)||
           !$value$plusargs("AUDIO_TRACE=%s",audio_trace_path))
            $fatal(1,"audio transport arguments required");
        if(transport_len<1||transport_len>MAX_STREAM_BYTES)
            $fatal(1,"audio transport bounds");
        void'($value$plusargs("HOST_STRIDE=%d",host_stride));
        void'($value$plusargs("AUDIO_STOP_CYCLES=%d",stop_cycles));
        if(host_stride<1)$fatal(1,"invalid host stride");
        $readmemh(transport_path,transport_mem,0,transport_len-1);
        trace_fd=$fopen(audio_trace_path,"w");
        if(!trace_fd)$fatal(1,"audio trace open");
        $fdisplay(trace_fd,
            "cycle,event,video_byte,transport_byte,audio_written,audio_read,audio_used,clean_used,decoder_ready,presentation_hold,destination_hold,input_ready,extractor_state,started,underrun,pcm_error");
    end

    always @(posedge clk) if(!reset) begin
        if(transport_valid&&transport_ready)
            transport_index<=transport_index+1;
        if(queued_valid&&stream_ready)begin
            if(stream_index>=stream_len||queued_data!==stream_mem[stream_index])
                $fatal(1,"clean-video byte mismatch at %0d",stream_index);
            stream_index<=stream_index+1;
        end
        if((pcm_valid||pcm_end)&&pcm_ready)begin
            if(pcm_end)source_ended<=1;
            else written_frames<=written_frames+1;
        end
        if(audio_used>max_audio_used)max_audio_used<=audio_used;
        if(pcm_error)$fatal(1,"PCM protocol fault");
        if(progress_interval!=0&&(total_cycles%progress_interval)==0)
            trace_audio("SAMPLE");
        if(stop_cycles>0&&total_cycles>=stop_cycles)begin
            if(audio_underrun||starvation_intervals!=0||pcm_error)
                $fatal(1,"audio prefix did not remain continuous");
            trace_audio("STOP");
            $display("AUDIO_PREFIX_PASS cycle=%0d video=%0d transport=%0d starvation_intervals=%0d writes=%0d reads=%0d max_used=%0d",
                total_cycles,stream_index,transport_index,starvation_intervals,
                written_frames,read_frames,max_audio_used);
            $finish;
        end
    end

    always @(posedge audio_clk) begin
        if(reset)source_ended_sync<=0;
        else source_ended_sync<={source_ended_sync[0],source_ended};
        if(!reset)begin
            if(audio_read&&!audio_empty&&!audio_data[34])begin
                read_frames<=read_frames+1;
                if(!playback_started)begin
                    playback_started<=1;
                    trace_audio("START");$fflush(trace_fd);
                end
            end
            if(audio_underrun&&!underrun_d)begin
                starvation_intervals<=starvation_intervals+1;
                trace_audio("UNDERRUN");$fflush(trace_fd);
            end
            if(audio_underrun)$fatal(1,"audio FIFO underrun");
            underrun_d<=audio_underrun;
        end
    end

    final begin
        trace_audio("END");
        $display("AUDIO_TRANSPORT_RESULT complete=%0d starvation_intervals=%0d underrun=%0d protocol_error=%0d written=%0d read=%0d max_used=%0d",
            playback_complete,starvation_intervals,audio_underrun,pcm_error,
            written_frames,read_frames,max_audio_used);
        $fclose(trace_fd);
    end
end else begin: no_audio_transport
    assign audio_metadata_valid=0;
    assign audio_metadata_pts=0;
    assign audio_transport_complete=1;
end endgenerate
