// Single-clock elastic FIFO with a registered, stable output and block RAM.
module av_stream_fifo #(parameter WIDTH=42, ADDRESS_BITS=10)(
    input wire clk,reset,
    input wire [WIDTH-1:0] input_data,
    input wire input_valid,
    output wire input_ready,
    output reg [WIDTH-1:0] output_data,
    output reg output_valid,
    input wire output_ready,
    output wire empty,
    output wire [ADDRESS_BITS:0] ram_level
);
reg [WIDTH-1:0] mem [0:(1<<ADDRESS_BITS)-1];
reg [ADDRESS_BITS-1:0] head,tail;
reg [ADDRESS_BITS:0] count;
assign input_ready=count<(1<<ADDRESS_BITS);
wire push=input_ready&&input_valid;
wire pop=count!=0&&(!output_valid||output_ready);
assign ram_level=count;
assign empty=count==0&&!output_valid;
always @(posedge clk) begin
    if(push) mem[tail]<=input_data;
    if(pop) output_data<=mem[head];
    if(reset) begin head<=0;tail<=0;count<=0;output_valid<=0;end
    else begin
        if(push) tail<=tail+1'b1;
        if(output_valid&&output_ready) output_valid<=0;
        if(pop) begin head<=head+1'b1;output_valid<=1;end
        case({push,pop})
            2'b10:count<=count+1'b1;
            2'b01:count<=count-1'b1;
            default:count<=count;
        endcase
    end
end
endmodule
