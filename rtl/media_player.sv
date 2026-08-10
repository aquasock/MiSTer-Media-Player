module media_player
(
	input  wire       clk,
	input  wire       reset,

	output reg        ce_pix,

	output reg        HBlank,
	output reg        HSync,
	output reg        VBlank,
	output reg        VSync,

	output wire [7:0] video
);

reg [9:0] h_count;
reg [9:0] v_count;

// 20 MHz system clock from the existing template PLL.
// Divide by 2 for an approximately 10 MHz pixel enable,
// matching the basic timing behavior used by Template_MiSTer.
always @(posedge clk) begin
	if (reset) begin
		ce_pix <= 1'b0;
	end
	else begin
		ce_pix <= ~ce_pix;
	end
end

always @(posedge clk) begin
	if (reset) begin
		h_count <= 10'd0;
		v_count <= 10'd0;
	end
	else if (ce_pix) begin

		if (h_count == 10'd637) begin
			h_count <= 10'd0;

			if (v_count == 10'd261)
				v_count <= 10'd0;
			else
				v_count <= v_count + 10'd1;
		end
		else begin
			h_count <= h_count + 10'd1;
		end
	end
end

always @(posedge clk) begin
	if (reset) begin
		HBlank <= 1'b0;
		HSync  <= 1'b0;
		VBlank <= 1'b0;
		VSync  <= 1'b0;
	end
	else if (ce_pix) begin

		if (h_count == 10'd529)
			HBlank <= 1'b1;
		else if (h_count == 10'd0)
			HBlank <= 1'b0;

		if (h_count == 10'd544)
			HSync <= 1'b1;
		else if (h_count == 10'd590)
			HSync <= 1'b0;

		if (h_count == 10'd544) begin
			if (v_count == 10'd245)
				VSync <= 1'b1;
			else if (v_count == 10'd248)
				VSync <= 1'b0;

			if (v_count == 10'd240)
				VBlank <= 1'b1;
			else if (v_count == 10'd0)
				VBlank <= 1'b0;
		end
	end
end

// Simple first-stage MediaPlayer test image.
//
// Active screen is approximately 529 x 240 pixels.
// Produce four vertical grayscale bars so we can verify
// that our own RTL is now producing the video.

reg [7:0] pixel;

always @(*) begin
	if (HBlank || VBlank)
		pixel = 8'h00;
	else if (h_count < 10'd132)
		pixel = 8'h20;
	else if (h_count < 10'd264)
		pixel = 8'h60;
	else if (h_count < 10'd396)
		pixel = 8'hA0;
	else
		pixel = 8'hE0;
end

assign video = pixel;

endmodule
