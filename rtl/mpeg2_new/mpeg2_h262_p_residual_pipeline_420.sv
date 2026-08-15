//============================================================================
// MiSTer Media Player - shared H.262 P residual pipeline
//
// The legacy first-macroblock parser remains available outside the generalized
// 128x96 raster client.  For the generalized raster, the syntax observer supplies
// a 48-position motion map plus a 48x6 coded-residual block plan.  Up to sixteen
// selected blocks are transformed serially through the existing IQ/IDCT path.
// Their spatial residuals are buffered and replayed with compact metadata over
// the existing residual-sample sideband; no second transform datapath is added.
//============================================================================
module mpeg2_h262_p_residual_probe(
 input wire clk,input wire reset,input wire [7:0] stream_data,input wire stream_valid,input wire p_picture_expected,
 input wire general_mode,input wire general_picture_complete,input wire [47:0] general_shift_right_map,
 input wire [287:0] general_residual_block_plan,input wire [4:0] general_residual_block_count,
 output wire decision_complete,output wire residual_required,output wire residual_success,output wire mixed_replay_active,
 output wire first_sample_valid,output wire signed [15:0] first_sample_value,
 output wire residual_sample_valid,output wire [5:0] residual_sample_index,output wire signed [15:0] residual_sample_value,
 output wire probe_error);

localparam [4:0] MAX_BLOCKS=5'd16;
wire old_decision,old_required,old_success,old_parser_error;wire[4:0] old_qscale;wire old_qtype,old_alt;
wire[2:0] old_block;wire old_start,old_we,old_end;wire[5:0] old_widx;wire signed[12:0] old_wval;
wire transform_done;
mpeg2_h262_p_residual_parser_420 parser(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),
 .transform_block_done(transform_done&&!general_mode),.decision_complete(old_decision),.residual_required(old_required),
 .residual_success(old_success),.quantiser_scale_code(old_qscale),.q_scale_type(old_qtype),.alternate_scan(old_alt),
 .qfs_block_index(old_block),.qfs_block_start(old_start),.qfs_write_en(old_we),.qfs_write_index(old_widx),
 .qfs_write_value(old_wval),.qfs_block_end(old_end),.probe_error(old_parser_error));

localparam [3:0] G_IDLE=4'd0,G_SCAN=4'd1,G_START=4'd2,G_WRITE=4'd3,G_END=4'd4,G_WAIT=4'd5,
 G_META=4'd6,G_DESC=4'd7,G_SAMPLES=4'd8,G_FINISH=4'd9;
reg[3:0] gstate;reg g_decision,g_required,g_success,g_error;
reg[287:0] gplan;reg[47:0] gmap;reg[4:0] expected_blocks,slot_count;
reg[8:0] scan_index;reg[5:0] scan_mb;reg[2:0] scan_block,current_block;
reg[5:0] desc_mb[0:15];reg[2:0] desc_block[0:15];
reg signed[15:0] gmem[0:1023];reg[6:0] sample_cap_count;
reg gstart,gwe,gend;
reg[2:0] replay_map_byte;reg[4:0] replay_slot;reg[5:0] replay_sample;
reg replay_valid,first_valid_reg;reg[5:0] replay_index;reg signed[15:0] replay_value,first_value_reg;
integer i;

wire [9:0] replay_mem_index={replay_slot[3:0],6'b000000}+{4'd0,replay_sample};
function automatic [7:0] map_byte_value;input[47:0] m;input[2:0] n;begin case(n)
 0:map_byte_value=m[7:0];1:map_byte_value=m[15:8];2:map_byte_value=m[23:16];3:map_byte_value=m[31:24];4:map_byte_value=m[39:32];default:map_byte_value=m[47:40];endcase end endfunction

wire[2:0] qblock=general_mode?current_block:old_block;
wire qstart=general_mode?gstart:old_start;wire qwe=general_mode?gwe:old_we;wire qend=general_mode?gend:old_end;
wire[5:0] qwidx=general_mode?6'd0:old_widx;wire signed[12:0] qwval=general_mode?13'sd7:old_wval;
wire[4:0] qscale=general_mode?5'd2:old_qscale;wire qtype=general_mode?1'b0:old_qtype;wire alt=general_mode?1'b0:old_alt;
wire[1:0] tblock=(qblock==0)?2'd0:2'd1;
wire tfvalid,tvalid,terr;wire signed[15:0] tfvalue,tvalue;wire[1:0] unused_block;wire[5:0] tidx;
mpeg2_h262_p_non_intra_transform transform(
 .clk(clk),.reset(reset),.qfs_block_index(tblock),.qfs_block_start(qstart),.qfs_write_en(qwe),.qfs_write_index(qwidx),.qfs_write_value(qwval),
 .qfs_block_end(qend),.quantiser_scale_code(qscale),.q_scale_type(qtype),.alternate_scan(alt),.block_done(transform_done),
 .first_sample_valid(tfvalid),.first_sample_value(tfvalue),.residual_sample_valid(tvalid),.residual_sample_block_index(unused_block),
 .residual_sample_index(tidx),.residual_sample_value(tvalue),.probe_error(terr));

always @(posedge clk)begin
 if(reset)begin
  gstate<=G_IDLE;g_decision<=0;g_required<=0;g_success<=0;g_error<=0;gplan<=0;gmap<=0;expected_blocks<=0;slot_count<=0;
  scan_index<=0;scan_mb<=0;scan_block<=0;current_block<=0;sample_cap_count<=0;gstart<=0;gwe<=0;gend<=0;
  replay_map_byte<=0;replay_slot<=0;replay_sample<=0;replay_valid<=0;first_valid_reg<=0;replay_index<=0;replay_value<=0;first_value_reg<=0;
  for(i=0;i<16;i=i+1)begin desc_mb[i]<=0;desc_block[i]<=0;end
 end else begin
  gstart<=0;gwe<=0;gend<=0;replay_valid<=0;first_valid_reg<=0;
  if(general_picture_complete)begin
   g_decision<=1;g_required<=(general_residual_block_count!=0);g_success<=(general_residual_block_count==0);
   gplan<=general_residual_block_plan;gmap<=general_shift_right_map;expected_blocks<=general_residual_block_count;
   slot_count<=0;scan_index<=0;scan_mb<=0;scan_block<=0;sample_cap_count<=0;replay_map_byte<=0;replay_slot<=0;replay_sample<=0;
   if(general_residual_block_count>MAX_BLOCKS)begin g_error<=1;gstate<=G_IDLE;end
   else if(general_residual_block_count!=0)gstate<=G_SCAN;else gstate<=G_IDLE;
  end
  if(general_mode&&tvalid)begin
   if(slot_count>=MAX_BLOCKS||tidx!=sample_cap_count[5:0]||sample_cap_count>=7'd64)g_error<=1;
   else begin gmem[{slot_count[3:0],6'b000000}+tidx]<=tvalue;sample_cap_count<=sample_cap_count+1'b1;end
  end
  case(gstate)
   G_SCAN:begin
    if(scan_index>=9'd288)begin
     if((slot_count!=expected_blocks)||(slot_count==0))begin g_error<=1;gstate<=G_IDLE;end
     else begin g_success<=1;replay_map_byte<=0;gstate<=G_META;end
    end else if(gplan[scan_index])begin
     if(slot_count>=MAX_BLOCKS)begin g_error<=1;gstate<=G_IDLE;end
     else begin desc_mb[slot_count]<=scan_mb;desc_block[slot_count]<=scan_block;current_block<=scan_block;sample_cap_count<=0;gstate<=G_START;end
    end else begin
     scan_index<=scan_index+1'b1;if(scan_block==5)begin scan_block<=0;scan_mb<=scan_mb+1'b1;end else scan_block<=scan_block+1'b1;
    end
   end
   G_START:begin gstart<=1;gstate<=G_WRITE;end
   G_WRITE:begin gwe<=1;gstate<=G_END;end
   G_END:begin gend<=1;gstate<=G_WAIT;end
   G_WAIT:if(transform_done)begin
    if((sample_cap_count+(tvalid?7'd1:7'd0))!=7'd64)g_error<=1;
    slot_count<=slot_count+1'b1;scan_index<=scan_index+1'b1;
    if(scan_block==5)begin scan_block<=0;scan_mb<=scan_mb+1'b1;end else scan_block<=scan_block+1'b1;
    gstate<=G_SCAN;
   end
   G_META:begin replay_valid<=1;replay_index<=6'h3f;replay_value<=$signed({8'hA1,map_byte_value(gmap,replay_map_byte)});
    if(replay_map_byte==5)begin replay_slot<=0;gstate<=G_DESC;end else replay_map_byte<=replay_map_byte+1'b1;end
   G_DESC:begin replay_valid<=1;replay_index<=6'h3f;replay_value<=$signed({4'hB,3'b000,desc_mb[replay_slot],desc_block[replay_slot]});replay_sample<=0;gstate<=G_SAMPLES;end
   G_SAMPLES:begin replay_valid<=1;replay_index<=replay_sample;replay_value<=gmem[replay_mem_index];
    if((replay_slot==0)&&(replay_sample==0))begin first_valid_reg<=1;first_value_reg<=gmem[replay_mem_index];end
    if(replay_sample==6'd63)begin if(replay_slot+1'b1>=slot_count)gstate<=G_FINISH;else begin replay_slot<=replay_slot+1'b1;gstate<=G_DESC;end end
    else replay_sample<=replay_sample+1'b1;end
   G_FINISH:begin replay_valid<=1;replay_index<=6'h3f;replay_value<=16'shA2FF;gstate<=G_IDLE;end
   default:;
  endcase
 end
end

assign decision_complete=general_mode?g_decision:old_decision;
assign residual_required=general_mode?g_required:old_required;
assign residual_success=general_mode?g_success:old_success;
assign mixed_replay_active=general_mode&&((gstate==G_META)||(gstate==G_DESC)||(gstate==G_SAMPLES)||(gstate==G_FINISH));
assign first_sample_valid=general_mode?first_valid_reg:tfvalid;
assign first_sample_value=general_mode?first_value_reg:tfvalue;
assign residual_sample_valid=general_mode?replay_valid:tvalid;
assign residual_sample_index=general_mode?replay_index:tidx;
assign residual_sample_value=general_mode?replay_value:tvalue;
assign probe_error=terr|g_error|(!general_mode&&old_parser_error);
endmodule
