// Post-filter, pre-menu integration. Decoder and transport have no dependency
// on renderer readiness. Only a coalescing presentation-state snapshot crosses.
module media_player_overlay(
 input wire control_clk,video_clk,input wire [90:0] control_state,
 input wire [23:0] rgb,input wire hs,vs,de,
 output wire [23:0] rgb_out,output wire hs_out,vs_out,de_out
);
wire [90:0] state_hdmi;
video_config_cdc #(.WIDTH(91)) player_ui_config(
 .src_clk(control_clk),.dst_clk(video_clk),.src_data(control_state),.dst_data(state_hdmi));
wire text_we,object_we,commit,pending,acknowledged;
wire [8:0] text_addr;
wire [7:0] text_data;
wire [3:0] object_addr,scale;
wire [55:0] object_data;
wire [15:0] epoch;
wire [1:0] groups;
wire [11:0] width,height;
media_ui_scene scene(
 .clk(video_clk),.state_in(state_hdmi),.width(width),.height(height),.pending(pending),.acknowledged(acknowledged),
 .text_we(text_we),.text_addr(text_addr),.text_data(text_data),
 .object_we(object_we),.object_addr(object_addr),.object_data(object_data),
 .commit(commit),.commit_epoch(epoch),.commit_groups(groups),.commit_scale(scale),
 .aux_text_we(1'b0),.aux_text_addr(8'd0),.aux_text_data(8'd0),
 .aux_object_we(1'b0),.aux_object_addr(2'd0),.aux_object_data(56'd0),
 .aux_commit(1'b0),.aux_epoch(16'd0),.aux_visible(1'b0));
media_overlay_compositor compositor(
 .clk(video_clk),.rgb(rgb),.hs(hs),.vs(vs),.de(de),.current_epoch(state_hdmi[90:75]),
 .text_we(text_we),.text_addr(text_addr),.text_data(text_data),
 .object_we(object_we),.object_addr(object_addr),.object_data(object_data),
 .commit(commit),.commit_epoch(epoch),.commit_groups(groups),.commit_scale(scale),
 .pending(pending),.acknowledged(acknowledged),.width(width),.height(height),
 .rgb_out(rgb_out),.hs_out(hs_out),.vs_out(vs_out),.de_out(de_out));
endmodule
