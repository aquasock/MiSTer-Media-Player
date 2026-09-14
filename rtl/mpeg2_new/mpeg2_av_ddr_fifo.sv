// Compressed-video queue at physical DDR 0x30400000..0x30bfffff.
// Each 64-bit word carries {EOF, PTS_valid, PTS[32:0], byte[7:0]}.
// Framebuffers occupy 0x30000000..0x3027ffff. One read may be in flight;
// prefetch occupancy and unread DDR occupancy are accounted independently.
module mpeg2_av_ddr_fifo #(
    parameter ADDRESS_BITS=20,
    parameter [28:0] BASE=29'h06080000
)(
    input wire clk,reset,
    input wire [42:0] input_data,
    input wire input_valid,
    output wire input_ready,
    output reg [42:0] output_data,
    output reg output_valid,
    input wire output_ready,
    output wire [28:0] mem_addr,
    output wire [63:0] mem_data,
    output wire mem_read,mem_write,
    input wire mem_busy,
    input wire [63:0] mem_q,
    input wire mem_q_valid,
    output wire [ADDRESS_BITS:0] ram_level
);
reg [ADDRESS_BITS-1:0] head,tail;
reg [ADDRESS_BITS:0] count;
reg [42:0] pending_data;
reg pending_valid,read_pending;
assign ram_level=count;
wire room=count < (1<<ADDRESS_BITS);
wire want_read=count!=0 && !read_pending && (!output_valid||output_ready);
assign mem_read=want_read;
assign mem_write=pending_valid&&room&&!want_read;
assign mem_addr=BASE+{{(29-ADDRESS_BITS){1'b0}},(want_read ? head:tail)};
assign mem_data={21'd0,pending_data};
wire read_accept=mem_read&&!mem_busy;
wire write_accept=mem_write&&!mem_busy;
assign input_ready=!pending_valid||write_accept;
always @(posedge clk) begin
    if(reset) begin
        head<=0;tail<=0;count<=0;pending_valid<=0;read_pending<=0;
        output_valid<=0;output_data<=0;pending_data<=0;
    end else begin
        if(write_accept) begin tail<=tail+1'b1; pending_valid<=0; end
        if(input_valid&&input_ready) begin pending_data<=input_data;pending_valid<=1; end
        if(output_valid&&output_ready) output_valid<=0;
        if(read_accept) begin head<=head+1'b1;read_pending<=1; end
        if(mem_q_valid&&(read_pending||read_accept)) begin
            read_pending<=0; output_valid<=1;output_data<=mem_q[42:0];
        end
        case({write_accept,read_accept})
            2'b10:count<=count+1'b1;
            2'b01:count<=count-1'b1;
            default:count<=count;
        endcase
    end
end
endmodule
