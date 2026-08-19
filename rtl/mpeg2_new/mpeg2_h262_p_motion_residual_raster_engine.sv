//============================================================================
// MiSTer Media Player - generalized H.262 P prediction+residual raster engine
//
// Sideband protocol:
//   * ordered motion words at residual_index 0x3e: {mvx[7:0],mvy[7:0]}
//   * legacy 128x96 residual descriptor: index 0x3f, value Bxxx
//   * Commit-166 wide descriptor: 0x3c -> 11-bit MB, 0x3d -> block
//   * 64 signed spatial samples at indices 0..63
//   * A2FE intermediate-row terminator at index 0x3f
//   * A2FF terminator at index 0x3f
//
// kate - Commit 166: geometry is derived from the live sequence dimensions,
// up to the established 720x480 progressive 4:2:0 envelope. Ordered motion
// words are retained in one synchronous M10K-oriented RAM instead of 48 flops.
// Commit 199 error_source is first-fault-only: 1 sample order, 2 motion
// metadata, 3/4/5 wide descriptor, 6 legacy descriptor, 7 terminator,
// 8 unknown metadata, 9 admission, 10 timeout, 11 motion range, 12 source
// bounds, 13 unexpected DDR response, 14 readback, 15 descriptor count,
// 16 motion count.
//============================================================================
module mpeg2_h262_p_motion_residual_raster_engine
(
    input wire clk,
    input wire reset,
    input wire capture_enable,
    input wire request,
    input wire [13:0] horizontal_size,
    input wire [13:0] vertical_size,
    input wire [47:0] shift_right_map, // historical compatibility, unused
    input wire residual_valid,
    input wire [5:0] residual_index,
    input wire signed [15:0] residual_value,
    output wire residual_store_write,
    output wire [16:0] residual_store_write_address,
    output wire signed [15:0] residual_store_write_data,
    output wire [16:0] residual_store_read_address,
    input wire signed [15:0] residual_store_read_data,
    input wire reference_valid,
    input wire reference_bank,
    input wire destination_bank,
    input wire store_block_stored,
    input wire ddram_busy,
    input wire [63:0] ddram_dout,
    input wire ddram_dout_ready,
    input wire ddram_lookup_ready,
    input wire ddram_lookup_hit,
    input wire [63:0] ddram_lookup_data,
    output wire [7:0] ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire ddram_rd,
    output wire ddram_cacheable,
    output wire ddram_lookup_request,
    output wire ddram_lookup_consume,
    output wire store_select,
    output wire [7:0] store_pixel_value,
    output wire [11:0] store_pixel_x,
    output wire [11:0] store_pixel_y,
    output wire store_pixel_valid,
    output wire store_block_start,
    output wire store_block_complete,
    output reg active,
    output reg read_seen,
    output reg [7:0] sample_value,
    output reg sample_nonzero,
    output reg half_sample_seen,
    output reg reconstructed_seen,
    output reg [7:0] reconstructed_value,
    output reg persisted_seen,
    output reg row_persisted,
    output reg [7:0] persisted_value,
    output reg [3:0] progress_stage,
    output reg error,
    output reg [4:0] error_source
);

localparam [28:0]
    Y_BASE=29'h06000000,
    CB_BASE=29'h0600A8C0,
    CR_BASE=29'h0600D2F0,
    BANK_OFF=29'h00010000;
localparam integer MAX_MB=1350;
localparam integer MAX_BLOCKS=2048;

wire [14:0] horizontal_rounded =
    {1'b0,horizontal_size}+15'd15;
wire [14:0] vertical_rounded =
    {1'b0,vertical_size}+15'd15;
wire [5:0] mb_width = horizontal_rounded[9:4];
wire [5:0] mb_height = vertical_rounded[9:4];
wire geometry_ok =
    (horizontal_size!=0) &&
    (vertical_size!=0) &&
    (horizontal_size<=14'd720) &&
    (vertical_size<=14'd480) &&
    (mb_width!=0) && (mb_width<=6'd45) &&
    (mb_height!=0) && (mb_height<=6'd30);

wire [11:0] padded_luma_width = {6'd0,mb_width} << 4;
wire [11:0] padded_luma_height = {6'd0,mb_height} << 4;
wire [11:0] padded_chroma_width = {6'd0,mb_width} << 3;
wire [11:0] padded_chroma_height = {6'd0,mb_height} << 3;

function automatic [28:0] r90;
    input [11:0] r;
    reg [28:0] x;
    begin
        x={17'd0,r};
        r90=(x<<6)+(x<<4)+(x<<3)+(x<<1);
    end
endfunction

function automatic [28:0] r45;
    input [11:0] r;
    reg [28:0] x;
    begin
        x={17'd0,r};
        r45=(x<<5)+(x<<3)+(x<<2)+x;
    end
endfunction

function automatic [28:0] block_addr;
    input [28:0] off;
    input [5:0] c;
    input [5:0] mr;
    input [2:0] b;
    input [2:0] rr;
    reg [11:0] lr,lw,cr;
    begin
        if(b<4) begin
            lr=({6'd0,mr}<<4)+{8'd0,b[1],rr};
            lw=({6'd0,c}<<1)+{11'd0,b[0]};
            block_addr=Y_BASE+off+r90(lr)+{17'd0,lw};
        end else begin
            cr=({6'd0,mr}<<3)+{9'd0,rr};
            block_addr=(b==4?CB_BASE:CR_BASE)+
                       off+r45(cr)+{20'd0,c};
        end
    end
endfunction

function automatic [28:0] pixel_addr;
    input [28:0] off;
    input [2:0] b;
    input [11:0] x;
    input [11:0] y;
    begin
        if(b<4)
            pixel_addr=Y_BASE+off+r90(y)+{20'd0,x[11:3]};
        else
            pixel_addr=(b==4?CB_BASE:CR_BASE)+
                       off+r45(y)+{20'd0,x[11:3]};
    end
endfunction

function automatic [7:0] bat;
    input [63:0] w;
    input [2:0] n;
    begin
        case(n)
        0:bat=w[7:0];
        1:bat=w[15:8];
        2:bat=w[23:16];
        3:bat=w[31:24];
        4:bat=w[39:32];
        5:bat=w[47:40];
        6:bat=w[55:48];
        default:bat=w[63:56];
        endcase
    end
endfunction

function automatic [7:0] clip;
    input [7:0] p;
    input signed [15:0] f;
    reg signed [16:0] s;
    begin
        s=$signed({9'd0,p})+{f[15],f};
        if(s<0) clip=0;
        else if(s>255) clip=255;
        else clip=s[7:0];
    end
endfunction

function automatic signed [7:0] chroma_half_vector;
    input signed [7:0] v;
    reg signed [8:0] a;
    begin
        if(v<0) begin
            a=-$signed(v);
            chroma_half_vector=-(a>>>1);
        end else chroma_half_vector=$signed(v)>>>1;
    end
endfunction

function automatic [7:0] round_prediction;
    input [10:0] sum;
    input hx;
    input hy;
    begin
        if(hx&&hy) round_prediction=(sum+11'd2)>>2;
        else if(hx||hy) round_prediction=(sum+11'd1)>>1;
        else round_prediction=sum[7:0];
    end
endfunction

// kate - Commit 166: no reset loop on this array. Synchronous read plus ordered
// write/read phases allow Quartus to infer block RAM instead of 1350x16 flops.
(* ramstyle = "M10K" *) reg [16:0] motion_mem [0:MAX_MB-1];
reg [10:0] motion_count;
reg [16:0] motion_word;
wire mb_intra=motion_word[16];
wire signed [7:0] mb_mvx=$signed(motion_word[15:8]);
wire signed [7:0] mb_mvy=$signed(motion_word[7:0]);

(* ramstyle = "M10K" *) reg [14:0] desc_mem [0:2047];
reg [14:0] desc_word;
reg [14:0] last_desc_word;
reg [11:0] desc_count;
reg [10:0] current_desc_slot;
reg desc_active;
reg wide_desc_pending;
reg [10:0] wide_desc_mb;
reg [5:0] sample_expected;
reg metadata_done;
reg [10:0] exec_desc_slot;
reg [10:0] row_motion_base, row_motion_end;
reg [5:0] exec_row;
reg row_final_latched;

reg pending, started;
reg reference_bank_latched, destination_bank_latched;
reg req, waitresp, req_kind, lookup_wait;
reg [10:0] mbi;
reg [5:0] col, mrow;
reg [2:0] blk;
reg [23:0] timeout;
reg [63:0] resrows [0:7];
reg emit, wait_store, pixel_setup, motion_load;
reg residual_load, residual_load_wait;
reg [5:0] ei;
reg [2:0] verify_row;
reg [1:0] tap_index;
reg [10:0] pred_sum;
reg [7:0] out_reg;
integer i;

wire [28:0] roff=reference_bank_latched?BANK_OFF:0;
wire [28:0] doff=destination_bank_latched?BANK_OFF:0;
wire [2:0] er=ei[5:3], el=ei[2:0];

wire signed [7:0] exec_mvx =
    (blk<4)?mb_mvx:chroma_half_vector(mb_mvx);
wire signed [7:0] exec_mvy =
    (blk<4)?mb_mvy:chroma_half_vector(mb_mvy);
wire signed [8:0] exec_int_x=$signed(exec_mvx)>>>1;
wire signed [8:0] exec_int_y=$signed(exec_mvy)>>>1;
wire half_x=exec_mvx[0];
wire half_y=exec_mvy[0];

wire [11:0] luma_x=({6'd0,col}<<4)+{8'd0,blk[0],el};
wire [11:0] luma_y=({6'd0,mrow}<<4)+{8'd0,blk[1],er};
wire [11:0] chroma_x=({6'd0,col}<<3)+{9'd0,el};
wire [11:0] chroma_y=({6'd0,mrow}<<3)+{9'd0,er};
wire [11:0] dest_x=(blk<4)?luma_x:chroma_x;
wire [11:0] dest_y=(blk<4)?luma_y:chroma_y;
wire signed [13:0] src_base_x=
    $signed({1'b0,dest_x})+$signed(exec_int_x);
wire signed [13:0] src_base_y=
    $signed({1'b0,dest_y})+$signed(exec_int_y);
wire [11:0] plane_width =
    (blk<4)?padded_luma_width:padded_chroma_width;
wire [11:0] plane_height =
    (blk<4)?padded_luma_height:padded_chroma_height;
wire signed [13:0] src_last_x=
    src_base_x+(half_x?14'sd1:14'sd0);
wire signed [13:0] src_last_y=
    src_base_y+(half_y?14'sd1:14'sd0);
wire signed [13:0] plane_width_s=
    $signed({2'b00,plane_width});
wire signed [13:0] plane_height_s=
    $signed({2'b00,plane_height});
wire source_bounds_ok=
    (src_base_x>=0)&&(src_base_y>=0)&&
    (src_last_x<plane_width_s)&&(src_last_y<plane_height_s);

wire tap_dx=
    (half_x&&half_y)?tap_index[0]:
    (half_x?tap_index[0]:1'b0);
wire tap_dy=
    (half_x&&half_y)?tap_index[1]:
    (half_y?tap_index[0]:1'b0);
wire tap_last=
    (half_x&&half_y)?(tap_index==2'd3):
    ((half_x||half_y)?(tap_index==2'd1):(tap_index==2'd0));
wire signed [13:0] src_x_tap_signed=
    src_base_x+$signed({13'd0,tap_dx});
wire signed [13:0] src_y_tap_signed=
    src_base_y+$signed({13'd0,tap_dy});
wire [11:0] src_x_tap=src_x_tap_signed[11:0];
wire [11:0] src_y_tap=src_y_tap_signed[11:0];
wire [1:0] next_tap_index=tap_index+1'b1;
wire next_tap_dx=
    (half_x&&half_y)?next_tap_index[0]:
    (half_x?next_tap_index[0]:1'b0);
wire next_tap_dy=
    (half_x&&half_y)?next_tap_index[1]:
    (half_y?next_tap_index[0]:1'b0);
wire signed [13:0] next_src_x_tap_signed=
    src_base_x+$signed({13'd0,next_tap_dx});
wire signed [13:0] next_src_y_tap_signed=
    src_base_y+$signed({13'd0,next_tap_dy});
wire [11:0] next_src_x_tap=next_src_x_tap_signed[11:0];
wire [11:0] next_src_y_tap=next_src_y_tap_signed[11:0];

wire descriptor_position_hit=
    (exec_desc_slot<desc_count)&&
    (desc_word[14:4]==mbi)&&
    (desc_word[2:0]==blk);
wire residual_hit=descriptor_position_hit&&
    (desc_word[3]==mb_intra);
// Commit 231: while the current pixel performs its reference lookup, use the
// synchronous residual-store port to fetch the next sample in the block.
// Block boundaries retain the staged residual_load path so descriptor changes
// still receive the full RAM read latency.
wire residual_read_ahead=
    (pixel_setup||lookup_wait||(req&&!req_kind)||
     (waitresp&&!req_kind)||emit)&&(ei!=6'd63);
wire [5:0] residual_read_index=
    residual_read_ahead ? (ei+1'b1) : ei;
wire [16:0] residual_mem_index=
    {exec_desc_slot,6'b000000}+{11'd0,residual_read_index};
reg signed [15:0] residual_pel_q;

assign residual_store_write=
    capture_enable&&residual_valid&&desc_active&&
    (residual_index==sample_expected);
assign residual_store_write_address=
    {current_desc_slot,6'b000000}+{11'd0,residual_index};
assign residual_store_write_data=residual_value;
assign residual_store_read_address=residual_mem_index;

wire [7:0] current_tap_sample=bat(ddram_dout,src_x_tap[2:0]);
wire [10:0] pred_sum_with_current=
    pred_sum+{3'd0,current_tap_sample};
wire [7:0] predicted_current=
    round_prediction(pred_sum_with_current,half_x,half_y);
wire [7:0] reconstructed_current=
    clip(predicted_current,residual_pel_q);
wire [7:0] lookup_tap_sample=
    bat(ddram_lookup_data,src_x_tap[2:0]);
wire [10:0] lookup_pred_sum_with_current=
    pred_sum+{3'd0,lookup_tap_sample};
wire [7:0] lookup_predicted_current=
    round_prediction(lookup_pred_sum_with_current,half_x,half_y);
wire [7:0] lookup_reconstructed_current=
    clip(lookup_predicted_current,residual_pel_q);
wire lookup_advance=lookup_wait&&ddram_lookup_ready&&
    ddram_lookup_hit&&!tap_last;
wire prediction_lookup=
    (pixel_setup&&!mb_intra&&source_bounds_ok)||lookup_advance;
wire [11:0] lookup_src_x=lookup_advance?next_src_x_tap:src_x_tap;
wire [11:0] lookup_src_y=lookup_advance?next_src_y_tap:src_y_tap;

assign ddram_burstcnt=req?8'd1:0;
assign ddram_addr=req ?
    (req_kind ? block_addr(doff,col,mrow,blk,verify_row)
              : pixel_addr(roff,blk,src_x_tap,src_y_tap)) :
    prediction_lookup ? pixel_addr(roff,blk,lookup_src_x,lookup_src_y) :
    29'd0;
assign ddram_rd=req;
assign ddram_cacheable=(req&&!req_kind)||prediction_lookup;
assign ddram_lookup_request=prediction_lookup;
assign ddram_lookup_consume=
    lookup_wait&&ddram_lookup_ready&&ddram_lookup_hit;

assign store_select=emit;
assign store_pixel_value=out_reg;
assign store_pixel_valid=emit;
assign store_block_start=emit&&(ei==0);
assign store_block_complete=emit&&(ei==63);
assign store_pixel_x=
    (blk<4)?luma_x:
    (blk==4)?{2'b01,chroma_x[9:0]}:
             {2'b10,chroma_x[9:0]};
assign store_pixel_y=(blk<4)?luma_y:chroma_y;

wire ready_res=metadata_done;
wire descriptor_order_error=
    (desc_count!=0)&&
    ({wide_desc_mb,residual_value[2:0]} <=
     {last_desc_word[14:4],last_desc_word[2:0]});

wire new_picture_metadata=
    capture_enable&&residual_valid&&!desc_active&&
    ((residual_index==6'h3e)||(residual_index==6'h3b))&&
    persisted_seen&&!active;
wire unused_shift_map=&{1'b0,shift_right_map};

// Commit 202: synchronous descriptor and sparse-sample lookups allow both
// 2048-block stores to infer M10K RAM. Commit 231 keeps residual_load for the
// first sample of a block, then captures each prefetched in-block sample when
// the preceding pixel emits.
always @(posedge clk) begin
    if(reset) begin
        residual_pel_q<=0;
        desc_word<=0;
    end else begin
        if(residual_load_wait||(emit&&(ei!=6'd63)))
            residual_pel_q<=residual_hit ? residual_store_read_data : 16'sd0;
        desc_word<=desc_mem[exec_desc_slot];
    end
end

always @(posedge clk) begin
    if(reset) begin
        motion_count<=0;
        motion_word<=0;
        desc_count<=0;
        last_desc_word<=0;
        current_desc_slot<=0;
        desc_active<=0;
        wide_desc_pending<=0;
        wide_desc_mb<=0;
        sample_expected<=0;
        metadata_done<=0;
        exec_desc_slot<=0;
        pending<=0;
        started<=0;
        active<=0;
        reference_bank_latched<=0;
        destination_bank_latched<=0;
        req<=0;
        waitresp<=0;
        req_kind<=0;
        lookup_wait<=0;
        mbi<=0;
        col<=0;
        mrow<=0;
        blk<=0;
        timeout<=0;
        emit<=0;
        wait_store<=0;
        pixel_setup<=0;
        motion_load<=0;
        residual_load<=0;
        residual_load_wait<=0;
        ei<=0;
        verify_row<=0;
        tap_index<=0;
        pred_sum<=0;
        out_reg<=0;
        read_seen<=0;
        sample_value<=0;
        sample_nonzero<=0;
        half_sample_seen<=0;
        reconstructed_seen<=0;
        reconstructed_value<=0;
        persisted_seen<=0;
        row_persisted<=0;
        persisted_value<=0;
        progress_stage<=0;
        error<=0;
        error_source<=0;
        row_motion_base<=0;
        row_motion_end<=0;
        exec_row<=0;
        row_final_latched<=0;
        for(i=0;i<8;i=i+1)
            resrows[i]<=0;
    end else begin
        row_persisted<=0;
        if(new_picture_metadata) begin
            persisted_seen<=0;
            progress_stage<=4'd1;
            metadata_done<=0;
            motion_count<=11'd1;
            motion_mem[0]<={(residual_index==6'h3b),residual_value};
            desc_count<=0;
            last_desc_word<=0;
            current_desc_slot<=0;
            desc_active<=0;
            wide_desc_pending<=0;
            sample_expected<=0;
            exec_desc_slot<=0;
            pending<=request;
            started<=0;
            req<=0;
            waitresp<=0;
            lookup_wait<=0;
            emit<=0;
            wait_store<=0;
            pixel_setup<=0;
            motion_load<=0;
            residual_load<=0;
            residual_load_wait<=0;
            mbi<=0;
            col<=0;
            mrow<=0;
            row_motion_base<=0;
            row_motion_end<=0;
            exec_row<=0;
            row_final_latched<=0;
            blk<=0;
            ei<=0;
            verify_row<=0;
            half_sample_seen<=0;
        end else if(capture_enable&&residual_valid) begin
            if(progress_stage==4'd0)
                progress_stage<=4'd1;
            if(desc_active) begin
                if(residual_index!=sample_expected) begin
                    error<=1;
                    if(!error) error_source<=5'd1;
                end else begin
                    if(residual_index==6'd63) begin
                        desc_active<=0;
                    end else begin
                        sample_expected<=sample_expected+1'b1;
                    end
                end
            end else if((residual_index==6'h3e)||
                        (residual_index==6'h3b)) begin
                if(metadata_done ||
                   (desc_count!=0) ||
                   wide_desc_pending ||
                   (motion_count>=MAX_MB)) begin
                    error<=1;
                    if(!error) error_source<=5'd2;
                end else begin
                    motion_mem[motion_count]<=
                        {(residual_index==6'h3b),residual_value};
                    motion_count<=motion_count+1'b1;
                end
            end else if(residual_index==6'h3c) begin
                if(metadata_done ||
                   wide_desc_pending ||
                   (desc_count>=MAX_BLOCKS) ||
                   (residual_value<0) ||
                   (residual_value>16'sd1349)) begin
                    error<=1;
                    if(!error) error_source<=5'd3;
                end else begin
                    wide_desc_mb<=residual_value[10:0];
                    wide_desc_pending<=1;
                end
            end else if(residual_index==6'h3d) begin
                if(!wide_desc_pending ||
                   metadata_done ||
                   (desc_count>=MAX_BLOCKS) ||
                   (residual_value[15:4]!=0) ||
                   (residual_value[2:0]>=6)) begin
                    error<=1;
                    if(!error) error_source<=5'd4;
                end else if(descriptor_order_error) begin
                    error<=1;
                    if(!error) error_source<=5'd5;
                end else begin
                    current_desc_slot<=desc_count[10:0];
                    desc_mem[desc_count]<=
                        {wide_desc_mb,residual_value[3:0]};
                    last_desc_word<=
                        {wide_desc_mb,residual_value[3:0]};
                    desc_count<=desc_count+1'b1;
                    desc_active<=1;
                    wide_desc_pending<=0;
                    sample_expected<=0;
                end
            end else if((residual_index==6'h3f) &&
                        (residual_value[15:12]==4'hB)) begin
                if((motion_count!=11'd48) ||
                   metadata_done ||
                   wide_desc_pending ||
                   (desc_count>=MAX_BLOCKS) ||
                   (residual_value[8:3]>=48) ||
                   (residual_value[2:0]>=6) ||
                   ((desc_count!=0)&&
                    ({5'd0,residual_value[8:3],
                      residual_value[2:0]} <=
                     {last_desc_word[14:4],
                      last_desc_word[2:0]}))) begin
                    error<=1;
                    if(!error) error_source<=5'd6;
                end else begin
                    current_desc_slot<=desc_count[10:0];
                    desc_mem[desc_count]<=
                        {{5'd0,residual_value[8:3]},1'b0,
                         residual_value[2:0]};
                    last_desc_word<=
                        {{5'd0,residual_value[8:3]},1'b0,
                         residual_value[2:0]};
                    desc_count<=desc_count+1'b1;
                    desc_active<=1;
                    sample_expected<=0;
                end
            end else if((residual_index==6'h3f) &&
                        ((residual_value==16'shA2FE) ||
                         (residual_value==16'shA2FF))) begin
                if((motion_count==row_motion_base) ||
                   metadata_done ||
                   wide_desc_pending ||
                   (motion_count!=(row_motion_base+{5'd0,mb_width})) ||
                   ((residual_value==16'shA2FF) &&
                    (exec_row+1'b1!=mb_height)) ||
                   ((residual_value==16'shA2FE) &&
                    (exec_row+1'b1>=mb_height))) begin
                    error<=1;
                    if(!error) error_source<=5'd7;
                end else begin
                    metadata_done<=1;
                    row_motion_end<=motion_count;
                    row_final_latched<=(residual_value==16'shA2FF);
                end
            end else begin
                error<=1;
                if(!error) error_source<=5'd8;
            end
        end

        if(request&&!started) pending<=1;
        if(pending&&!started&&ready_res) begin
            pending<=0;
            started<=1;
            active<=1;
            reference_bank_latched<=reference_bank;
            destination_bank_latched<=destination_bank;
            timeout<=24'hffffff;
            mbi<=row_motion_base;
            col<=0;
            mrow<=exec_row;
            blk<=0;
            ei<=0;
            exec_desc_slot<=0;
            motion_load<=1;
            progress_stage<=4'd2;
            pixel_setup<=0;
            if(!geometry_ok ||
               !reference_valid ||
               (reference_bank==destination_bank) ||
               (motion_count==0)) begin
                error<=1;
                if(!error) error_source<=5'd9;
                active<=0;
                persisted_seen<=1;
                timeout<=0;
                motion_load<=0;
            end
        end

        if(started&&!persisted_seen&&timeout!=0) begin
            timeout<=timeout-1'b1;
            if(timeout==1) begin
                error<=1;
                if(!error) error_source<=5'd10;
            end
        end

        if(motion_load) begin
            motion_load<=0;
            if(mbi>=row_motion_end || mbi>=motion_count || mbi>=MAX_MB) begin
                error<=1;
                if(!error) error_source<=5'd11;
                active<=0;
                persisted_seen<=1;
                timeout<=0;
            end else begin
                motion_word<=motion_mem[mbi];
                residual_load<=1;
            end
        end

        if(residual_load) begin
            residual_load<=0;
            residual_load_wait<=1;
        end

        if(residual_load_wait) begin
            residual_load_wait<=0;
            pred_sum<=0;
            tap_index<=0;
            pixel_setup<=1;
        end

        if(pixel_setup) begin
            pixel_setup<=0;
            if(mb_intra&&!residual_hit) begin
                error<=1;
                if(!error) error_source<=5'd17;
                active<=0;
                persisted_seen<=1;
                timeout<=0;
            end else if(mb_intra) begin
                out_reg<=clip(8'd0,residual_pel_q);
                emit<=1;
            end else if(!source_bounds_ok) begin
                error<=1;
                if(!error) error_source<=5'd12;
                active<=0;
                persisted_seen<=1;
                timeout<=0;
            end else begin
                if(half_x||half_y) half_sample_seen<=1;
                req_kind<=0;
                lookup_wait<=1;
            end
        end

        if(lookup_wait&&ddram_lookup_ready) begin
            if(ddram_lookup_hit) begin
                if(progress_stage<4'd3)
                    progress_stage<=4'd3;
                if(tap_last) begin
                    lookup_wait<=0;
                    out_reg<=lookup_reconstructed_current;
                    emit<=1;
                    if((mbi==0)&&(blk==0)&&(ei==0)) begin
                        read_seen<=1;
                        sample_value<=lookup_predicted_current;
                        sample_nonzero<=|lookup_predicted_current;
                    end
                end else begin
                    pred_sum<=lookup_pred_sum_with_current;
                    tap_index<=tap_index+1'b1;
                end
            end else begin
                lookup_wait<=0;
                req<=1;
            end
        end

        if(req&&!ddram_busy) begin
            req<=0;
            waitresp<=1;
        end

        if(ddram_dout_ready) begin
            if(!waitresp) begin
                error<=1;
                if(!error) error_source<=5'd13;
            end else begin
                waitresp<=0;
                if(!req_kind) begin
                    if(progress_stage<4'd3)
                        progress_stage<=4'd3;
                    if(tap_last) begin
                        out_reg<=reconstructed_current;
                        emit<=1;
                        if((mbi==0)&&(blk==0)&&(ei==0)) begin
                            read_seen<=1;
                            sample_value<=predicted_current;
                            sample_nonzero<=|predicted_current;
                        end
                    end else begin
                        pred_sum<=pred_sum_with_current;
                        tap_index<=tap_index+1'b1;
                        req<=1;
                    end
                end else begin
                    if(progress_stage<4'd6)
                        progress_stage<=4'd6;
                    if(ddram_dout!=resrows[verify_row]) begin
                        error<=1;
                        if(!error) error_source<=5'd14;
                    end
                    if((mbi==0)&&(blk==0)&&(verify_row==0))
                        persisted_value<=ddram_dout[7:0];
                    if(verify_row==3'd7) begin
                        if(residual_hit)
                            exec_desc_slot<=exec_desc_slot+1'b1;
                        if(blk==3'd5) begin
                            if(col+1'b1>=mb_width) begin
                                if((exec_desc_slot+
                                    (residual_hit?1'b1:1'b0))!=desc_count)
                                begin
                                    error<=1;
                                    if(!error) error_source<=5'd15;
                                end
                                if(mbi+1'b1!=row_motion_end)
                                begin
                                    error<=1;
                                    if(!error) error_source<=5'd16;
                                end
                                row_persisted<=1;
                                active<=0;
                                timeout<=0;
                                if(row_final_latched) begin
                                    persisted_seen<=1;
                                    progress_stage<=4'd7;
                                    reconstructed_seen<=1;
                                end else begin
                                    started<=0;
                                    metadata_done<=0;
                                    desc_count<=0;
                                    last_desc_word<=0;
                                    current_desc_slot<=0;
                                    desc_active<=0;
                                    wide_desc_pending<=0;
                                    sample_expected<=0;
                                    exec_desc_slot<=0;
                                    row_motion_base<=row_motion_end;
                                    exec_row<=exec_row+1'b1;
                                    row_final_latched<=0;
                                end
                            end else begin
                                mbi<=mbi+1'b1;
                                col<=col+1'b1;
                                blk<=0;
                                ei<=0;
                                motion_load<=1;
                            end
                        end else begin
                            blk<=blk+1'b1;
                            ei<=0;
                            residual_load<=1;
                        end
                    end else begin
                        verify_row<=verify_row+1'b1;
                        req<=1;
                    end
                end
            end
        end

        if(emit) begin
            if(progress_stage<4'd4)
                progress_stage<=4'd4;
            resrows[er][{el,3'b000}+:8]<=out_reg;
            if((mbi==0)&&(blk==0)&&(ei==0))
                reconstructed_value<=out_reg;
            emit<=0;
            if(ei==6'd63) begin
                wait_store<=1;
            end else begin
                ei<=ei+1'b1;
                pred_sum<=0;
                tap_index<=0;
                pixel_setup<=1;
            end
        end

        if(wait_store&&store_block_stored) begin
            if(progress_stage<4'd5)
                progress_stage<=4'd5;
            wait_store<=0;
            req_kind<=1;
            verify_row<=0;
            req<=1;
        end
    end
end

endmodule
