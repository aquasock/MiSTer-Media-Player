            default:;
        endcase
        3'd6: if(bits[5:0]==6'b000001)
            match_p_mbtype=5'b10011;
        default:;
        endcase
    end
endfunction
wire [4:0] mbtype_match =
    match_p_mbtype(mbtype_bits_next,mbtype_len_next);

// {valid,signed motion_code[5:0]}; H.262 Table B.10.
function automatic [6:0] match_motion_code;
    input [10:0] bits;
    input [3:0] len;
    reg valid;
    reg signed [5:0] code;
    begin
        valid=0; code=0;
        case(len)
        4'd1: if(bits[0]) begin valid=1;code=0;end
        4'd3: case(bits[2:0])
            3'b010:begin valid=1;code=1;end
            3'b011:begin valid=1;code=-1;end
            default:;
        endcase
        4'd4: case(bits[3:0])
            4'b0010:begin valid=1;code=2;end
            4'b0011:begin valid=1;code=-2;end
            default:;
        endcase
        4'd5: case(bits[4:0])
            5'b00010:begin valid=1;code=3;end
            5'b00011:begin valid=1;code=-3;end
            default:;
        endcase
        4'd7: case(bits[6:0])
            7'b0000110:begin valid=1;code=4;end
            7'b0000111:begin valid=1;code=-4;end
            default:;
        endcase
        4'd8: case(bits[7:0])
            8'b00001010:begin valid=1;code=5;end
            8'b00001011:begin valid=1;code=-5;end
            8'b00001000:begin valid=1;code=6;end
            8'b00001001:begin valid=1;code=-6;end
            8'b00000110:begin valid=1;code=7;end
            8'b00000111:begin valid=1;code=-7;end
            default:;
        endcase
        4'd10: case(bits[9:0])
            10'b0000010110:begin valid=1;code=8;end
            10'b0000010111:begin valid=1;code=-8;end
            10'b0000010100:begin valid=1;code=9;end
            10'b0000010101:begin valid=1;code=-9;end
            10'b0000010010:begin valid=1;code=10;end
            10'b0000010011:begin valid=1;code=-10;end
            default:;
        endcase
        4'd11: case(bits[10:0])
            11'b00000100010:begin valid=1;code=11;end
            11'b00000100011:begin valid=1;code=-11;end
            11'b00000100000:begin valid=1;code=12;end
            11'b00000100001:begin valid=1;code=-12;end
            11'b00000011110:begin valid=1;code=13;end
            11'b00000011111:begin valid=1;code=-13;end
            11'b00000011100:begin valid=1;code=14;end
            11'b00000011101:begin valid=1;code=-14;end
            11'b00000011010:begin valid=1;code=15;end
            11'b00000011011:begin valid=1;code=-15;end
            11'b00000011000:begin valid=1;code=16;end
            11'b00000011001:begin valid=1;code=-16;end
            default:;
        endcase
        default:;
        endcase
        match_motion_code={valid,code[5:0]};
    end
endfunction
wire [6:0] motion_match =
    match_motion_code(motion_vlc_bits_next,motion_vlc_len_next);

function automatic signed [7:0] reconstruct_mv;
    input signed [7:0] pred;
    input signed [5:0] code;
    input [2:0] residual;
    input [3:0] f_code;
    reg [5:0] mag;
    reg [2:0] r_size;
    reg signed [10:0] delta, vec, low_limit, high_limit, vector_range;
    begin
        r_size=f_code-1'b1;
        if(code==0) delta=0;
        else if(f_code==4'd1) delta=code;
        else begin
            if(code<0) mag=-code; else mag=code;
            delta=(($signed({1'b0,mag})-1) <<< r_size) +
                  $signed({8'd0,residual}) + 1;
            if(code<0) delta=-delta;
        end
        vec=$signed(pred)+delta;
        low_limit=-(11'sd16 <<< r_size);
        high_limit=(11'sd16 <<< r_size)-1'b1;
        vector_range=11'sd32 <<< r_size;
        if(vec>high_limit) vec=vec-vector_range;
        else if(vec<low_limit) vec=vec+vector_range;
        reconstruct_mv=vec[7:0];
    end
endfunction

function automatic [6:0] match_cbp_code;
    input [8:0] bits;
    input [3:0] len;
    reg valid;
    reg [5:0] value;
    begin
        valid=0;value=0;
        case(len)
        4'd3: if(bits[2:0]==3'b111) begin valid=1;value=60;end
        4'd4: case(bits[3:0])
            4'b1010:begin valid=1;value=32;end
            4'b1011:begin valid=1;value=16;end
            4'b1100:begin valid=1;value=8;end
            4'b1101:begin valid=1;value=4;end
            default:;
        endcase
        4'd5: case(bits[4:0])
            5'b01000:begin valid=1;value=62;end
            5'b01001:begin valid=1;value=2;end
            5'b01010:begin valid=1;value=61;end
            5'b01011:begin valid=1;value=1;end
            5'b01100:begin valid=1;value=56;end
            5'b01101:begin valid=1;value=52;end
            5'b01110:begin valid=1;value=44;end
            5'b01111:begin valid=1;value=28;end
            5'b10000:begin valid=1;value=40;end
            5'b10001:begin valid=1;value=20;end
            5'b10010:begin valid=1;value=48;end
            5'b10011:begin valid=1;value=12;end
            default:;
        endcase
        4'd6: case(bits[5:0])
            6'b001100:begin valid=1;value=63;end
            6'b001101:begin valid=1;value=3;end
            6'b001110:begin valid=1;value=36;end
            6'b001111:begin valid=1;value=24;end
            default:;
        endcase
        4'd7: case(bits[6:0])
            7'b0010000:begin valid=1;value=34;end
            7'b0010001:begin valid=1;value=18;end
            7'b0010010:begin valid=1;value=10;end
            7'b0010011:begin valid=1;value=6;end
            7'b0010100:begin valid=1;value=33;end
            7'b0010101:begin valid=1;value=17;end
            7'b0010110:begin valid=1;value=9;end
            7'b0010111:begin valid=1;value=5;end
            default:;
        endcase
        4'd8: case(bits[7:0])
            8'b00000100:begin valid=1;value=58;end
            8'b00000101:begin valid=1;value=54;end
            8'b00000110:begin valid=1;value=46;end
            8'b00000111:begin valid=1;value=30;end
            8'b00001000:begin valid=1;value=57;end
            8'b00001001:begin valid=1;value=53;end
            8'b00001010:begin valid=1;value=45;end
            8'b00001011:begin valid=1;value=29;end
            8'b00001100:begin valid=1;value=38;end
            8'b00001101:begin valid=1;value=26;end
            8'b00001110:begin valid=1;value=37;end
            8'b00001111:begin valid=1;value=25;end
            8'b00010000:begin valid=1;value=43;end
            8'b00010001:begin valid=1;value=23;end
            8'b00010010:begin valid=1;value=51;end
            8'b00010011:begin valid=1;value=15;end
            8'b00010100:begin valid=1;value=42;end
            8'b00010101:begin valid=1;value=22;end
            8'b00010110:begin valid=1;value=50;end
            8'b00010111:begin valid=1;value=14;end
            8'b00011000:begin valid=1;value=41;end
            8'b00011001:begin valid=1;value=21;end
            8'b00011010:begin valid=1;value=49;end
            8'b00011011:begin valid=1;value=13;end
            8'b00011100:begin valid=1;value=35;end
            8'b00011101:begin valid=1;value=19;end
            8'b00011110:begin valid=1;value=11;end
            8'b00011111:begin valid=1;value=7;end
            default:;
        endcase
        4'd9: case(bits[8:0])
            9'b000000010:begin valid=1;value=39;end
            9'b000000011:begin valid=1;value=27;end
            9'b000000100:begin valid=1;value=59;end
            9'b000000101:begin valid=1;value=55;end
            9'b000000110:begin valid=1;value=47;end
            9'b000000111:begin valid=1;value=31;end
            default:;
        endcase
        default:;
        endcase
        match_cbp_code={valid,value};
    end
endfunction
wire [6:0] cbp_match =
    match_cbp_code(cbp_vlc_bits_next,cbp_vlc_len_next);

// H.262 Annex B Tables B.12 and B.13.
always @* begin
    dc_size_match=1'b0;
    dc_size_value=4'd0;
    if(current_block_index<3'd4) begin
        case(dc_vlc_len_next)
        4'd2: case(dc_vlc_code_next[1:0])
            2'b00:begin dc_size_match=1;dc_size_value=1;end
            2'b01:begin dc_size_match=1;dc_size_value=2;end
            default:;
        endcase
        4'd3: case(dc_vlc_code_next[2:0])
            3'b100:begin dc_size_match=1;dc_size_value=0;end
            3'b101:begin dc_size_match=1;dc_size_value=3;end
            3'b110:begin dc_size_match=1;dc_size_value=4;end
            default:;
        endcase
        4'd4:if(dc_vlc_code_next[3:0]==4'b1110)begin dc_size_match=1;dc_size_value=5;end
        4'd5:if(dc_vlc_code_next[4:0]==5'b11110)begin dc_size_match=1;dc_size_value=6;end
        4'd6:if(dc_vlc_code_next[5:0]==6'b111110)begin dc_size_match=1;dc_size_value=7;end
        4'd7:if(dc_vlc_code_next[6:0]==7'b1111110)begin dc_size_match=1;dc_size_value=8;end
        4'd8:if(dc_vlc_code_next[7:0]==8'b11111110)begin dc_size_match=1;dc_size_value=9;end
        4'd9:case(dc_vlc_code_next[8:0])
            9'b111111110:begin dc_size_match=1;dc_size_value=10;end
            9'b111111111:begin dc_size_match=1;dc_size_value=11;end
            default:;
        endcase
        default:;
        endcase
    end else begin
        case(dc_vlc_len_next)
        4'd2:case(dc_vlc_code_next[1:0])
            2'b00:begin dc_size_match=1;dc_size_value=0;end
            2'b01:begin dc_size_match=1;dc_size_value=1;end
            2'b10:begin dc_size_match=1;dc_size_value=2;end
            default:;
        endcase
        4'd3:if(dc_vlc_code_next[2:0]==3'b110)begin dc_size_match=1;dc_size_value=3;end
        4'd4:if(dc_vlc_code_next[3:0]==4'b1110)begin dc_size_match=1;dc_size_value=4;end
        4'd5:if(dc_vlc_code_next[4:0]==5'b11110)begin dc_size_match=1;dc_size_value=5;end
        4'd6:if(dc_vlc_code_next[5:0]==6'b111110)begin dc_size_match=1;dc_size_value=6;end
        4'd7:if(dc_vlc_code_next[6:0]==7'b1111110)begin dc_size_match=1;dc_size_value=7;end
        4'd8:if(dc_vlc_code_next[7:0]==8'b11111110)begin dc_size_match=1;dc_size_value=8;end
        4'd9:if(dc_vlc_code_next[8:0]==9'b111111110)begin dc_size_match=1;dc_size_value=9;end
        4'd10:case(dc_vlc_code_next[9:0])
            10'b1111111110:begin dc_size_match=1;dc_size_value=10;end
            10'b1111111111:begin dc_size_match=1;dc_size_value=11;end
            default:;
        endcase
        default:;
        endcase
    end
end

task init_row_parser;
    begin
        parse_byte_index<=0;
        parse_bit_index<=3'd7;
        parser_state<=R_H_QSCALE;
        field_bit_count<=0;
        qscale_shift<=0;
        extra_info_count<=0;
        mba_vlc_bits<=0;
        mba_vlc_len<=0;
        mba_escape_accum<=0;
        mba_increment<=0;
        previous_col<=-8'sd1;
        current_col<=0;
        row_has_coded_mb<=0;
        skip_emit_col<=0;
        skip_remaining<=0;
        predictor_x<=0;
        predictor_y<=0;
        current_motion_x<=0;
        current_motion_y<=0;
        current_is_intra<=0;
        dc_predictor_y<=dc_predictor_reset;
        dc_predictor_cb<=dc_predictor_reset;
        dc_predictor_cr<=dc_predictor_reset;
        dc_vlc_code<=0;
        dc_vlc_len<=0;
        dc_size<=0;
        dc_diff_shift<=0;
        dc_diff_bit_count<=0;
        mbtype_bits<=0;
        mbtype_len<=0;
        motion_vlc_bits<=0;
        motion_vlc_len<=0;
        cbp_vlc_bits<=0;
        cbp_vlc_len<=0;
        current_cbp<=0;
        current_block_index<=0;
    end
endtask

always @(posedge clk) begin
    if(reset) begin
        byte_window<=0;
        sequence_capture<=0;
        sequence_count<=0;
        sequence_shift<=0;
        geometry_supported<=0;
        picture_mb_width<=0;
        picture_mb_height<=0;
        picture_mb_count<=0;
        picture_capture<=0;
        picture_count<=0;
        picture_shift<=0;
        current_picture_is_p<=0;
        pce_capture<=0;
        pce_count<=0;
        pce_shift<=0;
        p_forward_f_code_horizontal<=0;
        p_forward_f_code_vertical<=0;
        p_intra_vlc_format<=0;
        wide_candidate<=0;
        wide_seen<=0;
        wide_complete_now<=0;
        motion_event_valid<=0;
        motion_event_index<=0;
        motion_event_x<=0;
        motion_event_y<=0;
        motion_event_intra<=0;
        residual_mb_plan<=0;
        residual_block_index_plan<=0;
        residual_intra_plan<=0;
        residual_block_count<=0;
        residual_present<=0;
        residual_coeff_index_plan<=0;
        residual_coeff_value_plan<=0;
        residual_coeff_last_plan<=0;
        residual_coeff_count<=0;
        residual_qscale_plan<=0;
        q_scale_type<=0;
        alternate_scan<=0;
        parse_hold<=0;
        probe_error<=0;
        slice_capture<=0;
        slice_parser_started<=0;
        chunk_boundary_known<=0;
        slice_row_number<=0;
        row_byte_count<=0;
        row_base_index<=0;
        proof_done<=0;
        parse_active<=0;
        boundary_final<=0;
        final_release_pending<=0;
        parse_byte_limit<=0;
        parse_byte_index<=0;
        parse_bit_index<=3'd7;
        parser_state<=R_H_QSCALE;
        field_bit_count<=0;
        qscale_shift<=0;
        current_qscale<=0;
        extra_info_count<=0;
        mba_vlc_bits<=0;
        mba_vlc_len<=0;
        mba_escape_accum<=0;
        mba_increment<=0;
        previous_col<=-8'sd1;
        current_col<=0;
        row_has_coded_mb<=0;
        row_covered_count<=0;
        skip_emit_col<=0;
        skip_remaining<=0;
        mbtype_bits<=0;
        mbtype_len<=0;
        current_has_motion<=0;
        current_has_pattern<=0;
        current_has_quant<=0;
        current_is_intra<=0;
        predictor_x<=0;
        predictor_y<=0;
        current_motion_x<=0;
        current_motion_y<=0;
        motion_code_pending<=0;
        motion_vlc_bits<=0;
        motion_vlc_len<=0;
        motion_residual_shift<=0;
        motion_residual_count<=0;
        cbp_vlc_bits<=0;
        cbp_vlc_len<=0;
        current_cbp<=0;
        current_block_index<=0;
        current_residual_slot<=0;
        coeff_vlc_code<=0;
        coeff_vlc_len<=0;
        qfs_index<=0;
        coeff_run_pending<=0;
        coeff_level_pending<=0;
        current_block_has_coeff<=0;
        escape_run_shift<=0;
        escape_run_bit_count<=0;
        escape_level_shift<=0;
        escape_level_bit_count<=0;
        dc_predictor_y<=11'd128;
        dc_predictor_cb<=11'd128;
        dc_predictor_cr<=11'd128;
        dc_vlc_code<=0;
        dc_vlc_len<=0;
        dc_size<=0;
        dc_diff_shift<=0;
        dc_diff_bit_count<=0;
    end else begin
        wide_complete_now<=0;
        motion_event_intra<=0;
