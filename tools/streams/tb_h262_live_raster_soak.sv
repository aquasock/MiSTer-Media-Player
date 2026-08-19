`timescale 1ns/1ps

// Entry 221: complete 72-picture I/P/B progression through the compiled
// generalized P/B raster wrapper, active tagged DDR writer, request arbiter,
// memory service, publication shell, and presentation scheduler.  The 128x96
// source keeps the real pixel/readback work inexpensive while preserving the
// same 3-I/22-P/47-B repeated-GOP transaction sequence as the 720x480 stream.
module tb_h262_live_raster_soak;
    localparam integer MAX_STREAM_BYTES=1048576;
    localparam [28:0] DDR_BASE=29'h06000000;
    localparam integer DDR_WORDS=262144;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [63:0] ddr_mem[0:DDR_WORDS-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0,quiet_cycles=0;
    integer i,p_rows=0,b_rows=0,p_pictures=0,b_pictures=0;
    integer published_references=0,display_swaps=0;
    integer reference_writes=0,scratch0_writes=0,scratch1_writes=0;
    integer memory_reads=0,total_cycles=0;

    wire frontend_ready,phase1_supported;
    wire [13:0] horizontal_size,vertical_size;
    wire [1:0] intra_dc_precision;
    wire intra_vlc_format;
    wire [2:0] picture_coding_type;
    wire [9:0] temporal_reference;
    wire sequence_end_seen;

    wire decoder_ready,picture_complete;
    wire active_bank,completed_bank,reference_valid,reference_bank;
    wire [7:0] picture_count,reference_promotion_count;
    wire sideband_valid;
    wire [5:0] sideband_index;
    wire signed [15:0] sideband_value;
    wire probe_error,b_success;
    wire [3:0] probe_error_source,p_probe_error_source,p_progress_detail;
    wire [2:0] publication_error_detail;
    wire [4:0] p_wide_probe_error_detail;

    wire [7:0] pred_burstcnt,pred_store_value,pred_sample,pred_recon_value;
    wire [28:0] pred_addr;
    wire pred_rd,pred_store_select,pred_store_valid,pred_store_start;
    wire pred_store_complete,pred_active,pred_read_seen,pred_sample_nonzero;
    wire pred_half_seen,pred_reconstructed_seen,pred_persisted;
    wire pred_row_persisted,pred_error;
    wire [11:0] pred_store_x,pred_store_y;
    wire [3:0] pred_progress;
    wire [2:0] pred_error_source;
    wire [4:0] pred_error_detail;
    assign pred_active=prediction.mixed_active||prediction.b_active;

    wire writer_stored,writer_seen,writer_error,writer_busy;
    wire [7:0] writer_burstcnt,writer_be;
    wire [28:0] writer_addr;
    wire writer_rd,writer_we;
    wire [63:0] writer_din;

    wire [7:0] memory_burstcnt;
    wire [28:0] memory_addr;
    wire memory_rd,memory_we;
    wire [63:0] memory_din;
    wire [7:0] memory_be;
    reg [63:0] memory_dout=0;
    reg memory_dout_ready=0,read_pending=0;
    reg [17:0] read_index=0;
    wire pred_busy,pred_dout_ready;

    wire display_frame_bank,display_scratch,display_scratch_bank;
    wire decode_scratch_bank,presentation_hold,presentation_complete;
    wire presentation_error;
    wire [2:0] framebuffer_swap_reset_count;
    reg swap_window_pulse=0;
    integer swap_counter=0;

    reg [31:0] picture_window=0;
    wire [31:0] picture_window_next={picture_window[23:0],stream_data};
    reg picture_header_capture=0,picture_header_second_byte=0;
    reg b_picture_start=0,non_b_picture_start=0,sequence_end=0;
    reg reference_ownership_arm=0,destination_ownership_hold=0;

    reg pred_persisted_d=0;
    reg pred_read_observed=0,pred_reconstructed_observed=0;
    reg display_frame_bank_d=0,display_scratch_d=0,display_scratch_bank_d=0;
    reg [7:0] reference_identity[0:1];
    reg [7:0] scratch_identity[0:1];
    reg [9:0] last_reference_temporal=0;
    wire [7:0] displayed_identity=display_scratch ?
        scratch_identity[display_scratch_bank] : reference_identity[display_frame_bank];

    wire destination_display_owned=!display_scratch&&
        (active_bank==display_frame_bank);
    wire frame_waiting=picture_complete&&
        (display_scratch||(completed_bank!=display_frame_bank));
    wire stream_ready=decoder_ready&&!presentation_hold&&
        !destination_ownership_hold;

    always #5 clk=~clk;

    mpeg2_h262_frontend frontend(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.frontend_ready(frontend_ready),
        .phase1_supported(phase1_supported),.horizontal_size(horizontal_size),
        .vertical_size(vertical_size),.intra_dc_precision(intra_dc_precision),
        .intra_vlc_format(intra_vlc_format),
        .picture_coding_type(picture_coding_type),
        .temporal_reference(temporal_reference),
        .sequence_end_seen(sequence_end_seen));

    mpeg2_h262_two_picture_probe publication(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.stream_ready(decoder_ready),
        .phase1_supported(phase1_supported),.vertical_size(vertical_size),
        .intra_dc_precision(intra_dc_precision),
        .intra_vlc_format(intra_vlc_format),
        .pipeline_block_done(1'b1),.recon_block_complete(1'b1),
        .p_persistence_complete(pred_persisted),
        .p_row_persistence_complete(pred_row_persisted),
        .picture_420_complete(picture_complete),
        .active_frame_bank(active_bank),.completed_frame_bank(completed_bank),
        .picture_count(picture_count),.reference_frame_valid(reference_valid),
        .reference_frame_bank(reference_bank),
        .reference_promotion_count(reference_promotion_count),
        .p_residual_sample_valid(sideband_valid),
        .p_residual_sample_index(sideband_index),
        .p_residual_sample_value(sideband_value),
        .probe_error(probe_error),.probe_error_source(probe_error_source),
        .p_probe_error_source(p_probe_error_source),
        .p_progress_detail(p_progress_detail),
        .publication_error_detail(publication_error_detail),
        .p_wide_probe_error_detail(p_wide_probe_error_detail),
        .b_user_success(b_success));

    mpeg2_h262_reference_read_probe prediction(
        .clk(clk),.reset(reset),.horizontal_size(horizontal_size),
        .vertical_size(vertical_size),.p_vector_proof_seen(1'b1),
        .p_forward_vector_valid(publication.p_forward_vector_valid),
        .p_forward_vector_x(publication.p_forward_vector_x),
        .p_forward_vector_y(publication.p_forward_vector_y),
        .forward_f_code_horizontal(frontend.forward_f_code_horizontal),
        .forward_f_code_vertical(frontend.forward_f_code_vertical),
        .p_implicit_reconstruct_request(1'b0),
        .p_residual_sample_valid(sideband_valid),
        .p_residual_sample_index(sideband_index),
        .p_residual_sample_value(sideband_value),
        .reference_frame_valid(reference_valid),
        .reference_frame_bank(reference_bank),
        .destination_frame_bank(active_bank),
        .b_scratch_frame_bank(decode_scratch_bank),
        .p_store_block_stored(writer_stored),.ddram_busy(pred_busy),
        .ddram_dout(memory_dout),.ddram_dout_ready(pred_dout_ready),
        .ddram_burstcnt(pred_burstcnt),.ddram_addr(pred_addr),
        .ddram_rd(pred_rd),.p_store_select(pred_store_select),
        .p_store_pixel_value(pred_store_value),
        .p_store_pixel_x(pred_store_x),.p_store_pixel_y(pred_store_y),
        .p_store_pixel_valid(pred_store_valid),
        .p_store_block_start(pred_store_start),
        .p_store_block_complete(pred_store_complete),.read_seen(pred_read_seen),
        .sample_value(pred_sample),.sample_nonzero(pred_sample_nonzero),
        .half_sample_seen(pred_half_seen),
        .reconstructed_seen(pred_reconstructed_seen),
        .reconstructed_value(pred_recon_value),.persisted_seen(pred_persisted),
        .row_persisted(pred_row_persisted),.p_progress_stage(pred_progress),
        .probe_error(pred_error),.probe_error_source(pred_error_source),
        .probe_error_detail(pred_error_detail));

    // This is the active writer selected by files.qip.  P chroma tags and B
    // scratch-bank/component tags are intentionally presented exactly as the
    // compiled top level presents them.
    mpeg2_h262_ddram_store writer(
        .clk(clk),.reset(reset),.frame_bank(active_bank),
        .pixel_value(pred_store_value),.pixel_component(2'd0),
        .pixel_x(pred_store_x),.pixel_y(pred_store_y),
        .pixel_valid(pred_store_valid),.block_start(pred_store_start),
        .block_complete(pred_store_complete),.block_stored(writer_stored),
        .write_seen(writer_seen),.store_error(writer_error),
        .ddram_busy(writer_busy),.ddram_burstcnt(writer_burstcnt),
        .ddram_addr(writer_addr),.ddram_rd(writer_rd),
        .ddram_din(writer_din),.ddram_be(writer_be),.ddram_we(writer_we));

    mpeg2_h262_ddram_arbiter arbiter(
        .clk(clk),.reset(reset),.writer_burstcnt(writer_burstcnt),
        .writer_addr(writer_addr),.writer_rd(writer_rd),
        .writer_din(writer_din),.writer_be(writer_be),.writer_we(writer_we),
        .writer_busy(writer_busy),.reader_burstcnt(8'd0),.reader_addr(29'd0),
        .reader_rd(1'b0),.prediction_burstcnt(pred_burstcnt),
        .prediction_addr(pred_addr),.prediction_rd(pred_rd),
        .prediction_busy(pred_busy),.prediction_dout_ready(pred_dout_ready),
        .ddram_busy(1'b0),.ddram_dout_ready(memory_dout_ready),
        .ddram_burstcnt(memory_burstcnt),.ddram_addr(memory_addr),
        .ddram_rd(memory_rd),.ddram_din(memory_din),.ddram_be(memory_be),
        .ddram_we(memory_we));

    mpeg2_h262_b_presentation_scheduler scheduler(
        .clk(clk),.reset(reset),.swap_window_pulse(swap_window_pulse),
        .frame_rate_code(4'h3),
        .frame_waiting(frame_waiting),.completed_frame_bank(completed_bank),
        .reference_frame_bank(reference_bank),.b_picture_start(b_picture_start),
        .non_b_picture_start(non_b_picture_start),.sequence_end(sequence_end),
        .b_user_success(b_success),.b_decode_error(probe_error||pred_error),
        .display_frame_bank(display_frame_bank),.display_scratch(display_scratch),
        .display_scratch_bank(display_scratch_bank),
        .decode_scratch_bank(decode_scratch_bank),
        .framebuffer_swap_reset_count(framebuffer_swap_reset_count),
        .presentation_hold(presentation_hold),
        .presentation_complete(presentation_complete),
        .presentation_error(presentation_error));

    initial begin
        reference_identity[0]=0;
        reference_identity[1]=0;
        scratch_identity[0]=0;
        scratch_identity[1]=0;
        for(i=0;i<DDR_WORDS;i=i+1)ddr_mem[i]=0;
        if(!$value$plusargs("HEX=%s",hex_path))$fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len))$fatal(1,"missing +LEN");
        if((stream_len<=0)||(stream_len>MAX_STREAM_BYTES))
            $fatal(1,"invalid LEN %0d",stream_len);
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        repeat(5)@(posedge clk);
        reset<=0;
    end

    always @(negedge clk) begin
        if(reset)begin
            stream_valid<=0;
            stream_data<=0;
        end
        else if(stream_index<stream_len)begin
            if(stream_ready)begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end
            else stream_valid<=0;
        end
        else stream_valid<=0;
    end

    always @(posedge clk) begin
        if(!reset)total_cycles<=total_cycles+1;
        memory_dout_ready<=0;
        if(read_pending)begin
            memory_dout<=ddr_mem[read_index];
            memory_dout_ready<=1;
            read_pending<=0;
        end
        if(memory_rd)begin
            memory_reads<=memory_reads+1;
            if((memory_addr<DDR_BASE)||((memory_addr-DDR_BASE)>=DDR_WORDS))
                $fatal(1,"DDR read outside frame regions: %h",memory_addr);
            read_index<=memory_addr-DDR_BASE;
            read_pending<=1;
        end
        if(memory_we)begin
            if((memory_addr<DDR_BASE)||((memory_addr-DDR_BASE)>=DDR_WORDS))
                $fatal(1,"DDR write outside frame regions: %h",memory_addr);
            ddr_mem[memory_addr-DDR_BASE]<=memory_din;
            case(memory_addr[17:16])
                2'd0,2'd1:reference_writes<=reference_writes+1;
                2'd2:scratch0_writes<=scratch0_writes+1;
                2'd3:scratch1_writes<=scratch1_writes+1;
            endcase
        end
    end

    always @(posedge clk) begin
        swap_window_pulse<=0;
        b_picture_start<=0;
        non_b_picture_start<=0;
        sequence_end<=0;
        pred_persisted_d<=pred_persisted;
        if(pred_read_seen)pred_read_observed<=1;
        if(pred_reconstructed_seen)pred_reconstructed_observed<=1;
        if(swap_counter==9999)begin
            swap_counter<=0;
            swap_window_pulse<=1;
        end
        else swap_counter<=swap_counter+1;

        if(stream_valid)begin
            picture_window<=picture_window_next;
            if(picture_window_next==32'h00000100)begin
                picture_header_capture<=1;
                picture_header_second_byte<=0;
            end
            else if(picture_header_capture)begin
                if(!picture_header_second_byte)
                    picture_header_second_byte<=1;
                else begin
                    picture_header_capture<=0;
                    picture_header_second_byte<=0;
                    if(stream_data[5:3]==3'b011)b_picture_start<=1;
                    else non_b_picture_start<=1;
                    if(reference_ownership_arm)begin
                        reference_ownership_arm<=0;
                        if((stream_data[5:3]==3'b010)&&destination_display_owned)
                            destination_ownership_hold<=1;
                    end
                end
            end
            if(picture_window_next==32'h000001b7)sequence_end<=1;
        end

        if(destination_ownership_hold&&!destination_display_owned)
            destination_ownership_hold<=0;
        if(picture_complete&&(picture_coding_type==3'b010))
            reference_ownership_arm<=1;

        if(pred_row_persisted)begin
            if(publication.b_picture_inflight)b_rows<=b_rows+1;
            else p_rows<=p_rows+1;
        end
        if(pred_persisted&&!pred_persisted_d)begin
            if(publication.b_picture_inflight)begin
                b_pictures<=b_pictures+1;
                scratch_identity[decode_scratch_bank]<=b_pictures+1;
            end
            else begin
                p_pictures<=p_pictures+1;
                last_reference_temporal<=temporal_reference;
            end
        end
        if(picture_complete)begin
            published_references<=published_references+1;
            reference_identity[completed_bank]<=published_references+1;
        end

        if((display_frame_bank!=display_frame_bank_d)||
           (display_scratch!=display_scratch_d)||
           (display_scratch&&
            (display_scratch_bank!=display_scratch_bank_d)))
            display_swaps<=display_swaps+1;
        display_frame_bank_d<=display_frame_bank;
        display_scratch_d<=display_scratch;
        display_scratch_bank_d<=display_scratch_bank;

        if(probe_error||pred_error||writer_error||presentation_error)
            $fatal(1,"live raster error byte=%0d shell=%0d/%0d/%0d pred=%0d/%0d writer=%0d presentation=%0d p_headers=%0d p_publications=%0d p_rows=%0d p_pictures=%0d",
                   stream_index,probe_error_source,p_probe_error_source,
                   publication_error_detail,pred_error_source,pred_error_detail,
                   writer_error,presentation_error,publication.p_header_count,
                   publication.p_publication_count,p_rows,p_pictures);

        if((stream_index==stream_len)&&sequence_end_seen&&!pred_active&&
           !presentation_hold&&!destination_ownership_hold&&!writer.writing&&
           !arbiter.read_outstanding&&!read_pending)
            quiet_cycles<=quiet_cycles+1;
        else quiet_cycles<=0;

        if(quiet_cycles==30000)begin
            $display("LIVE_RASTER_RESULT bytes=%0d p_rows=%0d p=%0d b_rows=%0d b=%0d published=%0d pictures=%0d promotions=%0d display_identity=%0d swaps=%0d last_p_temporal=%0d ref_writes=%0d scratch0_writes=%0d scratch1_writes=%0d ddr_reads=%0d cache=%0d/%0d/%0d cycles=%0d read=%0d recon=%0d presentation=%0d error=%0d/%0d/%0d/%0d",
                     stream_index,p_rows,p_pictures,b_rows,b_pictures,
                     published_references,picture_count,reference_promotion_count,
                     displayed_identity,display_swaps,last_reference_temporal,
                     reference_writes,scratch0_writes,scratch1_writes,
                     memory_reads,prediction.reference_cache.cache_hit_count,
                     prediction.reference_cache.cache_miss_count,
                     prediction.reference_cache.uncached_count,total_cycles,
                     pred_read_observed,pred_reconstructed_observed,
                     presentation_complete,probe_error,pred_error,writer_error,
                     presentation_error);
            if(stream_index!=stream_len||p_rows!=132||p_pictures!=22||
               b_rows!=282||b_pictures!=47||published_references!=25||
               picture_count!=25||reference_promotion_count!=25||
               publication.p_header_count!=22||publication.p_publication_count!=22||
               publication.b_header_count!=47||publication.b_persist_count!=47||
               displayed_identity!=25||last_reference_temporal!=10'd23||
               reference_writes==0||scratch0_writes==0||scratch1_writes==0||
               prediction.reference_cache.cache_hit_count==0||
               prediction.reference_cache.cache_hit_count<=
                prediction.reference_cache.cache_miss_count||
               total_cycles>=17800000||
               !writer_seen||!pred_read_observed||!pred_reconstructed_observed||
               !presentation_complete||probe_error||pred_error||writer_error||
               presentation_error)
                $fatal(1,"live raster soak failed");
            $finish;
        end
    end

    initial begin
        repeat(200000000)@(posedge clk);
        $fatal(1,"live raster soak timed out at byte %0d",stream_index);
    end

    wire unused=&{1'b0,frontend_ready,sideband_value,pred_sample,
                  pred_sample_nonzero,pred_half_seen,pred_recon_value,
                  pred_progress,p_wide_probe_error_detail,memory_burstcnt,
                  memory_din,memory_be,framebuffer_swap_reset_count};
endmodule
