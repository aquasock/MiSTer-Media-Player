//============================================================================
// MiSTer Media Player - Phase 1S DDR request arbiter
//
// kate - Phase 1R introduced concurrent decoder writes and presentation reads.
// Phase 1S repeats the two-bank ping-pong cycle, so the arbiter must also enforce
// frame-bank ownership: a new picture may not overwrite the bank still owned by
// the display reader.
//
// Reader requests have priority.  Once a read burst is accepted, hold the
// writer off until every response word for that burst has returned.  In
// addition, remember the frame-bank bit of the most recently accepted display
// read and refuse writes targeting that same bank.  The ownership latch starts
// invalid so picture 1 can populate bank 0 before the framebuffer has issued its
// first read.  When publication moves to the other bank, the first accepted read
// there transfers ownership and releases the old bank for the next picture.
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
reg       reader_bank_valid;
reg       reader_frame_bank;

// The two Phase 1R/1S frame banks are separated by 0x10000 64-bit words.
// Plane offsets stay below that boundary, so address bit 16 identifies the
// selected frame bank for both reader and writer transactions.
wire writer_targets_reader_bank =
    reader_bank_valid && (writer_addr[16] == reader_frame_bank);

wire grant_reader = !read_outstanding && reader_rd;
wire grant_writer = !read_outstanding && !reader_rd && writer_we &&
                    !writer_targets_reader_bank;

// A client which is not selected must continue holding its request.  Both the
// writer and framebuffer already use ddram_busy as their request backpressure.
// A writer aimed at the currently displayed bank therefore remains stalled
// until a read from the newly published bank transfers reader ownership.
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
        reader_bank_valid     <= 1'b0;
        reader_frame_bank     <= 1'b0;
    end
    else begin
        if (!read_outstanding) begin
            if (grant_reader && !ddram_busy) begin
                read_outstanding     <= 1'b1;
                read_words_remaining <= reader_burstcnt;
                reader_bank_valid    <= 1'b1;
                reader_frame_bank    <= reader_addr[16];
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
