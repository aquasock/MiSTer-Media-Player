// Keep the resolved color matrix with the persisted picture, as for its PTS.
// Auto supports matrix 1 (709), 5/6 (601); missing/other tags use the project's
// 601 compatibility fallback. This does not interpret primaries or transfer curves.
module mpeg2_h262_picture_color(
 input wire clk, reset,
 input wire colour_description_valid,
 input wire [7:0] matrix_coefficients,
 input wire picture_start, picture_is_b, decode_scratch_bank,
 input wire b_picture_complete,
 input wire [1:0] active_frame_bank, display_frame_bank,
 input wire display_scratch, display_scratch_bank,
 output wire display_bt709
);
reg current_bt709, current_is_b;
reg [3:0] frame_bt709;
reg [1:0] scratch_bt709;
reg [1:0] active_frame_bank_q;
reg b_picture_complete_q;
wire reference_commit=(active_frame_bank!=active_frame_bank_q)&&!current_is_b;
wire scratch_commit=b_picture_complete&&!b_picture_complete_q&&current_is_b;
assign display_bt709=display_scratch ? scratch_bt709[display_scratch_bank] :
                                     frame_bt709[display_frame_bank];
always @(posedge clk) begin
 if(reset) begin
  current_bt709<=0; current_is_b<=0;
  frame_bt709<=0; scratch_bt709<=0;
  active_frame_bank_q<=0; b_picture_complete_q<=0;
 end else begin
  active_frame_bank_q<=active_frame_bank;
  b_picture_complete_q<=b_picture_complete;
  if(picture_start) begin
   current_bt709<=colour_description_valid&&(matrix_coefficients==8'd1);
   current_is_b<=picture_is_b;
  end
  // Nonblocking writes preserve the retiring picture when the following
  // header is classified on the same edge.
  if(reference_commit) frame_bt709[active_frame_bank_q]<=current_bt709;
  if(scratch_commit) scratch_bt709[decode_scratch_bank]<=current_bt709;
 end
end
endmodule
