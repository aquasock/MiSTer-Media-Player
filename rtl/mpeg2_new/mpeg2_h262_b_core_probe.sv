//============================================================================
// MiSTer Media Player - controlled progressive 4:2:0 B-picture core probe
//
// Commit 128 / Phase 1V-a.  This is the first B-picture hardware boundary.
// It decodes a complete 128x96 progressive non-scalable B picture containing
// the six non-quantised non-intra Table-B.4 macroblock types used for forward,
// backward and bidirectional frame prediction.  Forward/backward f_code=(3,3)
// motion vectors are reconstructed independently.  Up to four coded Y0 blocks
// use the existing serialized non-intra IQ/IDCT engine.
//
// Diagnostic implementation limits (not H.262 limits): no skipped B MBs yet,
// MBA increment must be 1, coded B MBs use CBP=32 (Y0 only), and each coded
// block carries the controlled first coefficient +/-1 followed by EOB.
//============================================================================
module mpeg2_h262_b_core_probe
(
    input  wire clk,
    input  wire reset,
    input  wire [7:0] stream_data,
    input  wire stream_valid,

    output reg  b_candidate,
    output reg  b_seen,
    output reg  b_complete_now,
    output reg  parse_hold,

    output reg  replay_active,
    output reg  sideband_valid,
    output reg  [5:0] sideband_index,
    output reg  signed [15:0] sideband_value,
    output reg  first_sample_valid,
    output reg  signed [15:0] first_sample_value,
    output wire probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    SEQUENCE_HEADER_CODE = 8'hB3,
    EXTENSION_START_CODE = 8'hB5,
    SEQUENCE_END_CODE    = 8'hB7;
localparam integer ROW_BUFFER_BYTES = 128;
localparam [5:0] MB_WIDTH=6'd8, MB_HEIGHT=6'd6;
localparam [2:0] MAX_RESIDUAL_BLOCKS=3'd4;

reg [95:0] direction_plan;
reg [383:0] forward_x_plan, forward_y_plan;
reg [383:0] backward_x_plan, backward_y_plan;
reg [5:0] residual_mb [0:3];
reg [4:0] residual_qscale [0:3];
reg signed [12:0] residual_level [0:3];
reg [2:0] residual_count;
reg q_scale_type, alternate_scan;

reg parser_error, replay_error;
assign probe_error = parser_error | replay_error;

reg [31:0] byte_window;
wire [31:0] byte_window_next={byte_window[23:0],stream_data};
wire start_code_now=(byte_window_next[31:8]==24'h000001);
wire [7:0] start_code_value=byte_window_next[7:0];
wire slice_start_now=start_code_now&&(start_code_value>=8'h01)&&(start_code_value<=8'hAF);
wire post_b_boundary_now=start_code_now&&
    ((start_code_value==PICTURE_START_CODE)||(start_code_value==SEQUENCE_HEADER_CODE)||(start_code_value==SEQUENCE_END_CODE));

reg sequence_capture; reg [1:0] sequence_count; reg [23:0] sequence_shift;
wire [23:0] sequence_next={sequence_shift[15:0],stream_data};
reg geometry_128x96;

reg picture_capture,picture_count; reg [15:0] picture_shift;
wire [15:0] picture_next={picture_shift[7:0],stream_data};
reg current_picture_is_b;

reg pce_capture; reg [2:0] pce_count; reg [39:0] pce_shift;
wire [39:0] pce_next={pce_shift[31:0],stream_data};

reg [7:0] row_bytes [0:ROW_BUFFER_BYTES-1];
reg slice_capture; reg [5:0] slice_row_number; reg [7:0] row_byte_count;
reg parse_active,proof_done,boundary_final;
reg [7:0] parse_byte_limit,parse_byte_index; reg [2:0] parse_bit_index;
wire parser_at_end=(parse_byte_index>=parse_byte_limit);
wire parser_current_bit=row_bytes[parse_byte_index][parse_bit_index];

localparam [5:0]
    S_QSCALE=0,S_EXTRA_FLAG=1,S_EXTRA_INFO=2,S_MBA=3,S_MBTYPE=4,
    S_FX=5,S_FX_RES=6,S_FY=7,S_FY_RES=8,
    S_BX=9,S_BX_RES=10,S_BY=11,S_BY_RES=12,
    S_CBP=13,S_COEFF=14,S_MB_DONE=15,S_STUFF=16,S_SUCCESS=17,S_ERROR=18;
reg [5:0] state;

reg [2:0] field_bit_count; reg [4:0] qscale_shift,current_qscale; reg [3:0] extra_info_count;
reg [5:0] current_col; reg row_has_coded_mb;
reg [3:0] mbtype_bits; reg [2:0] mbtype_len; reg [1:0] current_direction; reg current_pattern;
reg signed [7:0] fpx,fpy,bpx,bpy,cur_fx,cur_fy,cur_bx,cur_by;
reg signed [5:0] motion_code_pending; reg [10:0] motion_bits; reg [3:0] motion_len;
reg [1:0] motion_residual_shift; reg motion_residual_count;
reg [3:0] cbp_bits; reg [2:0] cbp_len;
reg [3:0] coeff_bits; reg [2:0] coeff_len;

wire [4:0] qscale_next={qscale_shift[3:0],parser_current_bit};
wire [10:0] motion_bits_next={motion_bits[9:0],parser_current_bit};
wire [3:0] motion_len_next=motion_len+1'b1;
wire [1:0] motion_residual_next={motion_residual_shift[0],parser_current_bit};
wire [3:0] mbtype_bits_next={mbtype_bits[2:0],parser_current_bit};
wire [2:0] mbtype_len_next=mbtype_len+1'b1;
wire [3:0] cbp_bits_next={cbp_bits[2:0],parser_current_bit};
wire [2:0] cbp_len_next=cbp_len+1'b1;
wire [3:0] coeff_bits_next={coeff_bits[2:0],parser_current_bit};
wire [2:0] coeff_len_next=coeff_len+1'b1;
wire [5:0] current_map_index=((slice_row_number-1'b1)<<3)+current_col;

function automatic [3:0] match_b_mbtype;
    input [3:0] bits; input [2:0] len;
    begin
        match_b_mbtype=4'b0000;
        case(len)
        3'd2: case(bits[1:0])
            2'b10:match_b_mbtype={1'b1,2'd3,1'b0};
            2'b11:match_b_mbtype={1'b1,2'd3,1'b1};
            default:;
        endcase
        3'd3: case(bits[2:0])
            3'b010:match_b_mbtype={1'b1,2'd2,1'b0};
            3'b011:match_b_mbtype={1'b1,2'd2,1'b1};
            default:;
        endcase
        3'd4: case(bits[3:0])
            4'b0010:match_b_mbtype={1'b1,2'd1,1'b0};
            4'b0011:match_b_mbtype={1'b1,2'd1,1'b1};
            default:;
        endcase
        default:;
        endcase
    end
endfunction
wire [3:0] mbtype_match=match_b_mbtype(mbtype_bits_next,mbtype_len_next);

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
        default:;
        endcase
        match_motion_code={valid,code[5:0]};
    end
endfunction
wire [6:0] motion_match=match_motion_code(motion_bits_next,motion_len_next);

function automatic signed [7:0] reconstruct_mv_f3;
    input signed [7:0] pred; input signed [5:0] code; input [1:0] residual;
    reg [5:0] mag; reg signed [9:0] delta,vec;
    begin
        if(code==0)delta=0;
        else begin
            if(code<0)mag=-code;else mag=code;
            delta=(($signed({1'b0,mag})-1)<<<2)+$signed({8'd0,residual})+1;
            if(code<0)delta=-delta;
        end
        vec=$signed(pred)+delta;
        if(vec>63)vec=vec-128;else if(vec< -64)vec=vec+128;
        reconstruct_mv_f3=vec[7:0];
    end
endfunction

wire parser_consumes_bit=(state==S_QSCALE)||(state==S_EXTRA_FLAG)||(state==S_EXTRA_INFO)||(state==S_MBA)||
    (state==S_MBTYPE)||(state==S_FX)||(state==S_FX_RES)||(state==S_FY)||(state==S_FY_RES)||
    (state==S_BX)||(state==S_BX_RES)||(state==S_BY)||(state==S_BY_RES)||(state==S_CBP)||(state==S_COEFF)||(state==S_STUFF);
wire consume_bit=parse_active&&parser_consumes_bit&&!parser_at_end;

reg t_start,t_we,t_end; reg [5:0] t_widx; reg signed [12:0] t_wval; reg [4:0] t_qscale;
wire t_done,t_first_valid,t_valid,t_error; wire signed [15:0] t_first_value,t_value; wire [1:0] t_unused_block; wire [5:0] t_index;
mpeg2_h262_p_non_intra_transform b_transform(
    .clk(clk),.reset(reset),.qfs_block_index(2'd1),.qfs_block_start(t_start),.qfs_write_en(t_we),
    .qfs_write_index(t_widx),.qfs_write_value(t_wval),.qfs_block_end(t_end),
    .quantiser_scale_code(t_qscale),.q_scale_type(q_scale_type),.alternate_scan(alternate_scan),
    .block_done(t_done),.first_sample_valid(t_first_valid),.first_sample_value(t_first_value),
    .residual_sample_valid(t_valid),.residual_sample_block_index(t_unused_block),
    .residual_sample_index(t_index),.residual_sample_value(t_value),.probe_error(t_error));

reg signed [15:0] residual_mem [0:255];
reg [6:0] t_sample_count; reg [2:0] transform_slot;
localparam [3:0] R_IDLE=0,R_TSTART=1,R_TWRITE=2,R_TEND=3,R_TWAIT=4,R_MOTA=5,R_MOTB=6,R_DESC=7,R_SAMPLE=8,R_FINISH=9;
reg [3:0] rstate; reg [5:0] replay_mb,replay_sample; reg [2:0] replay_slot;
wire [7:0] replay_fvx=forward_x_plan[(replay_mb*8)+:8];
wire [7:0] replay_fvy=forward_y_plan[(replay_mb*8)+:8];
wire [7:0] replay_bvx=backward_x_plan[(replay_mb*8)+:8];
wire [7:0] replay_bvy=backward_y_plan[(replay_mb*8)+:8];
wire [1:0] replay_dir=direction_plan[(replay_mb*2)+:2];
wire [7:0] dir_index=(replay_dir==2'd1)?8'h38:(replay_dir==2'd2)?8'h39:8'h3a;
wire [7:0] desc_mb=residual_mb[replay_slot];
wire [7:0] res_mem_addr={replay_slot[1:0],6'b000000}+replay_sample;

integer i;
always @(posedge clk) begin
    if(reset) begin
        byte_window<=0;sequence_capture<=0;sequence_count<=0;sequence_shift<=0;geometry_128x96<=0;
        picture_capture<=0;picture_count<=0;picture_shift<=0;current_picture_is_b<=0;
        pce_capture<=0;pce_count<=0;pce_shift<=0;b_candidate<=0;b_seen<=0;b_complete_now<=0;
        parse_hold<=0;parser_error<=0;replay_error<=0;slice_capture<=0;slice_row_number<=0;row_byte_count<=0;
        parse_active<=0;proof_done<=0;boundary_final<=0;parse_byte_limit<=0;parse_byte_index<=0;parse_bit_index<=7;
        state<=S_QSCALE;field_bit_count<=0;qscale_shift<=0;current_qscale<=0;extra_info_count<=0;current_col<=0;row_has_coded_mb<=0;
        mbtype_bits<=0;mbtype_len<=0;current_direction<=0;current_pattern<=0;
        fpx<=0;fpy<=0;bpx<=0;bpy<=0;cur_fx<=0;cur_fy<=0;cur_bx<=0;cur_by<=0;
        motion_code_pending<=0;motion_bits<=0;motion_len<=0;motion_residual_shift<=0;motion_residual_count<=0;
        cbp_bits<=0;cbp_len<=0;coeff_bits<=0;coeff_len<=0;direction_plan<=0;forward_x_plan<=0;forward_y_plan<=0;backward_x_plan<=0;backward_y_plan<=0;
        residual_count<=0;q_scale_type<=0;alternate_scan<=0;
        t_start<=0;t_we<=0;t_end<=0;t_widx<=0;t_wval<=0;t_qscale<=0;t_sample_count<=0;transform_slot<=0;
        rstate<=R_IDLE;replay_mb<=0;replay_sample<=0;replay_slot<=0;replay_active<=0;sideband_valid<=0;sideband_index<=0;sideband_value<=0;
        first_sample_valid<=0;first_sample_value<=0;
        for(i=0;i<4;i=i+1)begin residual_mb[i]<=0;residual_qscale[i]<=0;residual_level[i]<=0;end
    end else begin
        b_complete_now<=0;sideband_valid<=0;first_sample_valid<=0;t_start<=0;t_we<=0;t_end<=0;
        if(t_error)replay_error<=1;

        if(parse_active) begin
            if(consume_bit) begin
                if(parse_bit_index==0)begin parse_bit_index<=7;parse_byte_index<=parse_byte_index+1'b1;end
                else parse_bit_index<=parse_bit_index-1'b1;
            end
            case(state)
            S_QSCALE: begin
                if(parser_at_end)state<=S_ERROR;
                else begin qscale_shift<=qscale_next;if(field_bit_count==4)begin field_bit_count<=0;if(qscale_next==0)state<=S_ERROR;else begin current_qscale<=qscale_next;state<=S_EXTRA_FLAG;end end else field_bit_count<=field_bit_count+1'b1;end
            end
            S_EXTRA_FLAG: begin
                if(parser_at_end)state<=S_ERROR;else if(parser_current_bit)begin extra_info_count<=0;state<=S_EXTRA_INFO;end else state<=S_MBA;
            end
            S_EXTRA_INFO: begin
                if(parser_at_end)state<=S_ERROR;else if(extra_info_count==7)begin extra_info_count<=0;state<=S_EXTRA_FLAG;end else extra_info_count<=extra_info_count+1'b1;
            end
            S_MBA: begin
                if(parser_at_end||!parser_current_bit)state<=S_ERROR;
                else begin mbtype_bits<=0;mbtype_len<=0;state<=S_MBTYPE;end
            end
            S_MBTYPE: begin
                if(parser_at_end)state<=S_ERROR;
                else if(mbtype_match[3])begin
                    current_direction<=mbtype_match[2:1];current_pattern<=mbtype_match[0];mbtype_bits<=0;mbtype_len<=0;
                    cur_fx<=0;cur_fy<=0;cur_bx<=0;cur_by<=0;motion_bits<=0;motion_len<=0;
                    if(mbtype_match[2:1]==2'd2)state<=S_BX;else state<=S_FX;
                end else if(mbtype_len_next>=4)state<=S_ERROR;else begin mbtype_bits<=mbtype_bits_next;mbtype_len<=mbtype_len_next;end
            end
            S_FX: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;if($signed(motion_match[5:0])==0)begin cur_fx<=fpx;state<=S_FY;end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_FX_RES;end end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
            end
            S_FX_RES: begin if(parser_at_end)state<=S_ERROR;else begin motion_residual_shift<=motion_residual_next;if(motion_residual_count)begin cur_fx<=reconstruct_mv_f3(fpx,motion_code_pending,motion_residual_next);motion_residual_count<=0;motion_bits<=0;motion_len<=0;state<=S_FY;end else motion_residual_count<=1;end end
            S_FY: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;if($signed(motion_match[5:0])==0)begin cur_fy<=fpy;if(current_direction==2'd3)state<=S_BX;else if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end else state<=S_MB_DONE;end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_FY_RES;end end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
            end
            S_FY_RES: begin if(parser_at_end)state<=S_ERROR;else begin motion_residual_shift<=motion_residual_next;if(motion_residual_count)begin cur_fy<=reconstruct_mv_f3(fpy,motion_code_pending,motion_residual_next);motion_residual_count<=0;motion_bits<=0;motion_len<=0;if(current_direction==2'd3)state<=S_BX;else if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end else state<=S_MB_DONE;end else motion_residual_count<=1;end end
            S_BX: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;if($signed(motion_match[5:0])==0)begin cur_bx<=bpx;state<=S_BY;end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_BX_RES;end end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
            end
            S_BX_RES: begin if(parser_at_end)state<=S_ERROR;else begin motion_residual_shift<=motion_residual_next;if(motion_residual_count)begin cur_bx<=reconstruct_mv_f3(bpx,motion_code_pending,motion_residual_next);motion_residual_count<=0;motion_bits<=0;motion_len<=0;state<=S_BY;end else motion_residual_count<=1;end end
            S_BY: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;if($signed(motion_match[5:0])==0)begin cur_by<=bpy;if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end else state<=S_MB_DONE;end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_BY_RES;end end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
            end
            S_BY_RES: begin if(parser_at_end)state<=S_ERROR;else begin motion_residual_shift<=motion_residual_next;if(motion_residual_count)begin cur_by<=reconstruct_mv_f3(bpy,motion_code_pending,motion_residual_next);motion_residual_count<=0;if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end else state<=S_MB_DONE;end else motion_residual_count<=1;end end
            S_CBP: begin
                if(parser_at_end)state<=S_ERROR;
                else begin cbp_bits<=cbp_bits_next;cbp_len<=cbp_len_next;if(cbp_len_next==4)begin if(cbp_bits_next!=4'b1010||residual_count>=MAX_RESIDUAL_BLOCKS)state<=S_ERROR;else begin coeff_bits<=0;coeff_len<=0;state<=S_COEFF;end end end
            end
            S_COEFF: begin
                if(parser_at_end)state<=S_ERROR;
                else begin coeff_bits<=coeff_bits_next;coeff_len<=coeff_len_next;if(coeff_len_next==4)begin
                    if((coeff_bits_next!=4'b1010)&&(coeff_bits_next!=4'b1110))state<=S_ERROR;
                    else begin residual_mb[residual_count]<=current_map_index;residual_qscale[residual_count]<=current_qscale;residual_level[residual_count]<=coeff_bits_next[2]? -13'sd1:13'sd1;residual_count<=residual_count+1'b1;state<=S_MB_DONE;end
                end end
            end
            S_MB_DONE: begin
                direction_plan[(current_map_index*2)+:2]<=current_direction;
                forward_x_plan[(current_map_index*8)+:8]<=cur_fx;forward_y_plan[(current_map_index*8)+:8]<=cur_fy;
                backward_x_plan[(current_map_index*8)+:8]<=cur_bx;backward_y_plan[(current_map_index*8)+:8]<=cur_by;
                if(current_direction[0])begin fpx<=cur_fx;fpy<=cur_fy;end
                if(current_direction[1])begin bpx<=cur_bx;bpy<=cur_by;end
                row_has_coded_mb<=1;
                if(current_col==MB_WIDTH-1'b1)state<=S_STUFF;else begin current_col<=current_col+1'b1;state<=S_MBA;end
            end
            S_STUFF: begin if(parser_at_end)state<=S_SUCCESS;else if(parser_current_bit)state<=S_ERROR;end
            S_SUCCESS: begin
                parse_active<=0;
                if(!row_has_coded_mb||(current_col!=MB_WIDTH-1'b1))begin parser_error<=1;proof_done<=1;parse_hold<=0;end
                else if(boundary_final)begin
                    proof_done<=1;transform_slot<=0;t_sample_count<=0;replay_mb<=0;replay_slot<=0;replay_sample<=0;
                    replay_active<=1;if(residual_count!=0)rstate<=R_TSTART;else rstate<=R_MOTA;
                end else begin slice_row_number<=slice_row_number+1'b1;row_byte_count<=0;slice_capture<=1;parse_hold<=0;end
            end
            default: begin parse_active<=0;parse_hold<=0;proof_done<=1;parser_error<=1;b_candidate<=0;state<=S_ERROR;end
            endcase
        end

        if(replay_active&&t_valid)begin
            if(transform_slot>=MAX_RESIDUAL_BLOCKS||t_index!=t_sample_count[5:0]||t_sample_count>=64)replay_error<=1;
            else begin residual_mem[{transform_slot[1:0],6'b000000}+t_index]<=t_value;t_sample_count<=t_sample_count+1'b1;end
        end
        case(rstate)
        R_TSTART:begin t_qscale<=residual_qscale[transform_slot];t_sample_count<=0;t_start<=1;rstate<=R_TWRITE;end
        R_TWRITE:begin t_we<=1;t_widx<=0;t_wval<=residual_level[transform_slot];rstate<=R_TEND;end
        R_TEND:begin t_end<=1;rstate<=R_TWAIT;end
        R_TWAIT:if(t_done)begin
            if((t_sample_count+(t_valid?1'b1:1'b0))!=64)replay_error<=1;
            if(transform_slot+1'b1>=residual_count)begin replay_mb<=0;rstate<=R_MOTA;end
            else begin transform_slot<=transform_slot+1'b1;rstate<=R_TSTART;end
        end
        R_MOTA:begin sideband_valid<=1;sideband_index<=dir_index[5:0];sideband_value<=$signed({replay_fvx,replay_fvy});rstate<=R_MOTB;end
        R_MOTB:begin
            sideband_valid<=1;sideband_index<=6'h3b;sideband_value<=$signed({replay_bvx,replay_bvy});
            if(replay_mb==47)begin if(residual_count==0)rstate<=R_FINISH;else begin replay_slot<=0;rstate<=R_DESC;end end
            else begin replay_mb<=replay_mb+1'b1;rstate<=R_MOTA;end
        end
        R_DESC:begin sideband_valid<=1;sideband_index<=6'h3f;sideband_value<=$signed({4'hB,3'b000,desc_mb[5:0],3'd0});replay_sample<=0;rstate<=R_SAMPLE;end
        R_SAMPLE:begin
            sideband_valid<=1;sideband_index<=replay_sample;sideband_value<=residual_mem[res_mem_addr];
            if((replay_slot==0)&&(replay_sample==0))begin first_sample_valid<=1;first_sample_value<=residual_mem[res_mem_addr];end
            if(replay_sample==63)begin if(replay_slot+1'b1>=residual_count)rstate<=R_FINISH;else begin replay_slot<=replay_slot+1'b1;rstate<=R_DESC;end end
            else replay_sample<=replay_sample+1'b1;
        end
        R_FINISH:begin sideband_valid<=1;sideband_index<=6'h3f;sideband_value<=16'shA3FF;b_seen<=1;b_complete_now<=1;replay_active<=0;parse_hold<=0;rstate<=R_IDLE;end
        default:;
        endcase

        if(stream_valid) begin
            byte_window<=byte_window_next;
            if(sequence_capture)begin sequence_shift<=sequence_next;if(sequence_count==2)begin sequence_capture<=0;sequence_count<=0;geometry_128x96<=(sequence_next[23:12]==128)&&(sequence_next[11:0]==96);end else sequence_count<=sequence_count+1'b1;end
            else if(start_code_now&&(start_code_value==SEQUENCE_HEADER_CODE))begin sequence_capture<=1;sequence_count<=0;sequence_shift<=0;end

            if(picture_capture)begin picture_shift<=picture_next;if(picture_count)begin picture_capture<=0;picture_count<=0;current_picture_is_b<=(picture_next[5:3]==3'd3);end else picture_count<=1;end
            else if(start_code_now&&(start_code_value==PICTURE_START_CODE))begin picture_capture<=1;picture_count<=0;picture_shift<=0;current_picture_is_b<=0;b_candidate<=0;end

            if(pce_capture)begin
                pce_shift<=pce_next;
                if(pce_count==4)begin
                    pce_capture<=0;pce_count<=0;q_scale_type<=pce_next[12];alternate_scan<=pce_next[10];
                    b_candidate<=geometry_128x96&&current_picture_is_b&&(pce_next[39:36]==4'h8)&&
                        (pce_next[35:32]==3)&&(pce_next[31:28]==3)&&(pce_next[27:24]==3)&&(pce_next[23:20]==3)&&
                        (pce_next[17:16]==2'b11)&&pce_next[14]&&!pce_next[13];
                end else pce_count<=pce_count+1'b1;
            end else if(current_picture_is_b&&start_code_now&&(start_code_value==EXTENSION_START_CODE))begin pce_capture<=1;pce_count<=0;pce_shift<=0;end

            if(!parse_active&&!proof_done&&slice_capture)begin
                if(start_code_now)begin
                    if(row_byte_count<3)begin slice_capture<=0;proof_done<=1;parser_error<=1;end
                    else if(slice_row_number<MB_HEIGHT)begin
                        if(start_code_value==({2'd0,slice_row_number}+1'b1))begin
                            slice_capture<=0;parse_active<=1;parse_hold<=1;boundary_final<=0;parse_byte_limit<=row_byte_count-3;parse_byte_index<=0;parse_bit_index<=7;state<=S_QSCALE;
                            field_bit_count<=0;qscale_shift<=0;extra_info_count<=0;current_col<=0;row_has_coded_mb<=0;fpx<=0;fpy<=0;bpx<=0;bpy<=0;
                        end else begin slice_capture<=0;proof_done<=1;parser_error<=1;end
                    end else if(post_b_boundary_now)begin
                        slice_capture<=0;parse_active<=1;parse_hold<=1;boundary_final<=1;parse_byte_limit<=row_byte_count-3;parse_byte_index<=0;parse_bit_index<=7;state<=S_QSCALE;
                        field_bit_count<=0;qscale_shift<=0;extra_info_count<=0;current_col<=0;row_has_coded_mb<=0;fpx<=0;fpy<=0;bpx<=0;bpy<=0;
                    end else begin slice_capture<=0;proof_done<=1;parser_error<=1;end
                end else if(row_byte_count<ROW_BUFFER_BYTES)begin row_bytes[row_byte_count]<=stream_data;row_byte_count<=row_byte_count+1'b1;end
                else begin slice_capture<=0;proof_done<=1;parser_error<=1;end
            end else if(!parse_active&&!proof_done&&b_candidate&&slice_start_now)begin
                if(start_code_value==8'h01)begin
                    slice_capture<=1;slice_row_number<=1;row_byte_count<=0;direction_plan<=0;forward_x_plan<=0;forward_y_plan<=0;backward_x_plan<=0;backward_y_plan<=0;residual_count<=0;parser_error<=0;replay_error<=0;
                end else begin proof_done<=1;parser_error<=1;end
            end
        end
    end
end
endmodule
