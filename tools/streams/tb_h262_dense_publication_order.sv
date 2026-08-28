`timescale 1ns/1ps

// Entry 215 complete repeated-GOP publication/presentation regression.  The
// real front end admits every I picture, the combined P/B sideband is retired
// exactly as the raster engines retire it, and a bounded vblank model requires
// the final reference identity to reach the display without a bank overwrite.
module tb_h262_dense_publication_order;
    localparam integer MAX_STREAM_BYTES=3145728;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0,quiet_cycles=0;
    integer last_stream_index=0,transport_stall_cycles=0;
    integer p_rows=0,b_rows=0,p_pictures=0,b_pictures=0;
    integer published_references=0,bank2_publications=0;
    reg row_persistence=0,picture_persistence=0;
    reg [5:0] previous_wide_parser_state=0;
    reg previous_wide_error=0;
    reg mixed_mode=0,long_mode=0;
    integer expected_p_rows,expected_p_pictures;
    integer expected_b_rows,expected_b_pictures;
    integer expected_reference_publications,expected_bank2_publications;

    wire stream_ready,decoder_stream_ready,picture_complete;
    wire phase1_supported;
    wire [13:0] frontend_vertical_size;
    wire [1:0] frontend_intra_dc_precision;
    wire frontend_intra_vlc_format;
    wire [7:0] picture_count,reference_promotion_count;
    wire reference_valid;wire[1:0] reference_bank,previous_reference_bank,active_bank,completed_bank;
    wire sideband_valid;
    wire [5:0] sideband_index;
    wire signed [15:0] sideband_value;
    wire probe_error,b_success;
    wire [3:0] probe_error_source,p_probe_error_source,p_progress_detail;
    wire [2:0] publication_error_detail;
    wire[1:0] display_frame_bank;wire display_scratch,display_scratch_bank;
    wire decode_scratch_bank,presentation_hold,presentation_complete;
    wire presentation_error;
    wire reference_overlap_header;
    wire [2:0] framebuffer_swap_reset_count;
    reg swap_window_pulse=0;
    integer swap_counter=0;
    reg [31:0] presentation_picture_window=0;
    reg presentation_header_capture=0;
    reg presentation_header_second_byte=0;
    reg b_picture_start=0,non_b_picture_start=0,i_picture_start=0,p_picture_start=0,sequence_end=0;
    reg reference_ownership_arm=0;
    reg destination_ownership_hold=0;
    integer destination_hold_count=0;
    integer displayed_bank_overwrite_count=0;
    reg [7:0] reference_identity[0:2];
    reg [7:0] scratch_identity[0:1];
    reg b_success_d=0;

    wire [31:0] presentation_picture_window_next=
        {presentation_picture_window[23:0],stream_data};
    wire frame_waiting=picture_complete&&
        (display_scratch||(completed_bank!=display_frame_bank));
    wire destination_display_owned=!display_scratch&&
        (active_bank==display_frame_bank);
    wire [7:0] displayed_identity=display_scratch?
        scratch_identity[display_scratch_bank]:reference_identity[display_frame_bank];

    assign stream_ready=decoder_stream_ready&&!presentation_hold&&
        !destination_ownership_hold;

    wire p_row_terminator=sideband_valid&&(sideband_index==6'h3f)&&
        ((sideband_value==16'shA2FE)||(sideband_value==16'shA2FF));
    wire b_row_terminator=sideband_valid&&(sideband_index==6'h3f)&&
        ((sideband_value==16'shA3FE)||(sideband_value==16'shA3FF));
    wire p_final=p_row_terminator&&(sideband_value==16'shA2FF);
    wire b_final=b_row_terminator&&(sideband_value==16'shA3FF);

    always #5 clk=~clk;

    mpeg2_h262_frontend frontend(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.phase1_supported(phase1_supported),
        .vertical_size(frontend_vertical_size),
        .intra_dc_precision(frontend_intra_dc_precision),
        .intra_vlc_format(frontend_intra_vlc_format));

    mpeg2_h262_two_picture_probe dut(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.stream_ready(decoder_stream_ready),
        .phase1_supported(phase1_supported),
        .vertical_size(frontend_vertical_size),
        .intra_dc_precision(frontend_intra_dc_precision),
        .intra_vlc_format(frontend_intra_vlc_format),
        .pipeline_block_done(1'b1),.recon_block_complete(1'b1),
        .p_persistence_complete(picture_persistence),
        .p_row_persistence_complete(row_persistence),
        .picture_420_complete(picture_complete),
        .active_frame_bank(active_bank),.completed_frame_bank(completed_bank),
        .picture_count(picture_count),.reference_frame_valid(reference_valid),
        .reference_frame_bank(reference_bank),
        .previous_reference_frame_bank(previous_reference_bank),
        .reference_promotion_count(reference_promotion_count),
        .p_residual_sample_valid(sideband_valid),
        .p_residual_sample_index(sideband_index),
        .p_residual_sample_value(sideband_value),
        .probe_error(probe_error),.probe_error_source(probe_error_source),
        .p_probe_error_source(p_probe_error_source),
        .p_progress_detail(p_progress_detail),
        .publication_error_detail(publication_error_detail),
        .b_user_success(b_success)
    );

    mpeg2_h262_b_presentation_scheduler scheduler(
        .native_film_mode(1'b0),
        .native_field(1'b0),
        .display_picture_present(1'b0),
        .display_repeat_first_field(1'b0),
        .candidate_top_field_first(1'b1),
        .clk(clk),.reset(reset),.swap_window_pulse(swap_window_pulse),
        .cadence_tick_pulse(swap_window_pulse),
        .frame_rate_code(4'h3),
        .timestamp_candidate_active(1'b0),
        .timestamp_candidate_due(1'b0),
        .native_ordinary_overlap_enable(1'b0),
        .active_frame_bank(active_bank),
        .frame_waiting(frame_waiting),.completed_frame_bank(completed_bank),
        .reference_frame_bank(reference_bank),.b_picture_start(b_picture_start),
        .reference_promotion_count(reference_promotion_count),
        .non_b_picture_start(non_b_picture_start),
        .i_picture_start(i_picture_start),
        .p_picture_start(p_picture_start),.sequence_end(sequence_end),
        .b_user_success(b_success),.b_decode_error(probe_error),
        .display_frame_bank(display_frame_bank),.display_scratch(display_scratch),
        .display_scratch_bank(display_scratch_bank),
        .decode_scratch_bank(decode_scratch_bank),
        .candidate_frame_valid(),.candidate_frame_scratch(),
        .candidate_scratch_bank(),.candidate_frame_bank(),
        .framebuffer_swap_reset_count(framebuffer_swap_reset_count),
        .reference_overlap_header(reference_overlap_header),
        .presentation_hold(presentation_hold),
        .presentation_complete(presentation_complete),
        .presentation_error(presentation_error));

    initial begin
        reference_identity[0]=0;
        reference_identity[1]=0;
        reference_identity[2]=0;
        scratch_identity[0]=0;
        scratch_identity[1]=0;
        if(!$value$plusargs("HEX=%s",hex_path))$fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len))$fatal(1,"missing +LEN");
        mixed_mode=$test$plusargs("MIXED");
        long_mode=$test$plusargs("LONG");
        if(mixed_mode&&long_mode)$fatal(1,"MIXED and LONG are mutually exclusive");
        if(long_mode)begin
            expected_p_rows=660;
            expected_p_pictures=22;
            expected_b_rows=1410;
            expected_b_pictures=47;
            expected_reference_publications=25;
            expected_bank2_publications=8;
        end else if(mixed_mode)begin
            expected_p_rows=210;
            expected_p_pictures=7;
            expected_b_rows=450;
            expected_b_pictures=15;
            expected_reference_publications=9;
            expected_bank2_publications=3;
        end else begin
            expected_p_rows=120;
            expected_p_pictures=4;
            expected_b_rows=210;
            expected_b_pictures=7;
            expected_reference_publications=5;
            expected_bank2_publications=1;
        end
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
        end else if(stream_index<stream_len)begin
            if(stream_ready)begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end else stream_valid<=0;
        end else stream_valid<=0;
    end

    always @(posedge clk) begin
        swap_window_pulse<=0;
        b_picture_start<=0;
        non_b_picture_start<=0;
        i_picture_start<=0;
        p_picture_start<=0;
        sequence_end<=0;
        b_success_d<=b_success;
        // A bounded synthetic vblank cadence proves ordering without making
        // full-corpus simulation wait for wall-clock display timing.
        if(swap_counter==99999)begin
            swap_counter<=0;
            swap_window_pulse<=1;
        end else swap_counter<=swap_counter+1;

        if(stream_valid)begin
            presentation_picture_window<=presentation_picture_window_next;
            if(presentation_picture_window_next==32'h00000100)begin
                presentation_header_capture<=1;
                presentation_header_second_byte<=0;
            end else if(presentation_header_capture)begin
                if(!presentation_header_second_byte)
                    presentation_header_second_byte<=1;
                else begin
                    presentation_header_capture<=0;
                    presentation_header_second_byte<=0;
                    if(stream_data[5:3]==3'b011)b_picture_start<=1;
                    else begin
                        non_b_picture_start<=1;
                        if(stream_data[5:3]==3'b001)i_picture_start<=1;
                        if(stream_data[5:3]==3'b010)p_picture_start<=1;
                    end
                    if(reference_ownership_arm||reference_overlap_header)begin
                        reference_ownership_arm<=0;
                        if((stream_data[5:3]==3'b010)&&
                           destination_display_owned)begin
                            destination_ownership_hold<=1;
                            destination_hold_count<=destination_hold_count+1;
                        end
                    end
                end
            end
            if(presentation_picture_window_next==32'h000001b7)
                sequence_end<=1;
        end

        if(destination_ownership_hold&&!destination_display_owned)
            destination_ownership_hold<=0;

        if(picture_complete)begin
            if(completed_bank==2'd2)
                bank2_publications<=bank2_publications+1;
            if(frontend.picture_coding_type==3'b010)
                reference_ownership_arm<=1;
            reference_identity[completed_bank]<=published_references+1;
            if((published_references!=0)&&!display_scratch&&
               (completed_bank==display_frame_bank))
                displayed_bank_overwrite_count<=
                    displayed_bank_overwrite_count+1;
        end
        if(b_success&&!b_success_d)
            scratch_identity[decode_scratch_bank]<=b_pictures;

        row_persistence<=0;
        picture_persistence<=0;
        previous_wide_parser_state<=
            dut.p_controller.wide_general_probe.parser_state;
        previous_wide_error<=dut.p_controller.wide_error;

        if((dut.p_controller.wide_general_probe.parser_state==6'd22)&&
           (previous_wide_parser_state!=6'd22))
            $display("WIDE_R_ERROR byte=%0d previous_state=%0d parse_byte=%0d/%0d bit=%0d row=%0d col=%0d covered=%0d row_bytes=%0d boundary_final=%0d slice_capture=%0d parser_started=%0d qfs=%0d run=%0d target=%0d coeffs=%0d blocks=%0d intra=%0d",
                     stream_index,previous_wide_parser_state,
                     dut.p_controller.wide_general_probe.parse_byte_index,
                     dut.p_controller.wide_general_probe.parse_byte_limit,
                     dut.p_controller.wide_general_probe.parse_bit_index,
                     dut.p_controller.wide_general_probe.slice_row_number,
                     dut.p_controller.wide_general_probe.current_col,
                     dut.p_controller.wide_general_probe.row_covered_count,
                     dut.p_controller.wide_general_probe.row_byte_count,
                     dut.p_controller.wide_general_probe.boundary_final,
                     dut.p_controller.wide_general_probe.slice_capture,
                     dut.p_controller.wide_general_probe.slice_parser_started,
                     dut.p_controller.wide_general_probe.qfs_index,
                     dut.p_controller.wide_general_probe.coeff_run_pending,
                     dut.p_controller.wide_general_probe.normal_target_index,
                     dut.p_controller.wide_general_probe.residual_coeff_count,
                     dut.p_controller.wide_general_probe.residual_block_count,
                     dut.p_controller.wide_general_probe.current_is_intra);

        if(dut.p_controller.wide_error&&!previous_wide_error)
            $display("WIDE_ERROR byte=%0d detail=%0d previous_state=%0d state=%0d parse_byte=%0d/%0d bit=%0d row=%0d col=%0d covered=%0d row_bytes=%0d boundary_final=%0d slice_capture=%0d parser_started=%0d",
                     stream_index,
                     dut.p_controller.wide_general_probe.probe_error_detail,
                     previous_wide_parser_state,
                     dut.p_controller.wide_general_probe.parser_state,
                     dut.p_controller.wide_general_probe.parse_byte_index,
                     dut.p_controller.wide_general_probe.parse_byte_limit,
                     dut.p_controller.wide_general_probe.parse_bit_index,
                     dut.p_controller.wide_general_probe.slice_row_number,
                     dut.p_controller.wide_general_probe.current_col,
                     dut.p_controller.wide_general_probe.row_covered_count,
                     dut.p_controller.wide_general_probe.row_byte_count,
                     dut.p_controller.wide_general_probe.boundary_final,
                     dut.p_controller.wide_general_probe.slice_capture,
                     dut.p_controller.wide_general_probe.slice_parser_started);

        if(p_row_terminator)begin
            row_persistence<=1;
            p_rows<=p_rows+1;
            if(p_final)begin
                picture_persistence<=1;
                p_pictures<=p_pictures+1;
                $display("P_FINAL byte=%0d p=%0d inflight=%0d headers=%0d publications=%0d",
                         stream_index,p_pictures+1,dut.b_picture_inflight,
                         dut.p_header_count,dut.p_publication_count);
            end
        end else if(b_row_terminator)begin
            row_persistence<=1;
            b_rows<=b_rows+1;
            if(b_final)begin
                picture_persistence<=1;
                b_pictures<=b_pictures+1;
                $display("B_FINAL byte=%0d b=%0d inflight=%0d headers=%0d persisted=%0d",
                         stream_index,b_pictures+1,dut.b_picture_inflight,
                         dut.b_header_count,dut.b_persist_count);
            end
        end

        if(dut.b_header_now)
            $display("B_HEADER byte=%0d inflight=%0d p_headers=%0d p_publications=%0d b_headers=%0d b_persist=%0d",
                     stream_index,dut.b_picture_inflight,
                     dut.p_header_count,dut.p_publication_count,
                     dut.b_header_count,dut.b_persist_count);
        if(dut.p_persisted_now)
            $display("P_PUBLISH_EDGE byte=%0d headers=%0d publications=%0d",
                     stream_index,dut.p_header_count,dut.p_publication_count);
        if(dut.b_persisted_now)
            $display("B_PERSIST_EDGE byte=%0d headers=%0d persisted=%0d",
                     stream_index,dut.b_header_count,dut.b_persist_count);

        if(picture_complete)published_references<=published_references+1;

        if(stream_index!=last_stream_index)begin
            last_stream_index<=stream_index;
            transport_stall_cycles<=0;
        end else if(stream_index<stream_len)begin
            transport_stall_cycles<=transport_stall_cycles+1;
            if(transport_stall_cycles==(presentation_hold?8000000:2000000))
                $fatal(1,"dense publication transport stalled byte=%0d inflight=%0d p_hold=%0d b_hold=%0d b_wait=%0d presentation_hold=%0d reorder=%0d closed=%0d decode_inflight=%0d scratch=%0d%0d future=%0d p_headers=%0d p_publications=%0d b_headers=%0d b_persist=%0d p_rows=%0d p=%0d b_rows=%0d b=%0d wide_candidate=%0d wide_seen=%0d wide_error=%0d proof_done=%0d current_p=%0d picture_capture=%0d slice_capture=%0d parse_active=%0d row_waiting=%0d wide_parse_hold=%0d b_candidate=%0d b_seen=%0d",
                       stream_index,dut.b_picture_inflight,
                       dut.p_hold_effective,dut.b_parse_hold,
                       dut.b_persistence_wait,presentation_hold,
                       scheduler.reorder_active,scheduler.run_closed,
                       scheduler.decode_inflight,scheduler.scratch1_pending,
                       scheduler.scratch0_pending,scheduler.future_frame_pending,
                       dut.p_header_count,
                       dut.p_publication_count,dut.b_header_count,
                       dut.b_persist_count,p_rows,p_pictures,b_rows,b_pictures,
                       dut.p_controller.wide_candidate,
                       dut.p_controller.wide_seen,
                       dut.p_controller.wide_error,
                       dut.p_controller.wide_general_probe.proof_done,
                       dut.p_controller.wide_general_probe.current_picture_is_p,
                       dut.p_controller.wide_general_probe.picture_capture,
                       dut.p_controller.wide_general_probe.slice_capture,
                       dut.p_controller.wide_general_probe.parse_active,
                       dut.p_controller.wide_general_probe.row_waiting,
                       dut.p_controller.wide_parse_hold,
                       dut.b_candidate,dut.b_seen);
        end

        // I reconstruction completion is modeled as immediately acknowledged,
        // while the real front end still drives the per-picture I capability
        // window. The compiled shell gates the legacy observer after the first
        // B header; enforce every error from that point forward, including all
        // publication-order checks.
        if(probe_error&&dut.b_picture_observed)
            $fatal(1,"publication sequence error source=%0d detail=%0d byte=%0d p_headers=%0d p_publications=%0d b_headers=%0d b_persist=%0d active=%0d completed=%0d reference_valid=%0d reference=%0d pictures=%0d promotions=%0d",
                   probe_error_source,publication_error_detail,stream_index,
                   dut.p_header_count,dut.p_publication_count,
                   dut.b_header_count,dut.b_persist_count,
                   active_bank,completed_bank,reference_valid,reference_bank,
                   picture_count,reference_promotion_count);

        if((stream_index==stream_len)&&stream_ready&&!sideband_valid)
            quiet_cycles<=quiet_cycles+1;
        else quiet_cycles<=0;

        if(quiet_cycles==100)begin
            $display("DENSE_PUBLICATION_RESULT bytes=%0d p_rows=%0d p=%0d b_rows=%0d b=%0d published=%0d pictures=%0d promotions=%0d bank2=%0d/%0d banks=%0d/%0d/%0d/%0d b_success=%0d display_identity=%0d destination_holds=%0d overwrites=%0d presentation_complete=%0d presentation_error=%0d",
                     stream_index,p_rows,p_pictures,b_rows,b_pictures,
                     published_references,picture_count,
                     reference_promotion_count,bank2_publications,
                     expected_bank2_publications,active_bank,completed_bank,
                     previous_reference_bank,reference_bank,b_success,displayed_identity,
                     destination_hold_count,displayed_bank_overwrite_count,
                     presentation_complete,presentation_error);
            if(probe_error||publication_error_detail!=0||stream_index!=stream_len||
               p_rows!=expected_p_rows||p_pictures!=expected_p_pictures||
               b_rows!=expected_b_rows||b_pictures!=expected_b_pictures||
               published_references!=expected_reference_publications||
               picture_count!=expected_reference_publications||
               reference_promotion_count!=expected_reference_publications||
               bank2_publications!=expected_bank2_publications||
               active_bank>2||completed_bank>2||reference_bank>2||
               previous_reference_bank>2||reference_bank==active_bank||
               displayed_identity!=expected_reference_publications||
               displayed_bank_overwrite_count!=0||
               !presentation_complete||presentation_error||
               dut.p_header_count!=expected_p_pictures||
               dut.p_publication_count!=expected_p_pictures||
               dut.b_header_count!=expected_b_pictures||
               dut.b_persist_count!=expected_b_pictures||!b_success)
                $fatal(1,"dense publication-order regression failed");
            $finish;
        end
    end

    initial begin
        repeat(200000000)@(posedge clk);
        $fatal(1,"dense publication-order regression timed out at byte %0d",stream_index);
    end

    wire unused=&{1'b0,p_probe_error_source,p_progress_detail,
                  framebuffer_swap_reset_count};
endmodule
