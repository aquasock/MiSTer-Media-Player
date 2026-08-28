// Entry 669: simulation-only integration for tb_h262_live_raster_soak.
// No production path is overridden. Sparse PTS are inserted at their exact
// clean-stream byte offsets; host transport/PCM are intentionally outside this
// first isolation boundary. Display requests share the real DDR arbiter.
wire native_writer_accepted;
wire native_use_intra=NATIVE_PRESENTATION&&!pred_store_select;
wire [7:0] native_reader_burst;
wire [28:0] native_reader_addr;
wire native_reader_rd,native_reader_busy,native_reader_valid,native_memory_busy;
wire native_film_mode,native_field,native_picture_present,native_display_rff;
wire native_candidate_tff,native_pts_active,native_pts_due,native_active;
wire native_swap,native_cadence,native_metadata_pending;
wire native_candidate_valid,native_candidate_scratch,native_candidate_sb;
wire [1:0] native_candidate_bank;
wire native_candidate_ready,native_cadence_slot;
wire [31:0] native_scheduler_state;
wire native_header_now=stream_valid&&picture_header_capture&&picture_header_second_byte;

generate if(NATIVE_PRESENTATION) begin: native_presentation
    reg video_clk=0;
    always #9.259259 video_clk=~video_clk;
    wire active_video,field_video,ce,pixel_en,hs,vs,field_window,field_swap,frame_window;
    wire [11:0] hpos,vpos;
    wire film,locked,first_tff,mismatch;
    wire request=(phase1_supported||(film&&frontend.native_film_supported))&&
        !frontend.progressive_sequence&&locked&&!mismatch;
    mpeg2_h262_native_field_order field_order(
        .clk(clk),.reset(reset),
        .picture_coding_extension_valid(frontend.picture_coding_extension_valid),
        .progressive_sequence(frontend.progressive_sequence),
        .picture_top_field_first(frontend.picture_coding_extension_top_field_first),
        .picture_progressive_frame(frontend.picture_coding_extension_progressive_frame),
        .film_mode(film),.locked(locked),.top_field_first(first_tff),.mismatch(mismatch));
    mpeg2_video_output_timing timing(
        .clk(video_clk),.reset(reset),.native_request_async(request),
        .top_field_first_async(first_tff),.native_active(active_video),
        .ce_pixel(ce),.h_pos(hpos),.v_pos(vpos),.pixel_en(pixel_en),
        .h_sync(hs),.v_sync(vs),.field(field_video),.field_window(field_window),
        .field_swap_window(field_swap),.frame_window(frame_window));
    reg [1:0] film_video=0;
    reg swap_video=0,cadence_video=0;
    reg [2:0] active_sync=0,field_sync=0,swap_sync=0,cadence_sync=0,present_sync=0;
    always @(posedge video_clk) begin
        if(reset)begin film_video<=0;swap_video<=0;cadence_video<=0;end
        else begin
            film_video<={film_video[0],film};
            swap_video<=film_video[1]?field_swap:frame_window;
            cadence_video<=field_window;
        end
    end
    wire present_video;
    always @(posedge clk)begin
        if(reset)begin active_sync<=0;field_sync<=0;swap_sync<=0;cadence_sync<=0;present_sync<=0;end
        else begin
            active_sync<={active_sync[1:0],active_video};
            field_sync<={field_sync[1:0],field_video};
            swap_sync<={swap_sync[1:0],swap_video};
            cadence_sync<={cadence_sync[1:0],cadence_video};
            present_sync<={present_sync[1:0],present_video};
        end
    end
    assign native_active=active_sync[2];
    assign native_film_mode=film&&native_active;
    assign native_field=field_sync[2];
    assign native_cadence=cadence_sync[1]&&!cadence_sync[2];
    assign native_picture_present=present_sync[2];

    // The manifest stores {clean byte offset[31:0], PTS[32:0]}.
    reg [64:0] pts_records[0:1023];
    integer pts_count=0,pts_index=0;
    reg [1023:0] pts_path,trace_path;
    integer trace_fd=0;
    assign native_metadata_pending=(pts_index<pts_count)&&
        (stream_index>=pts_records[pts_index][64:33]);
    wire [32:0] metadata_pts=pts_records[pts_index][32:0];
    reg tick90=0;
    integer tick_phase=0;
    always @(posedge clk)begin
        if(reset)begin pts_index<=0;tick90<=0;tick_phase<=0;end
        else begin
            if(native_metadata_pending)pts_index<=pts_index+1;
            tick90<=tick_phase+3>=2000;
            tick_phase<=(tick_phase+3>=2000)?tick_phase+3-2000:tick_phase+3;
        end
    end
    wire [32:0] display_pts,candidate_pts,stc;
    wire display_pts_valid,display_tff,display_progressive,descriptor_valid;
    wire candidate_pts_valid,anchored;
    wire [7:0] associated;
    mpeg2_h262_picture_timestamp metadata_owner(
        .clk(clk),.reset(reset),.metadata_valid(native_metadata_pending),.metadata_pts(metadata_pts),
        .picture_coding_extension_valid(frontend.picture_coding_extension_valid),
        .picture_top_field_first(frontend.picture_coding_extension_top_field_first),
        .picture_repeat_first_field(frontend.picture_coding_extension_repeat_first_field),
        .picture_progressive_frame(frontend.picture_coding_extension_progressive_frame),
        .picture_start(native_header_now),.picture_is_b(native_header_now&&stream_data[5:3]==3),
        .decode_scratch_bank(decode_scratch_bank),.b_picture_complete(b_success),
        .active_frame_bank(active_bank),.display_frame_bank(display_frame_bank),
        .display_scratch(display_scratch),.display_scratch_bank(display_scratch_bank),
        .candidate_frame_valid(native_candidate_valid),.candidate_frame_scratch(native_candidate_scratch),
        .candidate_scratch_bank(native_candidate_sb),.candidate_frame_bank(native_candidate_bank),
        .display_pts(display_pts),.display_pts_valid(display_pts_valid),
        .display_top_field_first(display_tff),.display_repeat_first_field(native_display_rff),
        .display_progressive_frame(display_progressive),.display_descriptor_valid(descriptor_valid),
        .candidate_top_field_first(native_candidate_tff),.candidate_pts(candidate_pts),
        .candidate_pts_valid(candidate_pts_valid),.associated_count(associated));
    mpeg2_h262_pts_presentation_timeline timeline(
        .clk(clk),.reset(reset),.tick_90k(tick90),
        .metadata_valid(native_metadata_pending),.metadata_pts(metadata_pts),
        .candidate_valid(candidate_pts_valid),.candidate_pts(candidate_pts),
        .anchored(anchored),.stc_90k(stc),.candidate_active(native_pts_active),.candidate_due(native_pts_due));
    reg first_complete=0;
    always @(posedge clk)if(reset)first_complete<=0;else if(picture_complete)first_complete<=1;
    wire swaps_enabled,video_blank;
    mpeg2_h262_native_startup startup(
        .clk_mpeg2(clk),.reset_mpeg2(reset),.clk_video(video_clk),.reset_video(reset),
        .native_request(request),.frame_rate_code(frontend.frame_rate_code),
        .first_picture_complete(first_complete),.candidate_presentable(native_candidate_ready),
        .sequence_end_seen(sequence_end_seen),
        .bypass_event(native_metadata_pending||(native_header_now&&stream_data[5:3]!=1)||frontend.syntax_error||probe_error),
        .frame_window(frame_window),.swap_window_active(swap_sync[2]),
        .swaps_enabled(swaps_enabled),.video_blank(video_blank));
    assign native_swap=swap_sync[1]&&!swap_sync[2]&&swaps_enabled;

    wire generation_reset=(framebuffer_swap_reset_count!=0)||(active_sync[1]^active_sync[2]);
    wire cache_reset=reset||generation_reset;
    reg generation_reset_d=0;
    reg [7:0] generation=0;
    always @(posedge clk)begin
        if(reset)begin generation_reset_d<=0;generation<=0;end
        else begin
            generation_reset_d<=generation_reset;
            if(generation_reset&&!generation_reset_d)generation<=generation+1'b1;
        end
    end
    wire [28:0] reader_unbanked;
    wire [28:0] display_offset=display_scratch?
        (display_scratch_bank?29'h30000:29'h20000):{10'd0,reference_frame_offset(display_frame_bank)};
    assign native_reader_addr=reader_unbanked+display_offset;
    wire cache_ready,cache_error,overlap_error,prefill_miss,phase_error;
    mpeg2_luma_framebuffer framebuffer(
        .reset(cache_reset),.mem_clk(clk),.picture_complete(first_complete&&descriptor_valid),
        .horizontal_size(horizontal_size),.vertical_size(vertical_size),
        .native_interlaced(native_active),.top_field_first(display_tff),
        .progressive_chroma(display_progressive),.framebuffer_generation(generation),
        .write_read_expected_region(display_offset[18:16]),.write_read_expected_valid(1'b0),
        .write_read_expected_even_fingerprint(32'd0),.write_read_expected_odd_fingerprint(32'd0),
        .ddram_busy(native_reader_busy),.ddram_dout(memory_dout),.ddram_dout_ready(native_reader_valid),
        .ddram_burstcnt(native_reader_burst),.ddram_addr(reader_unbanked),.ddram_rd(native_reader_rd),
        .cache_ready(cache_ready),.cache_error(cache_error),.bank_overlap_error(overlap_error),
        .picture_present_debug(present_video),.prefill_deadline_missed_debug(prefill_miss),
        .sequence_phase_error_debug(phase_error),
        .rd_clk(video_clk),.h_pos(hpos),.v_pos(vpos),.pixel_ce(ce),.pixel_en(pixel_en),.h_sync(hs),.v_sync(vs));

    // Ordered full-burst response model: one 64-bit word per decoder cycle,
    // configurable command latency and deterministic busy intervals. These
    // are controlled sensitivity cases, not measured MiSTer DDR timings.
    integer response_head=0,response_tail=0,response_count=0,last_due=0;
    integer response_due[0:2047];
    integer response_address[0:2047];
    integer word_index,due_cycle,busy_phase=0;
    assign native_memory_busy=(response_count>1792)||
        ((MEMORY_BUSY_PERIOD>0)&&(busy_phase<MEMORY_BUSY_CYCLES));
    always @(posedge clk)begin
        memory_dout_ready<=0;
        if(reset)begin
            response_head=0;response_tail=0;response_count=0;last_due=0;busy_phase=0;
        end else begin
            if(MEMORY_BUSY_PERIOD>0)
                busy_phase<=(busy_phase+1>=MEMORY_BUSY_PERIOD)?0:busy_phase+1;
            if(response_count>0&&response_due[response_head]<=total_cycles)begin
                memory_dout<=ddr_mem[response_address[response_head]];
                memory_dout_ready<=1;
                response_head=(response_head+1)%2048;response_count=response_count-1;
            end
            if(memory_rd&&!native_memory_busy)begin
                memory_reads<=memory_reads+1;
                if(memory_burstcnt==0||memory_addr<DDR_BASE||
                   memory_addr-DDR_BASE+memory_burstcnt>DDR_WORDS)$fatal(1,"native DDR read bounds");
                for(word_index=0;word_index<memory_burstcnt;word_index=word_index+1)begin
                    due_cycle=total_cycles+MEMORY_READ_LATENCY;
                    if(due_cycle<=last_due)due_cycle=last_due+1;
                    response_due[response_tail]=due_cycle;
                    response_address[response_tail]=memory_addr-DDR_BASE+word_index;
                    response_tail=(response_tail+1)%2048;response_count=response_count+1;last_due=due_cycle;
                end
                if(response_count>2048)$fatal(1,"native DDR response overflow");
            end
        end
    end

    integer publications=0,field_number=0;
    integer decoder_wait=0,presentation_wait=0,destination_wait=0,writer_wait=0;
    reg present_d=0;
    wire [31:0] selected_id=display_scratch?
        picture_trace_scratch_id[display_scratch_bank]:picture_trace_reference_id[display_frame_bank];
    wire [31:0] candidate_id=native_candidate_scratch?
        picture_trace_scratch_id[native_candidate_sb]:picture_trace_reference_id[native_candidate_bank];
    task trace_event(input string event_name,input integer id);
        $fdisplay(trace_fd,"%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
            total_cycles,event_name,id,field_number,stream_index,selected_id,candidate_id,
            native_candidate_ready,native_cadence_slot,native_pts_active,native_pts_due,
            stc,display_pts,display_pts_valid,display_tff,native_display_rff,
            native_picture_present,generation,decoder_wait,presentation_wait,destination_wait,writer_wait,
            native_scheduler_state,decoder_ready,cache_ready,prefill_miss,phase_error,overlap_error,
            display_progressive,descriptor_valid,active_bank,display_frame_bank,
            scheduler.pending_frame_bank,scheduler.ordinary_secondary_valid,
            scheduler.ordinary_secondary_bank,scheduler.ordinary_reference_decode_open);
    endtask
    initial begin
        if(!$value$plusargs("PTS=%s",pts_path)||!$value$plusargs("PTS_COUNT=%d",pts_count)||
           !$value$plusargs("NATIVE_TRACE=%s",trace_path))$fatal(1,"native PTS/trace arguments required");
        if(pts_count<1||pts_count>1024)$fatal(1,"PTS count bounds");
        $readmemh(pts_path,pts_records,0,pts_count-1);
        trace_fd=$fopen(trace_path,"w");if(!trace_fd)$fatal(1,"native trace open");
        $fdisplay(trace_fd,"cycle,event,id,field,byte,selected_id,candidate_id,candidate_ready,cadence_slot,pts_active,pts_due,stc,display_pts,display_pts_valid,tff,rff,present,generation,decoder_wait,presentation_wait,destination_wait,writer_wait,state,decoder_ready,cache_ready,prefill_miss,phase_error,overlap_error,progressive,descriptor_valid,active_bank,display_bank,pending_bank,secondary_valid,secondary_bank,ordinary_decode_open");
        $display("NATIVE_MODEL decoder_hz=60000000 video_hz=54000000 latency=%0d busy_period=%0d busy_cycles=%0d",MEMORY_READ_LATENCY,MEMORY_BUSY_PERIOD,MEMORY_BUSY_CYCLES);
    end
    always @(posedge clk)if(!reset)begin
        if(native_header_now&&metadata_owner.current_owned&&
           metadata_owner.retiring_owned&&!metadata_owner.picture_committed)
            $fatal(1,"native metadata retirement capacity exceeded");
        if(native_header_now&&stream_data[5:3]!=3&&
           scheduler.reference_headers_inflight==2&&!scheduler.reference_completed)
            $fatal(1,"native reference header retirement capacity exceeded");
        if(stream_index<stream_len&&!decoder_ready)decoder_wait<=decoder_wait+1;
        if(presentation_hold)presentation_wait<=presentation_wait+1;
        if(destination_ownership_hold)destination_wait<=destination_wait+1;
        if(writer_we&&writer_busy)writer_wait<=writer_wait+1;
        present_d<=native_picture_present;
        if(native_metadata_pending)trace_event("PTS",pts_index);
        if(native_header_now)trace_event("START",picture_trace_next_id);
        if(picture_complete||(pred_persisted&&!pred_persisted_d&&publication.b_picture_inflight))
            trace_event("READY",picture_trace_ready_id);
        if(generation_reset&&!generation_reset_d)trace_event("SELECT",selected_id);
        if(native_picture_present&&!present_d)begin
            publications<=publications+1;trace_event("PUBLISH",selected_id);
        end
        if(native_swap)begin
            field_number<=field_number+1;trace_event("FIELD",selected_id);$fflush(trace_fd);
        end
        if(prediction_no_progress_cycles==10000)begin
            trace_event("WAIT",coded_picture);$fflush(trace_fd);
            $display("NATIVE_WAIT cycle=%0d coded=%0d type=%0d byte=%0d ready=%0d phold=%0d dhold=%0d writer=%0d/%0d/%0d reader_region=%0d active_bank=%0d p_parse=%0d p_replay=%0d p_row=%0d b_parse=%0d b_replay=%0d b_row=%0d pred=%0d/%0d",
                total_cycles,coded_picture,picture_coding_type,stream_index,decoder_ready,
                presentation_hold,destination_ownership_hold,writer.writing,writer_we,writer_busy,
                arbiter.reader_frame_region,active_bank,
                publication.p_controller.wide_general_probe.parse_active,
                publication.p_controller.mixed_replay_active,
                publication.p_controller.wide_general_probe.row_waiting,
                publication.b_controller.parse_active,publication.b_controller.replay_active,
                publication.b_controller.row_waiting,prediction.mixed_active,prediction.b_active);
            $fflush;
        end
        if(prediction_no_progress_cycles>10000&&
           (!pred_active||pred_store_valid||memory_rd||memory_dout_ready||writer_stored))
            trace_event("WAIT_RELEASE",coded_picture);
        if(cache_error||mismatch)$fatal(1,"native cache/field-order error");
    end
    final begin
        trace_event("END",selected_id);
        $display("NATIVE_RESULT publications=%0d bank_swaps=%0d decoded=%0d pts_records=%0d associated=%0d fields=%0d cache_error=%0d overlap=%0d",publications,display_swaps,published_references+b_pictures,pts_index,associated,field_number,cache_error,overlap_error);
        $fclose(trace_fd);
    end
end else begin: synthetic_presentation
    assign native_reader_burst=0;assign native_reader_addr=0;assign native_reader_rd=0;
    assign native_memory_busy=0;assign native_film_mode=0;assign native_field=0;
    assign native_picture_present=0;assign native_display_rff=0;assign native_candidate_tff=1;
    assign native_pts_active=0;assign native_pts_due=0;assign native_active=0;
    assign native_swap=0;assign native_cadence=0;assign native_metadata_pending=0;
end endgenerate
