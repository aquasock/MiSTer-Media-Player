//============================================================================
// MiSTer Media Player - syntax-derived H.262 P motion/residual raster observer
//
// Standards authority: core-standards.md, source_id H262.
// Relevant records: H262-006, H262-009, H262-011, H262-014..H262-021.
// Table B.9 coded_block_pattern values are decoded from the official H.262 text.
//
// Controlled execution subset:
//   * 128x96 progressive 4:2:0 frame pictures, forward f_code=(3,3)
//   * Table B.3 motion-forward-only (001) and MC+Coded (1) macroblock types
//   * Table B.1 macroblock address progression, including skipped P macroblocks
//   * horizontal motion reconstructed as zero or the proven +32 half-sample case
//   * vertical motion zero
//   * full 4:2:0 Table B.9 coded_block_pattern decoding
//   * coded residual blocks restricted to the proven run=0, level=+7, EOB shape
//
// Up to sixteen coded residual blocks may be scheduled per picture.  That is a
// diagnostic implementation limit, not an H.262 limit.
//============================================================================
module mpeg2_h262_p_aligned_motion_syntax_probe
(
    input  wire         clk,
    input  wire         reset,
    input  wire [7:0]   stream_data,
    input  wire         stream_valid,
    output reg          aligned_candidate,
    output reg          aligned_seen,
    output reg          aligned_complete_now,
    output reg [47:0]   aligned_shift_right_map,
    output reg [287:0]  residual_block_plan,
    output reg [4:0]    residual_block_count,
    output reg          residual_present,
    output reg          parse_hold,
    output reg          probe_error
);

localparam [7:0] PICTURE_START_CODE=8'h00,SEQUENCE_HEADER_CODE=8'hB3,EXTENSION_START_CODE=8'hB5;
localparam integer ROW_BUFFER_BYTES=128;
localparam [5:0] MB_WIDTH=6'd8,MB_HEIGHT=6'd6;
localparam [4:0] MAX_RESIDUAL_BLOCKS=5'd16;
localparam [12:0] CONTROLLED_COEFF_BITS=13'b0000001010010;

reg [31:0] byte_window;
wire [31:0] byte_window_next={byte_window[23:0],stream_data};
wire start_code_now=(byte_window_next[31:8]==24'h000001);
wire [7:0] start_code_value=byte_window_next[7:0];
wire slice_start_now=start_code_now&&(start_code_value>=8'h01)&&(start_code_value<=8'hAF);
wire post_p_boundary_now=start_code_now&&((start_code_value==PICTURE_START_CODE)||(start_code_value==SEQUENCE_HEADER_CODE));

reg sequence_capture;reg [1:0] sequence_count;reg [23:0] sequence_shift;
wire [23:0] sequence_next={sequence_shift[15:0],stream_data};
reg geometry_128x96;
reg picture_capture;reg picture_count;reg [15:0] picture_shift;
wire [15:0] picture_next={picture_shift[7:0],stream_data};
reg current_picture_is_p;
reg pce_capture;reg [2:0] pce_count;reg [39:0] pce_shift;
wire [39:0] pce_next={pce_shift[31:0],stream_data};

reg [7:0] row_bytes[0:ROW_BUFFER_BYTES-1];
reg slice_capture;reg [5:0] slice_row_number;reg [7:0] row_byte_count;
reg proof_done,parse_active,boundary_final,final_release_pending;
reg [7:0] parse_byte_limit,parse_byte_index;reg [2:0] parse_bit_index;
wire parser_at_end=(parse_byte_index>=parse_byte_limit);
wire parser_current_bit=row_bytes[parse_byte_index][parse_bit_index];

localparam [4:0]
 R_HEADER=5'd0,R_MBA=5'd1,R_APPLY=5'd2,R_MBTYPE0=5'd3,R_MBTYPE1=5'd4,R_MBTYPE2=5'd5,
 R_MOTION_X=5'd6,R_MOTION_X_R0=5'd7,R_MOTION_X_R1=5'd8,R_MOTION_Y=5'd9,R_CBP=5'd10,
 R_BLOCK=5'd11,R_COEFF=5'd12,R_MB_DONE=5'd13,R_STUFF=5'd14,R_SUCCESS=5'd15,R_ERROR=5'd16;
reg [4:0] parser_state;
reg [2:0] header_bit_index;
reg [10:0] mba_vlc_bits;reg [3:0] mba_vlc_len;reg [9:0] mba_escape_accum,mba_increment;
reg signed [7:0] previous_col;reg [5:0] current_col;reg row_has_coded_mb;
reg predictor_shift_right,current_motion_shift_right,current_has_pattern,map_has_motion;
reg [9:0] motion_vlc_bits;reg [3:0] motion_vlc_len;
reg [8:0] cbp_vlc_bits;reg [3:0] cbp_vlc_len;reg [5:0] current_cbp;
reg [2:0] current_block_index;reg [3:0] coeff_bit_index;

wire parser_state_consumes_bit=(parser_state==R_HEADER)||(parser_state==R_MBA)||(parser_state==R_MBTYPE0)||
 (parser_state==R_MBTYPE1)||(parser_state==R_MBTYPE2)||(parser_state==R_MOTION_X)||
 (parser_state==R_MOTION_X_R0)||(parser_state==R_MOTION_X_R1)||(parser_state==R_MOTION_Y)||
 (parser_state==R_CBP)||(parser_state==R_COEFF)||(parser_state==R_STUFF);
wire parser_consume_bit=parse_active&&parser_state_consumes_bit&&!parser_at_end;
wire [10:0] mba_vlc_bits_next={mba_vlc_bits[9:0],parser_current_bit};
wire [3:0] mba_vlc_len_next=mba_vlc_len+4'd1;
wire [9:0] motion_vlc_bits_next={motion_vlc_bits[8:0],parser_current_bit};
wire [3:0] motion_vlc_len_next=motion_vlc_len+4'd1;
wire [8:0] cbp_vlc_bits_next={cbp_vlc_bits[7:0],parser_current_bit};
wire [3:0] cbp_vlc_len_next=cbp_vlc_len+4'd1;
wire signed [10:0] next_col_calc=$signed(previous_col)+$signed({1'b0,mba_increment});
wire [5:0] current_map_index=((slice_row_number-6'd1)<<3)+current_col;
wire [8:0] current_plan_index=({3'd0,current_map_index}*9'd6)+{6'd0,current_block_index};

function automatic [6:0] match_mba_code;
 input [10:0] bits;input [3:0] len;reg valid;reg [5:0] value;
 begin valid=0;value=0;case(len)
 4'd1:if(bits[0])begin valid=1;value=1;end
 4'd3:case(bits[2:0])3'b011:begin valid=1;value=2;end 3'b010:begin valid=1;value=3;end default:;endcase
 4'd4:case(bits[3:0])4'b0011:begin valid=1;value=4;end 4'b0010:begin valid=1;value=5;end default:;endcase
 4'd5:case(bits[4:0])5'b00011:begin valid=1;value=6;end 5'b00010:begin valid=1;value=7;end default:;endcase
 4'd7:case(bits[6:0])7'b0000111:begin valid=1;value=8;end 7'b0000110:begin valid=1;value=9;end default:;endcase
 4'd8:case(bits[7:0])8'b00001011:begin valid=1;value=10;end 8'b00001010:begin valid=1;value=11;end
  8'b00001001:begin valid=1;value=12;end 8'b00001000:begin valid=1;value=13;end 8'b00000111:begin valid=1;value=14;end
  8'b00000110:begin valid=1;value=15;end default:;endcase
 4'd10:case(bits[9:0])10'b0000010111:begin valid=1;value=16;end 10'b0000010110:begin valid=1;value=17;end
  10'b0000010101:begin valid=1;value=18;end 10'b0000010100:begin valid=1;value=19;end 10'b0000010011:begin valid=1;value=20;end
  10'b0000010010:begin valid=1;value=21;end default:;endcase
 4'd11:case(bits[10:0])
  11'b00000100011:begin valid=1;value=22;end 11'b00000100010:begin valid=1;value=23;end
  11'b00000100001:begin valid=1;value=24;end 11'b00000100000:begin valid=1;value=25;end
  11'b00000011111:begin valid=1;value=26;end 11'b00000011110:begin valid=1;value=27;end
  11'b00000011101:begin valid=1;value=28;end 11'b00000011100:begin valid=1;value=29;end
  11'b00000011011:begin valid=1;value=30;end 11'b00000011010:begin valid=1;value=31;end
  11'b00000011001:begin valid=1;value=32;end 11'b00000011000:begin valid=1;value=33;end default:;endcase
 default:;endcase match_mba_code={valid,value};end
endfunction
wire [6:0] mba_match=match_mba_code(mba_vlc_bits_next,mba_vlc_len_next);
wire mba_escape_match=(mba_vlc_len_next==4'd11)&&(mba_vlc_bits_next==11'b00000001000);

function automatic [6:0] match_cbp_code;
 input [8:0] bits;input [3:0] len;reg valid;reg [5:0] value;
 begin valid=0;value=0;case(len)
 4'd3:case(bits[2:0])3'b111:begin valid=1;value=60;end default:;endcase
 4'd4:case(bits[3:0])4'b1010:begin valid=1;value=32;end 4'b1011:begin valid=1;value=16;end 4'b1100:begin valid=1;value=8;end 4'b1101:begin valid=1;value=4;end default:;endcase
 4'd5:case(bits[4:0])5'b01000:begin valid=1;value=62;end 5'b01001:begin valid=1;value=2;end 5'b01010:begin valid=1;value=61;end 5'b01011:begin valid=1;value=1;end
  5'b01100:begin valid=1;value=56;end 5'b01101:begin valid=1;value=52;end 5'b01110:begin valid=1;value=44;end 5'b01111:begin valid=1;value=28;end
  5'b10000:begin valid=1;value=40;end 5'b10001:begin valid=1;value=20;end 5'b10010:begin valid=1;value=48;end 5'b10011:begin valid=1;value=12;end default:;endcase
 4'd6:case(bits[5:0])6'b001100:begin valid=1;value=63;end 6'b001101:begin valid=1;value=3;end 6'b001110:begin valid=1;value=36;end 6'b001111:begin valid=1;value=24;end default:;endcase
 4'd7:case(bits[6:0])7'b0010000:begin valid=1;value=34;end 7'b0010001:begin valid=1;value=18;end 7'b0010010:begin valid=1;value=10;end 7'b0010011:begin valid=1;value=6;end
  7'b0010100:begin valid=1;value=33;end 7'b0010101:begin valid=1;value=17;end 7'b0010110:begin valid=1;value=9;end 7'b0010111:begin valid=1;value=5;end default:;endcase
 4'd8:case(bits[7:0])8'b00000100:begin valid=1;value=58;end 8'b00000101:begin valid=1;value=54;end 8'b00000110:begin valid=1;value=46;end 8'b00000111:begin valid=1;value=30;end
  8'b00001000:begin valid=1;value=57;end 8'b00001001:begin valid=1;value=53;end 8'b00001010:begin valid=1;value=45;end 8'b00001011:begin valid=1;value=29;end
  8'b00001100:begin valid=1;value=38;end 8'b00001101:begin valid=1;value=26;end 8'b00001110:begin valid=1;value=37;end 8'b00001111:begin valid=1;value=25;end
  8'b00010000:begin valid=1;value=43;end 8'b00010001:begin valid=1;value=23;end 8'b00010010:begin valid=1;value=51;end 8'b00010011:begin valid=1;value=15;end
  8'b00010100:begin valid=1;value=42;end 8'b00010101:begin valid=1;value=22;end 8'b00010110:begin valid=1;value=50;end 8'b00010111:begin valid=1;value=14;end
  8'b00011000:begin valid=1;value=41;end 8'b00011001:begin valid=1;value=21;end 8'b00011010:begin valid=1;value=49;end 8'b00011011:begin valid=1;value=13;end
  8'b00011100:begin valid=1;value=35;end 8'b00011101:begin valid=1;value=19;end 8'b00011110:begin valid=1;value=11;end 8'b00011111:begin valid=1;value=7;end default:;endcase
 4'd9:case(bits[8:0])9'b000000010:begin valid=1;value=39;end 9'b000000011:begin valid=1;value=27;end 9'b000000100:begin valid=1;value=59;end
  9'b000000101:begin valid=1;value=55;end 9'b000000110:begin valid=1;value=47;end 9'b000000111:begin valid=1;value=31;end default:;endcase
 default:;endcase match_cbp_code={valid,value};end
endfunction
wire [6:0] cbp_match=match_cbp_code(cbp_vlc_bits_next,cbp_vlc_len_next);

always @(posedge clk) begin
 if(reset)begin
  byte_window<=0;sequence_capture<=0;sequence_count<=0;sequence_shift<=0;geometry_128x96<=0;
  picture_capture<=0;picture_count<=0;picture_shift<=0;current_picture_is_p<=0;pce_capture<=0;pce_count<=0;pce_shift<=0;
  aligned_candidate<=0;aligned_seen<=0;aligned_complete_now<=0;aligned_shift_right_map<=0;residual_block_plan<=0;residual_block_count<=0;residual_present<=0;
  parse_hold<=0;probe_error<=0;slice_capture<=0;slice_row_number<=0;row_byte_count<=0;proof_done<=0;parse_active<=0;boundary_final<=0;final_release_pending<=0;
  parse_byte_limit<=0;parse_byte_index<=0;parse_bit_index<=3'd7;parser_state<=R_HEADER;header_bit_index<=0;
  mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;mba_increment<=0;previous_col<=-8'sd1;current_col<=0;row_has_coded_mb<=0;
  predictor_shift_right<=0;current_motion_shift_right<=0;current_has_pattern<=0;map_has_motion<=0;motion_vlc_bits<=0;motion_vlc_len<=0;
  cbp_vlc_bits<=0;cbp_vlc_len<=0;current_cbp<=0;current_block_index<=0;coeff_bit_index<=0;
 end else begin
  aligned_complete_now<=0;
  if(final_release_pending)begin parse_hold<=0;final_release_pending<=0;end
  if(parse_active)begin
   if(parser_consume_bit)begin if(parse_bit_index==0)begin parse_bit_index<=3'd7;parse_byte_index<=parse_byte_index+1'b1;end else parse_bit_index<=parse_bit_index-1'b1;end
   case(parser_state)
    R_HEADER:begin if(parser_at_end)parser_state<=R_ERROR;else if(parser_current_bit!=((header_bit_index==3)?1'b1:1'b0))parser_state<=R_ERROR;
     else if(header_bit_index==5)begin header_bit_index<=0;mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;parser_state<=R_MBA;end else header_bit_index<=header_bit_index+1'b1;end
    R_MBA:begin if(parser_at_end)parser_state<=R_ERROR;else if(mba_escape_match)begin if(mba_escape_accum>957)parser_state<=R_ERROR;
     else begin mba_escape_accum<=mba_escape_accum+33;mba_vlc_bits<=0;mba_vlc_len<=0;end end
     else if(mba_match[6])begin mba_increment<=mba_escape_accum+{4'd0,mba_match[5:0]};mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;parser_state<=R_APPLY;end
     else if(mba_vlc_len_next==11)parser_state<=R_ERROR;else begin mba_vlc_bits<=mba_vlc_bits_next;mba_vlc_len<=mba_vlc_len_next;end end
    R_APPLY:begin if((mba_increment==0)||(!row_has_coded_mb&&(mba_increment!=1))||(next_col_calc<0)||(next_col_calc>=$signed({1'b0,MB_WIDTH})))parser_state<=R_ERROR;
     else begin if(row_has_coded_mb&&(mba_increment>1))predictor_shift_right<=0;previous_col<=next_col_calc[7:0];current_col<=next_col_calc[5:0];current_has_pattern<=0;parser_state<=R_MBTYPE0;end end
    R_MBTYPE0:begin if(parser_at_end)parser_state<=R_ERROR;else if(parser_current_bit)begin current_has_pattern<=1;motion_vlc_bits<=0;motion_vlc_len<=0;current_motion_shift_right<=0;parser_state<=R_MOTION_X;end else parser_state<=R_MBTYPE1;end
    R_MBTYPE1:if(parser_at_end||parser_current_bit)parser_state<=R_ERROR;else parser_state<=R_MBTYPE2;
    R_MBTYPE2:begin if(parser_at_end||!parser_current_bit)parser_state<=R_ERROR;else begin current_has_pattern<=0;motion_vlc_bits<=0;motion_vlc_len<=0;current_motion_shift_right<=0;parser_state<=R_MOTION_X;end end
    R_MOTION_X:begin if(parser_at_end)parser_state<=R_ERROR;else if((motion_vlc_len==0)&&parser_current_bit)begin current_motion_shift_right<=predictor_shift_right;parser_state<=R_MOTION_Y;end
     else if(motion_vlc_len_next==10)begin if((motion_vlc_bits_next==10'b0000010110)&&!predictor_shift_right)parser_state<=R_MOTION_X_R0;else parser_state<=R_ERROR;motion_vlc_bits<=0;motion_vlc_len<=0;end
     else begin motion_vlc_bits<=motion_vlc_bits_next;motion_vlc_len<=motion_vlc_len_next;end end
    R_MOTION_X_R0:if(parser_at_end||!parser_current_bit)parser_state<=R_ERROR;else parser_state<=R_MOTION_X_R1;
    R_MOTION_X_R1:begin if(parser_at_end||!parser_current_bit)parser_state<=R_ERROR;else begin current_motion_shift_right<=1;parser_state<=R_MOTION_Y;end end
    R_MOTION_Y:begin if(parser_at_end||!parser_current_bit)parser_state<=R_ERROR;else if(current_has_pattern)begin cbp_vlc_bits<=0;cbp_vlc_len<=0;parser_state<=R_CBP;end else parser_state<=R_MB_DONE;end
    R_CBP:begin if(parser_at_end)parser_state<=R_ERROR;else if(cbp_match[6])begin current_cbp<=cbp_match[5:0];cbp_vlc_bits<=0;cbp_vlc_len<=0;current_block_index<=0;residual_present<=1;parser_state<=R_BLOCK;end
     else if(cbp_vlc_len_next==9)parser_state<=R_ERROR;else begin cbp_vlc_bits<=cbp_vlc_bits_next;cbp_vlc_len<=cbp_vlc_len_next;end end
    R_BLOCK:begin if(current_block_index==6)parser_state<=R_MB_DONE;else if(current_cbp[5-current_block_index])begin
      if(residual_block_count>=MAX_RESIDUAL_BLOCKS)parser_state<=R_ERROR;else begin residual_block_plan[current_plan_index]<=1;residual_block_count<=residual_block_count+1'b1;coeff_bit_index<=0;parser_state<=R_COEFF;end end
     else current_block_index<=current_block_index+1'b1;end
    R_COEFF:begin if(parser_at_end||parser_current_bit!=CONTROLLED_COEFF_BITS[12-coeff_bit_index])parser_state<=R_ERROR;
     else if(coeff_bit_index==12)begin current_block_index<=current_block_index+1'b1;coeff_bit_index<=0;parser_state<=R_BLOCK;end else coeff_bit_index<=coeff_bit_index+1'b1;end
    R_MB_DONE:begin row_has_coded_mb<=1;predictor_shift_right<=current_motion_shift_right;if(current_motion_shift_right)begin aligned_shift_right_map[current_map_index]<=1;map_has_motion<=1;end
     if(current_col==(MB_WIDTH-1'b1))parser_state<=R_STUFF;else begin mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;parser_state<=R_MBA;end end
    R_STUFF:begin if(parser_at_end)parser_state<=R_SUCCESS;else if(parser_current_bit)parser_state<=R_ERROR;end
    R_SUCCESS:begin parse_active<=0;if(!row_has_coded_mb||(current_col!=(MB_WIDTH-1'b1)))begin probe_error<=1;proof_done<=1;parse_hold<=0;end
     else if(boundary_final)begin if(!map_has_motion)begin probe_error<=1;parse_hold<=0;proof_done<=1;end else begin aligned_seen<=1;aligned_complete_now<=1;proof_done<=1;final_release_pending<=1;end end
     else begin slice_row_number<=slice_row_number+1'b1;row_byte_count<=0;slice_capture<=1;parse_hold<=0;end end
    default:begin parse_active<=0;parse_hold<=0;proof_done<=1;probe_error<=1;aligned_candidate<=0;end
   endcase
  end

  if(stream_valid)begin
   byte_window<=byte_window_next;
   if(sequence_capture)begin sequence_shift<=sequence_next;if(sequence_count==2)begin sequence_capture<=0;sequence_count<=0;geometry_128x96<=(sequence_next[23:12]==128)&&(sequence_next[11:0]==96);end else sequence_count<=sequence_count+1'b1;end
   else if(start_code_now&&(start_code_value==SEQUENCE_HEADER_CODE))begin sequence_capture<=1;sequence_count<=0;sequence_shift<=0;end
   if(picture_capture)begin picture_shift<=picture_next;if(picture_count)begin picture_capture<=0;picture_count<=0;current_picture_is_p<=(picture_next[5:3]==2);
     if(aligned_seen&&(picture_next[5:3]==2))begin aligned_candidate<=1;aligned_seen<=0;aligned_shift_right_map<=0;residual_block_plan<=0;residual_block_count<=0;residual_present<=0;
      slice_capture<=0;slice_row_number<=0;row_byte_count<=0;proof_done<=0;parse_active<=0;parse_hold<=0;map_has_motion<=0;predictor_shift_right<=0;end else aligned_candidate<=0;
    end else picture_count<=1;end else if(start_code_now&&(start_code_value==PICTURE_START_CODE))begin picture_capture<=1;picture_count<=0;picture_shift<=0;end
   if(pce_capture)begin pce_shift<=pce_next;if(pce_count==4)begin pce_capture<=0;pce_count<=0;aligned_candidate<=geometry_128x96&&current_picture_is_p&&
      (pce_next[39:36]==4'h8)&&(pce_next[35:32]==3)&&(pce_next[31:28]==3)&&(pce_next[17:16]==2'b11)&&pce_next[14]&&!pce_next[13]&&!pce_next[12]&&!pce_next[10];end else pce_count<=pce_count+1'b1;end
   else if(current_picture_is_p&&start_code_now&&(start_code_value==EXTENSION_START_CODE))begin pce_capture<=1;pce_count<=0;pce_shift<=0;end
   if(!parse_active&&!proof_done&&slice_capture)begin
    if(start_code_now)begin
     if(row_byte_count<3)begin slice_capture<=0;proof_done<=1;probe_error<=1;end
     else if(slice_row_number<MB_HEIGHT)begin if(start_code_value==({2'd0,slice_row_number}+8'd1))begin slice_capture<=0;parse_active<=1;parse_hold<=1;boundary_final<=0;parse_byte_limit<=row_byte_count-3;
       parse_byte_index<=0;parse_bit_index<=7;parser_state<=R_HEADER;header_bit_index<=0;mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;mba_increment<=0;previous_col<=-8'sd1;current_col<=0;row_has_coded_mb<=0;predictor_shift_right<=0;
       current_motion_shift_right<=0;motion_vlc_bits<=0;motion_vlc_len<=0;cbp_vlc_bits<=0;cbp_vlc_len<=0;current_cbp<=0;current_block_index<=0;coeff_bit_index<=0;end
      else begin slice_capture<=0;proof_done<=1;probe_error<=1;end end
     else if(post_p_boundary_now)begin slice_capture<=0;parse_active<=1;parse_hold<=1;boundary_final<=1;parse_byte_limit<=row_byte_count-3;parse_byte_index<=0;parse_bit_index<=7;parser_state<=R_HEADER;header_bit_index<=0;
       mba_vlc_bits<=0;mba_vlc_len<=0;mba_escape_accum<=0;mba_increment<=0;previous_col<=-8'sd1;current_col<=0;row_has_coded_mb<=0;predictor_shift_right<=0;current_motion_shift_right<=0;motion_vlc_bits<=0;motion_vlc_len<=0;
       cbp_vlc_bits<=0;cbp_vlc_len<=0;current_cbp<=0;current_block_index<=0;coeff_bit_index<=0;end
     else begin slice_capture<=0;proof_done<=1;probe_error<=1;end
    end else if(row_byte_count<ROW_BUFFER_BYTES)begin row_bytes[row_byte_count]<=stream_data;row_byte_count<=row_byte_count+1'b1;end else begin slice_capture<=0;proof_done<=1;probe_error<=1;end
   end else if(!parse_active&&!proof_done&&aligned_candidate&&slice_start_now)begin
    if(start_code_value==8'h01)begin slice_capture<=1;slice_row_number<=1;row_byte_count<=0;aligned_shift_right_map<=0;residual_block_plan<=0;residual_block_count<=0;residual_present<=0;map_has_motion<=0;end
    else begin proof_done<=1;probe_error<=1;end
   end
  end
 end
end
endmodule
