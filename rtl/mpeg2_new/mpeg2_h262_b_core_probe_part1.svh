reg [6:0] qfs_index;
reg [5:0] coeff_run_pending,coeff_level_pending;
reg current_block_has_coeff;
wire [7:0] normal_target_index={1'b0,qfs_index}+{2'b00,coeff_run_pending};
reg [5:0] escape_run_shift; reg [2:0] escape_run_bit_count;
wire [5:0] escape_run_next={escape_run_shift[4:0],parser_current_bit};
reg [11:0] escape_level_shift; reg [3:0] escape_level_bit_count;
wire [11:0] escape_level_next={escape_level_shift[10:0],parser_current_bit};
wire signed [11:0] escape_level_signed=$signed(escape_level_next);
wire [7:0] escape_target_index={1'b0,qfs_index}+{2'b00,escape_run_shift};

wire [10:0] dc_predictor_reset=11'd128 << b_intra_dc_precision;
reg [10:0] dc_predictor_y,dc_predictor_cb,dc_predictor_cr;
wire [10:0] dc_predictor_current=(current_block_index<3'd4)?dc_predictor_y:
    (current_block_index==3'd4)?dc_predictor_cb:dc_predictor_cr;
reg [9:0] dc_vlc_code; reg [3:0] dc_vlc_len,dc_size,dc_diff_bit_count;
reg [10:0] dc_diff_shift;
wire [9:0] dc_vlc_code_next={dc_vlc_code[8:0],parser_current_bit};
wire [3:0] dc_vlc_len_next=dc_vlc_len+1'b1;
wire [10:0] dc_diff_bits_next={dc_diff_shift[9:0],parser_current_bit};
reg dc_size_match; reg [3:0] dc_size_value;
wire [12:0] dc_half_range=(dc_size==0)?13'd0:(13'd1 << (dc_size-1'b1));
wire [12:0] dc_raw_extended={2'b00,dc_diff_bits_next};
wire signed [12:0] dc_diff_decoded=(dc_size==0)?13'sd0:
    (dc_raw_extended>=dc_half_range)?$signed(dc_raw_extended):
    ($signed(dc_raw_extended)+13'sd1-$signed(dc_half_range<<1));
wire signed [12:0] dc_coefficient_decoded=
    $signed({2'b00,dc_predictor_current})+dc_diff_decoded;
wire [11:0] dc_coefficient_max=(12'd256 << b_intra_dc_precision)-12'd1;
wire signed [12:0] dc_coefficient_max_signed=$signed({1'b0,dc_coefficient_max});

wire [4:0] qscale_next={qscale_shift[3:0],parser_current_bit};
// Entry 695: frame_motion_type is two bits, motion_vertical_field_select one.
wire [1:0] motion_type_next={motion_type_shift[0],parser_current_bit};
wire [6:0] mba_bits_next={mba_bits[5:0],parser_current_bit};
wire [2:0] mba_len_next=mba_len+1'b1;
wire [10:0] motion_bits_next={motion_bits[9:0],parser_current_bit};
wire [3:0] motion_len_next=motion_len+1'b1;
wire [4:0] motion_residual_next={motion_residual_shift[3:0],parser_current_bit};
wire [5:0] mbtype_bits_next={mbtype_bits[4:0],parser_current_bit};
wire [2:0] mbtype_len_next=mbtype_len+1'b1;
wire [8:0] cbp_bits_next={cbp_bits[7:0],parser_current_bit};
wire [3:0] cbp_len_next=cbp_len+1'b1;
wire [10:0] current_map_index=row_base_index+{5'd0,current_col};

mpeg2_h262_dct_vlc b_dct_vlc
(
    .table_one(current_intra && b_intra_vlc_format),
    .vlc_code(coeff_vlc_code_next),
    .vlc_len(coeff_vlc_len_next),
    .match(coeff_vlc_match),
    .end_of_block(coeff_vlc_eob),
    .escape(coeff_vlc_escape),
    .run(coeff_vlc_run),
    .level(coeff_vlc_level)
);

function automatic [4:0] match_mba_increment;
    input [6:0] bits; input [2:0] len;
    begin
        match_mba_increment=5'd0;
        case(len)
        3'd1: if(bits[0]) match_mba_increment={1'b1,4'd1};
        3'd3: case(bits[2:0])
            3'b011:match_mba_increment={1'b1,4'd2};
            3'b010:match_mba_increment={1'b1,4'd3};
            default:;
        endcase
        3'd4: case(bits[3:0])
            4'b0011:match_mba_increment={1'b1,4'd4};
            4'b0010:match_mba_increment={1'b1,4'd5};
            default:;
        endcase
        3'd5: case(bits[4:0])
            5'b00011:match_mba_increment={1'b1,4'd6};
            5'b00010:match_mba_increment={1'b1,4'd7};
            default:;
        endcase
        3'd7: if(bits[6:0]==7'b0000111) match_mba_increment={1'b1,4'd8};
        default:;
        endcase
    end
endfunction
wire [4:0] mba_match=match_mba_increment(mba_bits_next,mba_len_next);
wire [6:0] mba_target_col={1'b0,current_col}+{3'd0,mba_match[3:0]}-1'b1;

function automatic [5:0] match_b_mbtype;
    input [5:0] bits; input [2:0] len;
    begin
        // STANDARDS_CONFORMANCE:H262-026. {valid, quant, intra,
        // direction[1:0], pattern}; Table B.4 intra codes are 00011/000001.
        match_b_mbtype=6'b000000;
        case(len)
        3'd2: case(bits[1:0])
            2'b10:match_b_mbtype={1'b1,1'b0,1'b0,2'd3,1'b0};
            2'b11:match_b_mbtype={1'b1,1'b0,1'b0,2'd3,1'b1};
            default:;
        endcase
        3'd3: case(bits[2:0])
            3'b010:match_b_mbtype={1'b1,1'b0,1'b0,2'd2,1'b0};
            3'b011:match_b_mbtype={1'b1,1'b0,1'b0,2'd2,1'b1};
            default:;
        endcase
        3'd4: case(bits[3:0])
            4'b0010:match_b_mbtype={1'b1,1'b0,1'b0,2'd1,1'b0};
            4'b0011:match_b_mbtype={1'b1,1'b0,1'b0,2'd1,1'b1};
            default:;
        endcase
        3'd5: case(bits[4:0])
            5'b00011:match_b_mbtype={1'b1,1'b0,1'b1,2'd0,1'b0};
            5'b00010:match_b_mbtype={1'b1,1'b1,1'b0,2'd3,1'b1};
            default:;
        endcase
        3'd6:case(bits[5:0])
            6'b000001:match_b_mbtype={1'b1,1'b1,1'b1,2'd0,1'b0};
            6'b000011:match_b_mbtype={1'b1,1'b1,1'b0,2'd1,1'b1};
            6'b000010:match_b_mbtype={1'b1,1'b1,1'b0,2'd2,1'b1};
            default:;
        endcase
        default:;
        endcase
    end
endfunction
wire [5:0] mbtype_match=match_b_mbtype(mbtype_bits_next,mbtype_len_next);

function automatic [6:0] match_motion_code;
    input [10:0] bits; input [3:0] len; reg valid; reg signed [5:0] code;
    begin
        valid=0;code=0;
        case(len)
        4'd1:if(bits[0])begin valid=1;code=0;end
        4'd3:case(bits[2:0]) 3'b010:begin valid=1;code=1;end 3'b011:begin valid=1;code=-1;end default:;endcase
        4'd4:case(bits[3:0]) 4'b0010:begin valid=1;code=2;end 4'b0011:begin valid=1;code=-2;end default:;endcase
        4'd5:case(bits[4:0]) 5'b00010:begin valid=1;code=3;end 5'b00011:begin valid=1;code=-3;end default:;endcase
        4'd7:case(bits[6:0]) 7'b0000110:begin valid=1;code=4;end 7'b0000111:begin valid=1;code=-4;end default:;endcase
        4'd8:case(bits[7:0])
          8'b00001010:begin valid=1;code=5;end 8'b00001011:begin valid=1;code=-5;end
          8'b00001000:begin valid=1;code=6;end 8'b00001001:begin valid=1;code=-6;end
          8'b00000110:begin valid=1;code=7;end 8'b00000111:begin valid=1;code=-7;end default:;endcase
        4'd10:case(bits[9:0])
          10'b0000010110:begin valid=1;code=8;end 10'b0000010111:begin valid=1;code=-8;end
          10'b0000010100:begin valid=1;code=9;end 10'b0000010101:begin valid=1;code=-9;end
          10'b0000010010:begin valid=1;code=10;end 10'b0000010011:begin valid=1;code=-10;end default:;endcase
        4'd11:case(bits[10:0])
          11'b00000100010:begin valid=1;code=11;end 11'b00000100011:begin valid=1;code=-11;end
          11'b00000100000:begin valid=1;code=12;end 11'b00000100001:begin valid=1;code=-12;end
          11'b00000011110:begin valid=1;code=13;end 11'b00000011111:begin valid=1;code=-13;end
          11'b00000011100:begin valid=1;code=14;end 11'b00000011101:begin valid=1;code=-14;end
          11'b00000011010:begin valid=1;code=15;end 11'b00000011011:begin valid=1;code=-15;end
          11'b00000011000:begin valid=1;code=16;end 11'b00000011001:begin valid=1;code=-16;end default:;endcase
