//============================================================================
// MiSTer Media Player - syntax-derived aligned H.262 P motion-plan observer
//
// Standards authority: core-standards.md, source_id H262.
// Relevant records: H262-009, H262-011, H262-012, H262-014, H262-015,
// H262-016 and H262-017.
//
// Phase 1U-q removes the fixed per-row payload/map requirement from the aligned
// P path. Each 128x96 slice row is buffered to its following start code, input
// is held, and the row is parsed one bit per decoder clock. The parser decodes
// full Table B.1 macroblock_address_increment (including escape accumulation),
// recognizes Table B.3 motion-forward-only macroblocks, and derives skipped
// macroblocks from address gaps. Horizontal forward motion is intentionally the
// already-proven execution subset: motion_code 0 or the controlled f_code=3
// +8/residual=3 reconstruction to +32. A skipped P macroblock resets the PMV;
// motion_code 0 therefore preserves the current 0/+32 predictor. The resulting
// 48-position shift-right plan is built from decoded syntax, not a known byte
// pattern. The executor remains the accepted aligned 0/+32 raster engine.
//============================================================================
module mpeg2_h262_p_aligned_motion_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    output reg        aligned_candidate,
    output reg        aligned_seen,
    output reg        aligned_complete_now,
    output reg [47:0] aligned_shift_right_map,
    output reg        parse_hold,
    output reg        probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    SEQUENCE_HEADER_CODE = 8'hB3,
    EXTENSION_START_CODE = 8'hB5;
localparam integer ROW_BUFFER_BYTES = 100;
localparam [5:0] MB_WIDTH = 6'd8;
localparam [5:0] MB_HEIGHT = 6'd6;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire start_code_now = (byte_window_next[31:8] == 24'h000001);
wire [7:0] start_code_value = byte_window_next[7:0];
wire slice_start_now = start_code_now && (start_code_value >= 8'h01) &&
                       (start_code_value <= 8'hAF);
wire post_p_boundary_now = start_code_now &&
    ((start_code_value == PICTURE_START_CODE) ||
     (start_code_value == SEQUENCE_HEADER_CODE));

reg sequence_capture;
reg [1:0] sequence_count;
reg [23:0] sequence_shift;
wire [23:0] sequence_next = {sequence_shift[15:0], stream_data};
reg geometry_128x96;

reg picture_capture;
reg picture_count;
reg [15:0] picture_shift;
wire [15:0] picture_next = {picture_shift[7:0], stream_data};
reg current_picture_is_p;

reg pce_capture;
reg [2:0] pce_count;
reg [39:0] pce_shift;
wire [39:0] pce_next = {pce_shift[31:0], stream_data};

reg [7:0] row_bytes [0:ROW_BUFFER_BYTES-1];
reg slice_capture;
reg [5:0] slice_row_number;
reg [6:0] row_byte_count;
reg proof_done;
reg parse_active;
reg boundary_final;
reg final_release_pending;
reg [6:0] parse_byte_limit;
reg [6:0] parse_byte_index;
reg [2:0] parse_bit_index;
wire parser_at_end = (parse_byte_index >= parse_byte_limit);
wire parser_current_bit = row_bytes[parse_byte_index][parse_bit_index];

localparam [3:0]
    R_HEADER       = 4'd0,
    R_MBA          = 4'd1,
    R_APPLY        = 4'd2,
    R_MBTYPE0      = 4'd3,
    R_MBTYPE1      = 4'd4,
    R_MBTYPE2      = 4'd5,
    R_MOTION_X     = 4'd6,
    R_MOTION_X_R0  = 4'd7,
    R_MOTION_X_R1  = 4'd8,
    R_MOTION_Y     = 4'd9,
    R_STUFF        = 4'd10,
    R_SUCCESS      = 4'd11,
    R_ERROR        = 4'd12;
reg [3:0] parser_state;
reg [2:0] header_bit_index;
reg [10:0] mba_vlc_bits;
reg [3:0] mba_vlc_len;
reg [9:0] mba_escape_accum;
reg [9:0] mba_increment;
reg signed [7:0] previous_col;
reg [5:0] current_col;
reg row_has_coded_mb;
reg predictor_shift_right;
reg current_motion_shift_right;
reg [9:0] motion_vlc_bits;
reg [3:0] motion_vlc_len;
reg map_has_motion;

wire parser_state_consumes_bit =
    (parser_state == R_HEADER)      || (parser_state == R_MBA) ||
    (parser_state == R_MBTYPE0)     || (parser_state == R_MBTYPE1) ||
    (parser_state == R_MBTYPE2)     || (parser_state == R_MOTION_X) ||
    (parser_state == R_MOTION_X_R0) || (parser_state == R_MOTION_X_R1) ||
    (parser_state == R_MOTION_Y)    || (parser_state == R_STUFF);
wire parser_consume_bit = parse_active && parser_state_consumes_bit && !parser_at_end;
wire [10:0] mba_vlc_bits_next = {mba_vlc_bits[9:0], parser_current_bit};
wire [3:0] mba_vlc_len_next = mba_vlc_len + 4'd1;
wire [9:0] motion_vlc_bits_next = {motion_vlc_bits[8:0], parser_current_bit};
wire [3:0] motion_vlc_len_next = motion_vlc_len + 4'd1;
wire signed [10:0] next_col_calc = $signed(previous_col) + $signed({1'b0,mba_increment});
wire [5:0] current_map_index = ((slice_row_number - 6'd1) << 3) + current_col;

function automatic [6:0] match_mba_code;
    input [10:0] bits;
    input [3:0] len;
    reg valid; reg [5:0] value;
    begin
        valid=1'b0; value=6'd0;
        case(len)
            4'd1: if(bits[0]) begin valid=1'b1;value=6'd1;end
            4'd3: case(bits[2:0]) 3'b011:begin valid=1'b1;value=6'd2;end 3'b010:begin valid=1'b1;value=6'd3;end default:; endcase
            4'd4: case(bits[3:0]) 4'b0011:begin valid=1'b1;value=6'd4;end 4'b0010:begin valid=1'b1;value=6'd5;end default:; endcase
            4'd5: case(bits[4:0]) 5'b00011:begin valid=1'b1;value=6'd6;end 5'b00010:begin valid=1'b1;value=6'd7;end default:; endcase
            4'd7: case(bits[6:0]) 7'b0000111:begin valid=1'b1;value=6'd8;end 7'b0000110:begin valid=1'b1;value=6'd9;end default:; endcase
            4'd8: case(bits[7:0])
                8'b00001011:begin valid=1'b1;value=6'd10;end 8'b00001010:begin valid=1'b1;value=6'd11;end
                8'b00001001:begin valid=1'b1;value=6'd12;end 8'b00001000:begin valid=1'b1;value=6'd13;end
                8'b00000111:begin valid=1'b1;value=6'd14;end 8'b00000110:begin valid=1'b1;value=6'd15;end default:; endcase
            4'd10: case(bits[9:0])
                10'b0000010111:begin valid=1'b1;value=6'd16;end 10'b0000010110:begin valid=1'b1;value=6'd17;end
                10'b0000010101:begin valid=1'b1;value=6'd18;end 10'b0000010100:begin valid=1'b1;value=6'd19;end
                10'b0000010011:begin valid=1'b1;value=6'd20;end 10'b0000010010:begin valid=1'b1;value=6'd21;end default:; endcase
            4'd11: case(bits[10:0])
                11'b00000100011:begin valid=1'b1;value=6'd22;end 11'b00000100010:begin valid=1'b1;value=6'd23;end
                11'b00000100001:begin valid=1'b1;value=6'd24;end 11'b00000100000:begin valid=1'b1;value=6'd25;end
                11'b00000011111:begin valid=1'b1;value=6'd26;end 11'b00000011110:begin valid=1'b1;value=6'd27;end
                11'b00000011101:begin valid=1'b1;value=6'd28;end 11'b00000011100:begin valid=1'b1;value=6'd29;end
                11'b00000011011:begin valid=1'b1;value=6'd30;end 11'b00000011010:begin valid=1'b1;value=6'd31;end
                11'b00000011001:begin valid=1'b1;value=6'd32;end 11'b00000011000:begin valid=1'b1;value=6'd33;end default:; endcase
            default:;
        endcase
        match_mba_code={valid,value};
    end
endfunction
wire [6:0] mba_match = match_mba_code(mba_vlc_bits_next,mba_vlc_len_next);
wire mba_escape_match=(mba_vlc_len_next==4'd11)&&(mba_vlc_bits_next==11'b00000001000);

always @(posedge clk) begin
    if(reset) begin
        byte_window<=0; sequence_capture<=0; sequence_count<=0; sequence_shift<=0; geometry_128x96<=0;
        picture_capture<=0; picture_count<=0; picture_shift<=0; current_picture_is_p<=0;
        pce_capture<=0; pce_count<=0; pce_shift<=0;
        aligned_candidate<=0; aligned_seen<=0; aligned_complete_now<=0; aligned_shift_right_map<=0;
        parse_hold<=0; probe_error<=0; slice_capture<=0; slice_row_number<=0; row_byte_count<=0;
        proof_done<=0; parse_active<=0; boundary_final<=0; final_release_pending<=0;
        parse_byte_limit<=0; parse_byte_index<=0; parse_bit_index<=3'd7; parser_state<=R_HEADER;
        header_bit_index<=0; mba_vlc_bits<=0; mba_vlc_len<=0; mba_escape_accum<=0; mba_increment<=0;
        previous_col<=-8'sd1; current_col<=0; row_has_coded_mb<=0; predictor_shift_right<=0;
        current_motion_shift_right<=0; motion_vlc_bits<=0; motion_vlc_len<=0; map_has_motion<=0;
    end else begin
        aligned_complete_now<=0;
        if(final_release_pending) begin parse_hold<=0; final_release_pending<=0; end

        if(parse_active) begin
            if(parser_consume_bit) begin
                if(parse_bit_index==0) begin parse_bit_index<=3'd7; parse_byte_index<=parse_byte_index+1'b1; end
                else parse_bit_index<=parse_bit_index-1'b1;
            end
            case(parser_state)
                R_HEADER: begin
                    if(parser_at_end) parser_state<=R_ERROR;
                    else if(parser_current_bit != ((header_bit_index==3'd3)?1'b1:1'b0)) parser_state<=R_ERROR;
                    else if(header_bit_index==3'd5) begin
                        header_bit_index<=0; mba_vlc_bits<=0; mba_vlc_len<=0; mba_escape_accum<=0; parser_state<=R_MBA;
                    end else header_bit_index<=header_bit_index+1'b1;
                end
                R_MBA: begin
                    if(parser_at_end) parser_state<=R_ERROR;
                    else if(mba_escape_match) begin
                        if(mba_escape_accum>10'd957) parser_state<=R_ERROR;
                        else begin mba_escape_accum<=mba_escape_accum+10'd33; mba_vlc_bits<=0; mba_vlc_len<=0; end
                    end else if(mba_match[6]) begin
                        mba_increment<=mba_escape_accum+{4'd0,mba_match[5:0]}; mba_vlc_bits<=0; mba_vlc_len<=0; mba_escape_accum<=0; parser_state<=R_APPLY;
                    end else if(mba_vlc_len_next==4'd11) parser_state<=R_ERROR;
                    else begin mba_vlc_bits<=mba_vlc_bits_next; mba_vlc_len<=mba_vlc_len_next; end
                end
                R_APPLY: begin
                    if((mba_increment==0)||(!row_has_coded_mb&&(mba_increment!=1))||
                       (next_col_calc<0)||(next_col_calc>=$signed({1'b0,MB_WIDTH}))) parser_state<=R_ERROR;
                    else begin
                        if(row_has_coded_mb&&(mba_increment>1)) predictor_shift_right<=0;
                        previous_col<=next_col_calc[7:0]; current_col<=next_col_calc[5:0]; parser_state<=R_MBTYPE0;
                    end
                end
                R_MBTYPE0: if(parser_at_end||parser_current_bit!=0) parser_state<=R_ERROR; else parser_state<=R_MBTYPE1;
                R_MBTYPE1: if(parser_at_end||parser_current_bit!=0) parser_state<=R_ERROR; else parser_state<=R_MBTYPE2;
                R_MBTYPE2: begin
                    if(parser_at_end||parser_current_bit!=1) parser_state<=R_ERROR;
                    else begin motion_vlc_bits<=0;motion_vlc_len<=0;current_motion_shift_right<=0;parser_state<=R_MOTION_X;end
                end
                R_MOTION_X: begin
                    if(parser_at_end) parser_state<=R_ERROR;
                    else if((motion_vlc_len==0)&&parser_current_bit) begin
                        current_motion_shift_right<=predictor_shift_right; parser_state<=R_MOTION_Y;
                    end else if(motion_vlc_len_next==4'd10) begin
                        if((motion_vlc_bits_next==10'b0000010110)&&!predictor_shift_right) parser_state<=R_MOTION_X_R0;
                        else parser_state<=R_ERROR;
                        motion_vlc_bits<=0;motion_vlc_len<=0;
                    end else begin motion_vlc_bits<=motion_vlc_bits_next;motion_vlc_len<=motion_vlc_len_next;end
                end
                R_MOTION_X_R0: if(parser_at_end||!parser_current_bit) parser_state<=R_ERROR; else parser_state<=R_MOTION_X_R1;
                R_MOTION_X_R1: begin
                    if(parser_at_end||!parser_current_bit) parser_state<=R_ERROR;
                    else begin current_motion_shift_right<=1; parser_state<=R_MOTION_Y; end
                end
                R_MOTION_Y: begin
                    if(parser_at_end||!parser_current_bit) parser_state<=R_ERROR;
                    else begin
                        row_has_coded_mb<=1; predictor_shift_right<=current_motion_shift_right;
                        if(current_motion_shift_right) begin aligned_shift_right_map[current_map_index]<=1'b1; map_has_motion<=1'b1; end
                        if(current_col==(MB_WIDTH-1'b1)) parser_state<=R_STUFF;
                        else begin mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;parser_state<=R_MBA;end
                    end
                end
                R_STUFF: begin
                    if(parser_at_end) parser_state<=R_SUCCESS;
                    else if(parser_current_bit) parser_state<=R_ERROR;
                end
                R_SUCCESS: begin
                    parse_active<=0;
                    if(!row_has_coded_mb||(current_col!=(MB_WIDTH-1'b1))) begin probe_error<=1;proof_done<=1;parse_hold<=0;end
                    else if(boundary_final) begin
                        if(!map_has_motion) begin probe_error<=1;parse_hold<=0;proof_done<=1;end
                        else begin aligned_seen<=1;aligned_complete_now<=1;proof_done<=1;final_release_pending<=1;end
                    end else begin
                        slice_row_number<=slice_row_number+1'b1;row_byte_count<=0;slice_capture<=1;parse_hold<=0;
                    end
                end
                default: begin parse_active<=0;parse_hold<=0;proof_done<=1;probe_error<=1;aligned_candidate<=0;end
            endcase
        end

        if(stream_valid) begin
            byte_window<=byte_window_next;
            if(sequence_capture) begin
                sequence_shift<=sequence_next;
                if(sequence_count==2) begin sequence_capture<=0;sequence_count<=0;geometry_128x96<=(sequence_next[23:12]==12'd128)&&(sequence_next[11:0]==12'd96);end
                else sequence_count<=sequence_count+1'b1;
            end else if(start_code_now&&(start_code_value==SEQUENCE_HEADER_CODE)) begin sequence_capture<=1;sequence_count<=0;sequence_shift<=0;end

            if(picture_capture) begin
                picture_shift<=picture_next;
                if(picture_count) begin
                    picture_capture<=0;picture_count<=0;current_picture_is_p<=(picture_next[5:3]==3'd2);
                    if(aligned_seen&&(picture_next[5:3]==3'd2)) begin
                        aligned_candidate<=1;aligned_seen<=0;aligned_shift_right_map<=0;slice_capture<=0;slice_row_number<=0;row_byte_count<=0;
                        proof_done<=0;parse_active<=0;parse_hold<=0;map_has_motion<=0;predictor_shift_right<=0;
                    end else aligned_candidate<=0;
                end else picture_count<=1;
            end else if(start_code_now&&(start_code_value==PICTURE_START_CODE)) begin picture_capture<=1;picture_count<=0;picture_shift<=0;end

            if(pce_capture) begin
                pce_shift<=pce_next;
                if(pce_count==4) begin
                    pce_capture<=0;pce_count<=0;
                    aligned_candidate<=geometry_128x96&&current_picture_is_p&&
                        (pce_next[39:36]==4'h8)&&(pce_next[35:32]==4'd3)&&(pce_next[31:28]==4'd3)&&
                        (pce_next[17:16]==2'b11)&&pce_next[14]&&!pce_next[13]&&!pce_next[12]&&!pce_next[10];
                end else pce_count<=pce_count+1'b1;
            end else if(current_picture_is_p&&start_code_now&&(start_code_value==EXTENSION_START_CODE)) begin pce_capture<=1;pce_count<=0;pce_shift<=0;end

            if(!parse_active&&!proof_done&&slice_capture) begin
                if(start_code_now) begin
                    if(row_byte_count<3) begin slice_capture<=0;proof_done<=1;probe_error<=1;end
                    else if(slice_row_number<MB_HEIGHT) begin
                        if(start_code_value==({2'd0,slice_row_number}+8'd1)) begin
                            slice_capture<=0;parse_active<=1;parse_hold<=1;boundary_final<=0;parse_byte_limit<=row_byte_count-3;
                            parse_byte_index<=0;parse_bit_index<=3'd7;parser_state<=R_HEADER;header_bit_index<=0;
                            mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;mba_increment<=0;previous_col<=-8'sd1;
                            current_col<=0;row_has_coded_mb<=0;predictor_shift_right<=0;current_motion_shift_right<=0;motion_vlc_bits<=0;motion_vlc_len<=0;
                        end else begin slice_capture<=0;proof_done<=1;probe_error<=1;end
                    end else if(post_p_boundary_now) begin
                        slice_capture<=0;parse_active<=1;parse_hold<=1;boundary_final<=1;parse_byte_limit<=row_byte_count-3;
                        parse_byte_index<=0;parse_bit_index<=3'd7;parser_state<=R_HEADER;header_bit_index<=0;
                        mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;mba_increment<=0;previous_col<=-8'sd1;
                        current_col<=0;row_has_coded_mb<=0;predictor_shift_right<=0;current_motion_shift_right<=0;motion_vlc_bits<=0;motion_vlc_len<=0;
                    end else begin slice_capture<=0;proof_done<=1;probe_error<=1;end
                end else if(row_byte_count<ROW_BUFFER_BYTES) begin row_bytes[row_byte_count]<=stream_data;row_byte_count<=row_byte_count+1'b1;end
                else begin slice_capture<=0;proof_done<=1;probe_error<=1;end
            end else if(!parse_active&&!proof_done&&aligned_candidate&&slice_start_now) begin
                if(start_code_value==8'h01) begin slice_capture<=1;slice_row_number<=1;row_byte_count<=0;aligned_shift_right_map<=0;map_has_motion<=0;end
                else begin proof_done<=1;probe_error<=1;end
            end
        end
    end
end
endmodule
