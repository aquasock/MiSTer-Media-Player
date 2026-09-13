// Bind PES PTS to the first picture prefix that STARTS after its marker.
// Watching bytes accepted by the decoder avoids associating a PES beginning
// inside a partly consumed picture header with that preceding picture.
module mpeg2_pes_picture_pts (
    input wire clk,reset,
    input wire [7:0] stream_data,
    input wire stream_valid,
    input wire metadata_valid,
    input wire [32:0] metadata_pts,
    output reg pts_valid,
    output reg [32:0] pts
);
reg [23:0] prefix;
reg [31:0] byte_offset, marker_offset;
reg [32:0] pending_pts;
reg pending_valid;
wire [31:0] prefix_distance=(byte_offset-32'd3)-marker_offset;
always @(posedge clk) begin
    pts_valid<=0;
    if(reset) begin
        prefix<=24'hffffff;byte_offset<=0;marker_offset<=0;pending_valid<=0;
        pending_pts<=0;pts<=0;
    end else begin
        if(metadata_valid) begin
            pending_valid<=1;pending_pts<=metadata_pts;
            marker_offset<=byte_offset+(stream_valid?32'd1:32'd0);
        end
        if(stream_valid) begin
            prefix<={prefix[15:0],stream_data};byte_offset<=byte_offset+32'd1;
            if(prefix==24'h000001&&stream_data==0&&pending_valid&&!prefix_distance[31]) begin
                pts_valid<=1;pts<=pending_pts;pending_valid<=0;
            end
        end
    end
end
endmodule
