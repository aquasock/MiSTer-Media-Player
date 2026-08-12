//============================================================================
// MiSTer Media Player - Phase 1R DDR request arbiter
//
// kate - Phase 1R is the first architecture where the decoder can write a new
// frame while the DDR-backed presentation path is still reading the displayed
// frame.  Keep arbitration explicit in the 54 MHz DDR clock domain.
//
// Reader requests have priority.  Once a read burst is accepted, hold the
// writer off until every response word for that burst has returned.  This keeps
// MiSTer's shared DDR service sequencing simple and prevents a block write from
// being inserted into the middle of a line-cache read burst.
//============================================================================

module mpeg2_h262_ddram_arbiter
(
    input  wire        clk,
    input  wire        reset,

    // Writer client.  Current H.262 store issues one-word write transactions.
    input  wire [7:0]  writer_burstcnt,
    input  wire [28:0] writer_addr,
    input  wire        writer_rd,
    input  wire [63:0] writer_din,
    input  wire [7:0]  writer_be,
    input  wire        writer_we,
    output wire        writer_busy,

    // Reader client.  The framebuffer issues read bursts up to 64 words.
    input  wire [7:0]  reader_burstcnt,
    input  wire [28:0] reader_addr,
    input  wire        reader_rd,
    output wire        reader_busy,

    // MiSTer DDR service.
    input  wire        ddram_busy,
    input  wire        ddram_dout_ready,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,
    output wire [63:0] ddram_din,
    output wire [7:0]  ddram_be,
    output wire        ddram_we
);

reg       read_outstanding;
reg [7:0] read_words_remaining;

wire grant_reader = !read_outstanding && reader_rd;
wire grant_writer = !read_outstanding && !reader_rd && writer_we;

// A client which is not selected must continue holding its request.  Both the
// writer and framebuffer already use ddram_busy as their request backpressure.
assign reader_busy = grant_reader ? ddram_busy : 1'b1;
assign writer_busy = grant_writer ? ddram_busy : 1'b1;

assign ddram_burstcnt = grant_reader ? reader_burstcnt :
                        grant_writer ? writer_burstcnt : 8'd0;
assign ddram_addr     = grant_reader ? reader_addr :
                        grant_writer ? writer_addr : 29'd0;
assign ddram_rd       = grant_reader ? reader_rd : 1'b0;
assign ddram_din      = grant_writer ? writer_din : 64'd0;
assign ddram_be       = grant_writer ? writer_be : 8'hFF;
assign ddram_we       = grant_writer ? writer_we : 1'b0;

always @(posedge clk) begin
    if (reset) begin
        read_outstanding      <= 1'b0;
        read_words_remaining  <= 8'd0;
    end
    else begin
        if (!read_outstanding) begin
            if (grant_reader && !ddram_busy) begin
                read_outstanding     <= 1'b1;
                read_words_remaining <= reader_burstcnt;
            end
        end
        else if (ddram_dout_ready) begin
            if (read_words_remaining <= 8'd1) begin
                read_outstanding     <= 1'b0;
                read_words_remaining <= 8'd0;
            end
            else begin
                read_words_remaining <= read_words_remaining - 8'd1;
            end
        end
    end
end

endmodule
