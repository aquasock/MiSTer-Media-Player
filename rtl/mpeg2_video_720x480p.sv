// Fixed 27 MHz, 858x525 total, 720x480 progressive raster.
// 60000/1001 Hz; negative sync polarity. Geometry reused from b3626a6.
module mpeg2_video_720x480p
(
	input  wire        clk,
	input  wire        reset,

	output wire [11:0] h_pos,
	output wire [11:0] v_pos,
	output wire        pixel_en,
	output wire        h_sync,
	output wire        v_sync
);

localparam integer H_ACTIVE = 720;
localparam integer H_FRONT  = 16;
localparam integer H_SYNC   = 62;
localparam integer H_BACK   = 60;
localparam integer H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;

localparam integer V_ACTIVE = 480;
localparam integer V_FRONT  = 9;
localparam integer V_SYNC   = 6;
localparam integer V_BACK   = 30;
localparam integer V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

reg [11:0] h_count;
reg [11:0] v_count;

always @(posedge clk) begin
	if (reset) begin
		h_count <= 12'd0;
		v_count <= 12'd0;
	end
	else if (h_count == H_TOTAL-1) begin
		h_count <= 12'd0;

		if (v_count == V_TOTAL-1)
			v_count <= 12'd0;
		else
			v_count <= v_count + 12'd1;
	end
	else begin
		h_count <= h_count + 12'd1;
	end
end

assign h_pos = h_count;
assign v_pos = v_count;

assign pixel_en =
	(h_count < H_ACTIVE) &&
	(v_count < V_ACTIVE);

assign h_sync = !(
	(h_count >= H_ACTIVE + H_FRONT) &&
	(h_count <  H_ACTIVE + H_FRONT + H_SYNC));

assign v_sync = !(
	(v_count >= V_ACTIVE + V_FRONT) &&
	(v_count <  V_ACTIVE + V_FRONT + V_SYNC));

endmodule
