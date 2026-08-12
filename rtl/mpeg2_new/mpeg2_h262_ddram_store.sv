//============================================================================
// MiSTer Media Player - Phase 1Oa full-precision H.262 DDR3 picture writer
//
// kate - This module is the first external-frame-store proof for the new H.262
// decoder.  It deliberately changes only one architectural boundary:
// reconstructed 8-bit Y/Cb/Cr samples are persisted to MiSTer's DDR3 service
// port before the parser is allowed to submit the next 8x8 block.
//
// The existing Phase 1N on-chip presentation framebuffer remains active in
// parallel for this proof.  Therefore a normal picture plus USER=ON demonstrates
// that the already-proven decoder/display path still works while every block has
// also traversed the new DDR write/backpressure path.
//
// Storage format (implementation choice, not an H.262 requirement):
//   - Planar Y, Cb, Cr.
//   - Fixed maximum strides: Y=720 pels, Cb/Cr=360 pels.
//   - Eight adjacent 8-bit pels packed into one 64-bit DDR word, byte 0 first.
//   - Each reconstructed 8x8 block is staged locally, then written as eight
//     single-word DDR transactions separated by the component row stride.
//
// DDR_BASE reuses the private region selected by this project's frozen
// MPEG2FPGA DDR bridge. DDRAM_ADDR is a 64-bit-word address, so 29'h04000000
// corresponds to byte address 0x20000000.
//============================================================================

module mpeg2_h262_ddram_store
(
    input  wire        clk,
    input  wire        reset,

    input  wire [7:0]  pixel_value,
    // 0 = Y, 1 = Cb, 2 = Cr.
    input  wire [1:0]  pixel_component,
    input  wire [11:0] pixel_x,
    input  wire [11:0] pixel_y,
    input  wire        pixel_valid,
    input  wire        block_start,
    input  wire        block_complete,

    // One-cycle pulse after all eight 64-bit rows of the current reconstructed
    // block have been accepted by MiSTer's DDR service.
    output reg         block_stored,

    // Sticky diagnostics.
    output reg         write_seen,
    output reg         store_error,

    input  wire        ddram_busy,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,
    output wire [63:0] ddram_din,
    output wire [7:0]  ddram_be,
    output wire        ddram_we
);

localparam integer SRC_WIDTH       = 720;
localparam integer SRC_HEIGHT      = 480;
localparam integer CHROMA_WIDTH    = SRC_WIDTH / 2;
localparam integer CHROMA_HEIGHT   = SRC_HEIGHT / 2;

localparam [1:0] COMPONENT_Y  = 2'd0;
localparam [1:0] COMPONENT_CB = 2'd1;
localparam [1:0] COMPONENT_CR = 2'd2;

localparam [28:0] DDR_Y_BASE  = 29'h04000000;
localparam [28:0] DDR_CB_BASE = 29'h0400A8C0; // + 43200 Y words
localparam [28:0] DDR_CR_BASE = 29'h0400D2F0; // + 10800 Cb words

function automatic [28:0] row_times_90;
    input [11:0] row;
    reg [28:0] r;
    begin
        r = {17'd0, row};
        row_times_90 = (r << 6) + (r << 4) + (r << 3) + (r << 1);
    end
endfunction

function automatic [28:0] row_times_45;
    input [11:0] row;
    reg [28:0] r;
    begin
        r = {17'd0, row};
        row_times_45 = (r << 5) + (r << 3) + (r << 2) + r;
    end
endfunction

// One 8x8 block = eight 64-bit row words.  These are explicit registers rather
// than an inferred RAM so this proof does not consume additional M10K blocks
// while the known-good Phase 1N display framebuffer is still present.
reg [63:0] block_row0;
reg [63:0] block_row1;
reg [63:0] block_row2;
reg [63:0] block_row3;
reg [63:0] block_row4;
reg [63:0] block_row5;
reg [63:0] block_row6;
reg [63:0] block_row7;
reg [63:0] row_shift;
wire [63:0] row_shift_next = {pixel_value, row_shift[63:8]};

reg        capture_active;
reg        flush_pending;
reg [1:0]  active_component;
reg [11:0] block_origin_x;
reg [11:0] block_origin_y;

reg        write_active;
reg [2:0]  write_row;
reg [28:0] write_address;

wire geometry_valid =
    ((active_component == COMPONENT_Y) &&
     (block_origin_x < SRC_WIDTH) &&
     (block_origin_y < SRC_HEIGHT)) ||
    (((active_component == COMPONENT_CB) ||
      (active_component == COMPONENT_CR)) &&
     (block_origin_x < CHROMA_WIDTH) &&
     (block_origin_y < CHROMA_HEIGHT));

wire [28:0] first_word_address =
    (active_component == COMPONENT_Y) ?
        (DDR_Y_BASE + row_times_90(block_origin_y) +
         {20'd0, block_origin_x[11:3]}) :
    (active_component == COMPONENT_CB) ?
        (DDR_CB_BASE + row_times_45(block_origin_y) +
         {20'd0, block_origin_x[11:3]}) :
        (DDR_CR_BASE + row_times_45(block_origin_y) +
         {20'd0, block_origin_x[11:3]});

wire [28:0] row_stride =
    (active_component == COMPONENT_Y) ? 29'd90 : 29'd45;

// Keep a full write request stable for as long as DDRAM_BUSY is asserted.
assign ddram_burstcnt = write_active ? 8'd1 : 8'd0;
assign ddram_addr     = write_active ? write_address : 29'd0;
assign ddram_rd       = 1'b0;
assign ddram_din =
    (write_row == 3'd0) ? block_row0 :
    (write_row == 3'd1) ? block_row1 :
    (write_row == 3'd2) ? block_row2 :
    (write_row == 3'd3) ? block_row3 :
    (write_row == 3'd4) ? block_row4 :
    (write_row == 3'd5) ? block_row5 :
    (write_row == 3'd6) ? block_row6 : block_row7;
assign ddram_be       = 8'hFF;
assign ddram_we       = write_active;

always @(posedge clk) begin
    if (reset) begin
        capture_active   <= 1'b0;
        flush_pending    <= 1'b0;
        active_component <= COMPONENT_Y;
        block_origin_x   <= 12'd0;
        block_origin_y   <= 12'd0;
        write_active     <= 1'b0;
        write_row        <= 3'd0;
        write_address    <= 29'd0;
        row_shift        <= 64'd0;
        block_stored     <= 1'b0;
        write_seen       <= 1'b0;
        store_error      <= 1'b0;
    end
    else begin
        block_stored <= 1'b0;

        if (block_start) begin
            if (capture_active || flush_pending || write_active)
                store_error <= 1'b1;

            capture_active   <= 1'b1;
            active_component <= pixel_component;
            block_origin_x   <= {pixel_x[11:3], 3'b000};
            block_origin_y   <= {pixel_y[11:3], 3'b000};
        end

        if (pixel_valid) begin
            if (!(capture_active || block_start)) begin
                store_error <= 1'b1;
            end
            else begin
                // Reconstruction is already proven to emit sample_index 0..63
                // in row-major order.  Shift one byte per pel; at X lane 7 the
                // resulting word is {pel7,...,pel0}, so DDR byte 0 is pel0.
                row_shift <= row_shift_next;

                if (pixel_x[2:0] == 3'd7) begin
                    case (pixel_y[2:0])
                        3'd0: block_row0 <= row_shift_next;
                        3'd1: block_row1 <= row_shift_next;
                        3'd2: block_row2 <= row_shift_next;
                        3'd3: block_row3 <= row_shift_next;
                        3'd4: block_row4 <= row_shift_next;
                        3'd5: block_row5 <= row_shift_next;
                        3'd6: block_row6 <= row_shift_next;
                        3'd7: block_row7 <= row_shift_next;
                    endcase
                end
            end
        end

        if (block_complete) begin
            if (!capture_active || flush_pending || write_active)
                store_error <= 1'b1;

            capture_active <= 1'b0;
            flush_pending  <= 1'b1;
        end

        if (!write_active && flush_pending) begin
            if (!geometry_valid) begin
                store_error   <= 1'b1;
                flush_pending <= 1'b0;
                block_stored  <= 1'b1;
            end
            else begin
                write_row     <= 3'd0;
                write_address <= first_word_address;
                write_active  <= 1'b1;
            end
        end
        else if (write_active && !ddram_busy) begin
            // Current ddram_addr/ddram_din/ddram_we have been accepted.
            write_seen <= 1'b1;

            if (write_row == 3'd7) begin
                write_active  <= 1'b0;
                flush_pending <= 1'b0;
                block_stored  <= 1'b1;
            end
            else begin
                write_row     <= write_row + 3'd1;
                write_address <= write_address + row_stride;
            end
        end
    end
end

endmodule
