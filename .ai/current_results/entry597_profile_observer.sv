`timescale 1ns/1ps

// End-to-end proof for the bounded 720x480 interlaced frame-DCT all-I subset.
// The authored field order is header metadata at this stage; reconstruction
// must produce the same full-frame Y/Cb/Cr planes for either TFF or BFF before
// native field presentation is allowed to consume those planes.
module tb_entry597_i_throughput;
    localparam integer MAX_STREAM_BYTES = 33554432;
    localparam integer FRAME_COUNT = 4;
    localparam integer LUMA_BYTES = 720*480;
    localparam integer CHROMA_BYTES = 360*240;
    localparam integer FRAME_BYTES = LUMA_BYTES + 2*CHROMA_BYTES;
    localparam integer ORACLE_BYTES = FRAME_COUNT*FRAME_BYTES;
    localparam integer MAX_CYCLES = 300000000;
    // Four 30000/1001 pictures have 8,008,000 decoder clocks available at
    // 60 MHz.  This is an implementation-throughput gate, not an H.262 limit.
    localparam integer REALTIME_2997_FOUR_FRAME_CYCLES = 8008000;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path,pixel_path;
    integer stream_len,stream_index=0,total_cycles=0,quiet_cycles=0;
    integer reconstructed_picture=0,pixel_samples=0,pixel_differences=0;
    integer pixel_mismatches=0;
    integer max_pixel_delta=0,pixel_delta,pixel_index;
    reg phase1_seen=0,interlaced_seen=0,progressive_seen=0,field_order_seen=0;
    reg expected_tff=0;
    reg expect_progressive=0,expect_reject=0;

    wire parser_ready,frontend_ready,phase1_supported,syntax_error;
    wire [13:0] horizontal_size,vertical_size;
    wire [3:0] frame_rate_code;
    wire [1:0] chroma_format,intra_dc_precision,picture_structure;
    wire [2:0] picture_coding_type;
    wire progressive_sequence,progressive_frame,chroma_420_type;
    wire top_field_first,repeat_first_field,frame_pred_frame_dct;
    wire concealment_motion_vectors,intra_vlc_format,q_scale_type,alternate_scan;
    wire intra_quant_matrix_default;

    wire slice_start,macroblock_start;
    wire [2:0] qfs_block_index;
    wire qfs_block_start,qfs_write_en,qfs_block_end;
    wire [5:0] qfs_write_index;
    wire signed [12:0] qfs_write_value;
    wire [4:0] slice_quantiser_scale_code;
    wire macroblock_quant;
    wire [4:0] macroblock_quantiser_scale_code;
    wire [11:0] macroblock_address_increment;
    wire [7:0] slice_vertical_position;
    wire [2:0] slice_vertical_position_extension;
    wire picture_complete,probe_error;
    wire [7:0] picture_count;

    wire iq_complete,iq_error,unsupported_matrix;
    wire iq_coeff_start,iq_coeff_valid,iq_coeff_end;
    wire [5:0] iq_coeff_index;
    wire signed [11:0] iq_coeff_value;
    wire idct_complete,idct_error,idct_sample_valid;
    wire [5:0] idct_sample_index;
    wire signed [15:0] idct_sample_value;
    wire recon_pixel_valid,recon_block_start,recon_block_complete;
    wire recon_macroblock_complete,recon_error;
    wire [1:0] recon_pixel_component;
    wire [11:0] recon_pixel_x,recon_pixel_y;
    wire [7:0] recon_pixel_value;

    wire [4:0] effective_quantiser_scale_code = macroblock_quant ?
        macroblock_quantiser_scale_code : slice_quantiser_scale_code;

    always #5 clk=~clk;

    mpeg2_h262_frontend frontend(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.frontend_ready(frontend_ready),
        .phase1_supported(phase1_supported),
        .syntax_error(syntax_error),.horizontal_size(horizontal_size),
        .vertical_size(vertical_size),.frame_rate_code(frame_rate_code),
        .progressive_sequence(progressive_sequence),.chroma_format(chroma_format),
        .picture_coding_type(picture_coding_type),
        .intra_dc_precision(intra_dc_precision),
        .picture_structure(picture_structure),
        .frame_pred_frame_dct(frame_pred_frame_dct),
        .concealment_motion_vectors(concealment_motion_vectors),
        .q_scale_type(q_scale_type),.intra_vlc_format(intra_vlc_format),
        .alternate_scan(alternate_scan),.progressive_frame(progressive_frame),
        .chroma_420_type(chroma_420_type),.top_field_first(top_field_first),
        .repeat_first_field(repeat_first_field),
        .intra_quant_matrix_default(intra_quant_matrix_default));

    mpeg2_h262_picture_bookkeeper parser(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.parser_stream_ready(parser_ready),
        .phase1_supported(phase1_supported),.vertical_size(vertical_size),
        .intra_dc_precision(intra_dc_precision),
        .intra_vlc_format(intra_vlc_format),
        .pipeline_block_done(recon_block_complete),
        .recon_block_complete(recon_block_complete),
        .picture_420_complete(picture_complete),.picture_count(picture_count),
        .probe_error(probe_error),
        .quantiser_scale_code(slice_quantiser_scale_code),
        .macroblock_address_increment(macroblock_address_increment),
        .macroblock_quant(macroblock_quant),
        .macroblock_quantiser_scale_code(macroblock_quantiser_scale_code),
        .slice_vertical_position(slice_vertical_position),
        .slice_vertical_position_extension(slice_vertical_position_extension),
        .slice_start(slice_start),.luma_macroblock_start(macroblock_start),
        .qfs_block_index(qfs_block_index),.qfs_block_start(qfs_block_start),
        .qfs_write_en(qfs_write_en),.qfs_write_index(qfs_write_index),
        .qfs_write_value(qfs_write_value),.qfs_block_end(qfs_block_end));

    mpeg2_h262_inverse_quant inverse_quant(
        .clk(clk),.reset(reset),.block_start(qfs_block_start),
        .coeff_write_en(qfs_write_en),.coeff_write_index(qfs_write_index),
        .coeff_write_value(qfs_write_value),.block_end(qfs_block_end),
        .intra_quant_matrix_default(intra_quant_matrix_default),
        .intra_dc_precision(intra_dc_precision),
        .quantiser_scale_code(effective_quantiser_scale_code),
        .q_scale_type(q_scale_type),.alternate_scan(alternate_scan),
        .block_complete(iq_complete),.iq_error(iq_error),
        .unsupported_matrix(unsupported_matrix),
        .coeff_out_block_start(iq_coeff_start),
        .coeff_out_valid(iq_coeff_valid),.coeff_out_index(iq_coeff_index),
        .coeff_out_value(iq_coeff_value),.coeff_out_block_end(iq_coeff_end));

    mpeg2_h262_idct idct(
        .clk(clk),.reset(reset),.coeff_block_start(iq_coeff_start),
        .coeff_valid(iq_coeff_valid),.coeff_index(iq_coeff_index),
        .coeff_value(iq_coeff_value),.coeff_block_end(iq_coeff_end),
        .block_complete(idct_complete),.idct_error(idct_error),
        .sample_valid(idct_sample_valid),.sample_index(idct_sample_index),
        .sample_value(idct_sample_value));

    mpeg2_h262_intra_recon recon(
        .clk(clk),.reset(reset),.horizontal_size(horizontal_size),
        .vertical_size(vertical_size),
        .slice_vertical_position(slice_vertical_position),
        .slice_vertical_position_extension(slice_vertical_position_extension),
        .macroblock_address_increment(macroblock_address_increment),
        .slice_start(slice_start),.macroblock_start(macroblock_start),
        .block_index(qfs_block_index),.sample_valid(idct_sample_valid),
        .sample_index(idct_sample_index),.sample_value(idct_sample_value),
        .idct_block_complete(idct_complete),.pixel_valid(recon_pixel_valid),
        .pixel_component(recon_pixel_component),.pixel_x(recon_pixel_x),
        .pixel_y(recon_pixel_y),.pixel_value(recon_pixel_value),
        .block_start(recon_block_start),.block_complete(recon_block_complete),
        .macroblock_420_complete(recon_macroblock_complete),
        .recon_error(recon_error));


    integer expected_pictures=0, start_cycle=0, previous_complete=0;
    integer picture_bytes=0, previous_index=0, observed_pixels=0;
    integer fd, completed=0;
    integer ac_coefficients=0, blocks=0, pipeline_wait=0, parse_bits=0;
    integer transform_cycles=0, quant_sum=0;
    reg [31:0] accepted_window=0;
    reg started=0;
    reg [1023:0] report_path;
    initial begin
        if (!$value$plusargs("HEX=%s",hex_path)) $fatal(1,"missing HEX");
        if (!$value$plusargs("LEN=%d",stream_len)) $fatal(1,"missing LEN");
        if (!$value$plusargs("PICTURES=%d",expected_pictures)) $fatal(1,"missing PICTURES");
        if (!$value$plusargs("REPORT=%s",report_path)) $fatal(1,"missing REPORT");
        if (stream_len<1 || stream_len>MAX_STREAM_BYTES) $fatal(1,"invalid LEN");
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        fd=$fopen(report_path,"w");
        if (!fd) $fatal(1,"cannot open report");
        $fdisplay(fd,"picture,start_cycle,complete_cycle,decode_cycles,interval_cycles,bytes,pixels,ac_coefficients,blocks,pipeline_wait,parse_bits,transform_cycles,quant_sum");
        repeat (5) @(negedge clk);
        reset=0;
    end
    always @(negedge clk) begin
        if (!reset && stream_index<stream_len && parser_ready) begin
            stream_data<=stream_mem[stream_index];
            stream_valid<=1;
            stream_index<=stream_index+1;
        end else stream_valid<=0;
    end
    always @(posedge clk) begin
        if (!reset) begin
            total_cycles=total_cycles+1;
            if (stream_valid) begin
                accepted_window={accepted_window[23:0],stream_data};
                if (accepted_window==32'h00000100) begin
                    start_cycle=total_cycles;
                    started=1;
                end
            end
            if (syntax_error||probe_error||iq_error||unsupported_matrix||idct_error||recon_error)
                $fatal(1,"production reconstruction error");
            if (phase1_supported && (horizontal_size!=720 || vertical_size!=480 ||
                frame_rate_code!=4 || picture_coding_type!=1 || progressive_sequence))
                $fatal(1,"unexpected source format");
            if (recon_pixel_valid) observed_pixels=observed_pixels+1;
            if (qfs_write_en && qfs_write_index!=0 && qfs_write_value!=0)
                ac_coefficients=ac_coefficients+1;
            if (qfs_block_start) begin
                blocks=blocks+1;
                quant_sum=quant_sum+effective_quantiser_scale_code;
            end
            if (parser.picture_probe.parse_active && parser.picture_probe.parse_state==18)
                pipeline_wait=pipeline_wait+1;
            if (parser.picture_probe.bit_consume) parse_bits=parse_bits+1;
            if (idct.pass1_active || idct.pass2_active) transform_cycles=transform_cycles+1;
            if (picture_complete) begin
                if (!started || observed_pixels!=518400) $fatal(1,"incomplete picture pixels=%0d",observed_pixels);
                $fdisplay(fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",completed+1,start_cycle,total_cycles,
                    total_cycles-start_cycle,total_cycles-previous_complete,
                    stream_index-previous_index,observed_pixels,ac_coefficients,blocks,
                    pipeline_wait,parse_bits,transform_cycles,quant_sum);
                $fflush(fd);
                previous_complete=total_cycles;previous_index=stream_index;
                observed_pixels=0;ac_coefficients=0;blocks=0;pipeline_wait=0;
                parse_bits=0;transform_cycles=0;quant_sum=0;started=0;completed=completed+1;
                if (completed%16==0) $display("PROFILE pictures=%0d cycles=%0d",completed,total_cycles);
            end
            if (stream_index==stream_len) quiet_cycles=quiet_cycles+1;
            else quiet_cycles=0;
            if (completed==expected_pictures && quiet_cycles>1000) begin
                $display("I_THROUGHPUT_PASS pictures=%0d cycles=%0d bytes=%0d",completed,total_cycles,stream_index);
                $fclose(fd);$finish;
            end
            if (total_cycles>1200000000) $fatal(1,"timeout");
        end
    end
endmodule
