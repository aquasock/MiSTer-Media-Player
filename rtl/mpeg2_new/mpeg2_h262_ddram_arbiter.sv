//============================================================================
// MiSTer Media Player - Phase 1S/1T DDR request arbiter
//
// kate - Phase 1R introduced concurrent decoder writes and presentation reads.
// Phase 1S repeats the two-bank ping-pong cycle, so the arbiter must also enforce
// frame-bank ownership: a new picture may not overwrite the bank still owned by
// the display reader.
//
// Reader requests have priority. Once a read burst is accepted, hold every
// other client off until every response word for that burst has returned. The
// display reader's accepted bank transfers presentation ownership; prediction
// reads never alter that ownership.
//
// kate - Phase 1T-f adds one decoder-side prediction reader. Display reads keep
// highest priority, prediction reads are next, and writes remain lowest priority.
// Response-ready is demultiplexed by the recorded read owner so the framebuffer
// cannot consume a prediction response and vice versa.
//
// kate - Phase 1T-o removes the temporary Phase 1T-m/n prediction-write command.
// The first reconstructed P block now uses the ordinary block writer, so this
// arbiter returns to three explicit clients: presentation read, prediction read,
// and reconstruction write. No prediction-side write encoding remains.
//============================================================================

module mpeg2_h262_ddram_arbiter
(
    input  wire        clk,
    input  wire        reset,

    input  wire [7:0]  writer_burstcnt,
    input  wire [28:0] writer_addr,
    input  wire        writer_rd,
    input  wire [63:0] writer_din,
    input  wire [7:0]  writer_be,
    input  wire        writer_we,
    output wire        writer_busy,

    input  wire [7:0]  reader_burstcnt,
    input  wire [28:0] reader_addr,
    input  wire        reader_rd,
    output wire        reader_busy,
    output wire        reader_dout_ready,

    input  wire [7:0]  prediction_burstcnt,
    input  wire [28:0] prediction_addr,
    input  wire        prediction_rd,
    output wire        prediction_busy,
    output wire        prediction_dout_ready,

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
reg       read_owner_prediction;
reg [7:0] read_words_remaining;
reg       reader_bank_valid;
reg       reader_frame_bank;

wire writer_targets_reader_bank =
    reader_bank_valid && (writer_addr[16] == reader_frame_bank);

wire grant_reader =
    !read_outstanding && reader_rd;

wire grant_prediction =
    !read_outstanding && !reader_rd && prediction_rd;

wire grant_writer =
    !read_outstanding && !reader_rd && !prediction_rd &&
    writer_we && !writer_targets_reader_bank;

assign reader_busy =
    grant_reader ? ddram_busy : 1'b1;

assign prediction_busy =
    grant_prediction ? ddram_busy : 1'b1;

assign writer_busy =
    grant_writer ? ddram_busy : 1'b1;

assign ddram_burstcnt =
    grant_reader ? reader_burstcnt :
    grant_prediction ? prediction_burstcnt :
    grant_writer ? writer_burstcnt : 8'd0;

assign ddram_addr =
    grant_reader ? reader_addr :
    grant_prediction ? prediction_addr :
    grant_writer ? writer_addr : 29'd0;

assign ddram_rd =
    grant_reader ? 1'b1 :
    grant_prediction ? 1'b1 : 1'b0;

assign ddram_din =
    grant_writer ? writer_din : 64'd0;

assign ddram_be =
    grant_writer ? writer_be : 8'hFF;

assign ddram_we =
    grant_writer ? writer_we : 1'b0;

assign reader_dout_ready =
    read_outstanding && !read_owner_prediction && ddram_dout_ready;

assign prediction_dout_ready =
    read_outstanding && read_owner_prediction && ddram_dout_ready;

always @(posedge clk) begin
    if (reset) begin
        read_outstanding      <= 1'b0;
        read_owner_prediction <= 1'b0;
        read_words_remaining  <= 8'd0;
        reader_bank_valid     <= 1'b0;
        reader_frame_bank     <= 1'b0;
    end
    else begin
        if (!read_outstanding) begin
            if (grant_reader && !ddram_busy) begin
                read_outstanding      <= 1'b1;
                read_owner_prediction <= 1'b0;
                read_words_remaining  <= reader_burstcnt;
                reader_bank_valid     <= 1'b1;
                reader_frame_bank     <= reader_addr[16];
            end
            else if (grant_prediction && !ddram_busy) begin
                read_outstanding      <= 1'b1;
                read_owner_prediction <= 1'b1;
                read_words_remaining  <= prediction_burstcnt;
            end
        end
        else if (ddram_dout_ready) begin
            if (read_words_remaining <= 8'd1) begin
                read_outstanding      <= 1'b0;
                read_owner_prediction <= 1'b0;
                read_words_remaining  <= 8'd0;
            end
            else begin
                read_words_remaining <= read_words_remaining - 8'd1;
            end
        end
    end
end

wire unused_writer_rd = writer_rd;

endmodule
