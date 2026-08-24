`timescale 1ns/1ps

// End-to-end proof for the bounded 720x480 interlaced frame-DCT all-I subset.
// The authored field order is header metadata at this stage; reconstruction
// must produce the same full-frame Y/Cb/Cr planes for either TFF or BFF before
// native field presentation is allowed to consume those planes.
module tb_h262_interlaced_i_reconstruction;
    localparam integer MAX_STREAM_BYTES = 1048576;
    localparam integer FRAME_COUNT = 4;
    localparam integer LUMA_BYTES = 720*480;
    localparam integer CHROMA_BYTES = 360*240;
    localparam integer FRAME_BYTES = LUMA_BYTES + 2*CHROMA_BYTES;
    localparam integer ORACLE_BYTES = FRAME_COUNT*FRAME_BYTES;
    localparam integer MAX_CYCLES = 300000000;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [7:0] pixel_oracle[0:ORACLE_BYTES-1];
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

    initial begin
        if(!$value$plusargs("HEX=%s",hex_path))$fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len))$fatal(1,"missing +LEN");
        expected_tff=$test$plusargs("TFF");
        expect_progressive=$test$plusargs("PROGRESSIVE");
        expect_reject=$test$plusargs("REJECT");
        if(!expect_reject)begin
            if(!$value$plusargs("PIXELS=%s",pixel_path))$fatal(1,"missing +PIXELS");
            $readmemh(pixel_path,pixel_oracle,0,ORACLE_BYTES-1);
        end
        if((stream_len<=0)||(stream_len>MAX_STREAM_BYTES))
            $fatal(1,"invalid stream length %0d",stream_len);
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        repeat(5)@(posedge clk);
        reset=0;
    end

    always @(negedge clk) begin
        if(reset)begin
            stream_valid<=0;
            stream_data<=0;
        end else if((stream_index<stream_len)&&parser_ready)begin
            stream_data<=stream_mem[stream_index];
            stream_valid<=1;
            stream_index<=stream_index+1;
        end else stream_valid<=0;
    end

    always @(posedge clk) begin
        total_cycles<=total_cycles+1;
        if(total_cycles>MAX_CYCLES)$fatal(1,"timeout at byte %0d",stream_index);
        if(phase1_supported)begin
            phase1_seen<=1;
            if(progressive_sequence)begin
                progressive_seen<=1;
                if(!progressive_frame||!chroma_420_type||repeat_first_field||
                   picture_structure!=3||!frame_pred_frame_dct)
                    $fatal(1,"progressive capability gate admitted wrong state");
            end else begin
                interlaced_seen<=1;
                field_order_seen<=top_field_first;
                if(horizontal_size!=720||vertical_size!=480||frame_rate_code!=4||
                   chroma_format!=1||picture_coding_type!=1||picture_structure!=3||
                   !frame_pred_frame_dct||concealment_motion_vectors||
                   progressive_frame||chroma_420_type||repeat_first_field||
                   top_field_first!=expected_tff)
                    $fatal(1,"interlaced capability gate admitted wrong state");
            end
        end
        if(syntax_error||probe_error||iq_error||unsupported_matrix||idct_error||recon_error)
            $fatal(1,"pipeline error syntax=%0d probe=%0d iq=%0d matrix=%0d idct=%0d recon=%0d",
                   syntax_error,probe_error,iq_error,unsupported_matrix,idct_error,recon_error);

        if(recon_pixel_valid&&!expect_reject)begin
            if(reconstructed_picture>=FRAME_COUNT)
                $fatal(1,"pixel after final picture");
            if(recon_pixel_component==0)begin
                if(recon_pixel_x>=720||recon_pixel_y>=480)
                    $fatal(1,"luma coordinate %0d,%0d",recon_pixel_x,recon_pixel_y);
                pixel_index=reconstructed_picture*FRAME_BYTES+
                    recon_pixel_y*720+recon_pixel_x;
            end else if(recon_pixel_component==1)begin
                if(recon_pixel_x>=360||recon_pixel_y>=240)
                    $fatal(1,"Cb coordinate %0d,%0d",recon_pixel_x,recon_pixel_y);
                pixel_index=reconstructed_picture*FRAME_BYTES+LUMA_BYTES+
                    recon_pixel_y*360+recon_pixel_x;
            end else if(recon_pixel_component==2)begin
                if(recon_pixel_x>=360||recon_pixel_y>=240)
                    $fatal(1,"Cr coordinate %0d,%0d",recon_pixel_x,recon_pixel_y);
                pixel_index=reconstructed_picture*FRAME_BYTES+LUMA_BYTES+CHROMA_BYTES+
                    recon_pixel_y*360+recon_pixel_x;
            end else $fatal(1,"invalid component %0d",recon_pixel_component);
            pixel_delta=$signed({1'b0,recon_pixel_value})-
                $signed({1'b0,pixel_oracle[pixel_index]});
            if(pixel_delta<0)pixel_delta=-pixel_delta;
            pixel_samples<=pixel_samples+1;
            if(pixel_delta>max_pixel_delta)max_pixel_delta<=pixel_delta;
            if(pixel_delta!=0)pixel_differences<=pixel_differences+1;
            // The existing fixed-point IDCT is qualified against FFmpeg with
            // the established one-LSB transform tolerance.  Coordinate,
            // component and sample-count checks remain exact.
            if(pixel_delta>1)begin
                pixel_mismatches<=pixel_mismatches+1;
                if(pixel_mismatches<8)
                    $display("PIXEL_MISMATCH frame=%0d c=%0d x=%0d y=%0d rtl=%0d oracle=%0d delta=%0d",
                        reconstructed_picture,recon_pixel_component,
                        recon_pixel_x,recon_pixel_y,recon_pixel_value,
                        pixel_oracle[pixel_index],pixel_delta);
            end
        end
        if(picture_complete)reconstructed_picture<=reconstructed_picture+1;

        if(stream_index==stream_len)quiet_cycles<=quiet_cycles+1;
        else quiet_cycles<=0;
        if(expect_reject&&(stream_index==stream_len)&&quiet_cycles>1000)begin
            $display("INTERLACED_I_REJECT_RESULT frontend=%0d phase1=%0d pictures=%0d cycles=%0d",
                frontend_ready,phase1_seen,picture_count,total_cycles);
            if(phase1_seen||picture_count!=0)
                $fatal(1,"unsupported interlaced syntax entered reconstruction");
            $display("PASS tb_h262_interlaced_i_reconstruction reject");
            $finish;
        end
        if(!expect_reject&&(stream_index==stream_len)&&
           (picture_count==FRAME_COUNT)&&quiet_cycles>1000)begin
            $display("I_RECON_RESULT progressive=%0d tff=%0d pictures=%0d pixels=%0d differences=%0d out_of_tolerance=%0d max_delta=%0d cycles=%0d",
                expect_progressive,expected_tff,picture_count,pixel_samples,
                pixel_differences,pixel_mismatches,max_pixel_delta,total_cycles);
            if(!phase1_seen||
               (expect_progressive?(!progressive_seen||interlaced_seen):
                                   (!interlaced_seen||progressive_seen||
                                    field_order_seen!=expected_tff))||
               reconstructed_picture!=FRAME_COUNT||pixel_samples!=ORACLE_BYTES||
               pixel_mismatches!=0||max_pixel_delta>1)
                $fatal(1,"I reconstruction regression failed");
            $display("PASS tb_h262_interlaced_i_reconstruction accept");
            $finish;
        end
    end
endmodule
