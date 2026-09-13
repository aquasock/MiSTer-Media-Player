// Replay queued video bytes, serializing a PES PTS through the existing
// private metadata extractor. The marker is internal and never enters DDR
// video decode. An explicit queued EOF cannot overtake retained video bytes.
module mpeg2_pes_metadata_expand(
    input wire clk,reset,
    input wire [42:0] input_data,
    input wire input_valid,
    output wire input_ready,
    output wire [7:0] output_data,
    output wire output_valid,
    input wire output_ready,
    output wire output_end
);
reg [3:0] index;
wire marked=input_data[41];
wire [39:0] payload={input_data[40:8],7'h64};
wire metadata=marked&&index<9;
assign output_end=input_valid&&input_data[42];
assign output_valid=input_valid&&!input_data[42];
assign input_ready=output_ready&&output_valid&&!metadata;
assign output_data=!metadata?input_data[7:0]:
    index==0||index==1?8'h00:index==2?8'h01:index==3?8'hb0:
    index==4?payload[39:32]:index==5?payload[31:24]:
    index==6?payload[23:16]:index==7?payload[15:8]:payload[7:0];
always @(posedge clk) begin
    if(reset) index<=0;
    else if(output_valid&&output_ready) begin
        if(metadata) index<=index+4'd1;
        else index<=0;
    end
end
endmodule
