// Stock Main T entries pulse one status bit. Store the selected value after
// the pulse clears; movie replacement does not reset user timing preferences.
module media_subtitle_select(
 input wire clk,reset,
 input wire [50:0] offset_select,speed_select,
 output reg [6:0] offset_code=0,speed_code=0
);
 always @(posedge clk)begin
  if(reset)begin offset_code<=0;speed_code<=0;end
  else begin
`include "rtl/media_subtitle_select_map.svh"
  end
 end
endmodule
