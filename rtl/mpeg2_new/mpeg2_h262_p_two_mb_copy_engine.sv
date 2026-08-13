//============================================================================
// MiSTer Media Player - Phase 1T-r controlled two-macroblock P copy engine
//
// Standards authority: core-standards.md, source_id H262.
// H262-001: decoded pel reconstruction/clipping.
// H262-005: zero-vector P prediction uses the corresponding reference sample.
// H262-006: 4:2:0 block order is Y0,Y1,Y2,Y3,Cb,Cr.
// H262-009: consecutive MBA increments place the second macroblock at x=16.
//
// The controlled test has two adjacent motion-forward-only macroblocks with
// vector (0,0) and no residual. Therefore every decoded pel equals its reference
// pel. The engine proves the complete first two 4:2:0 macroblocks by performing
// ordinary planar DDR reads, ordinary block-writer stores, and exact DDR
// readback. P publication/reference promotion remain outside this phase.
//============================================================================
module mpeg2_h262_p_two_mb_copy_engine
(
    input  wire        clk,
    input  wire        reset,
    input  wire        request,
    input  wire        reference_valid,
    input  wire        reference_bank,
    input  wire        destination_bank,
    input  wire        store_block_stored,
    input  wire        ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire        ddram_dout_ready,

    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,

    output wire        store_select,
    output wire [7:0]  store_pixel_value,
    output wire [11:0] store_pixel_x,
    output wire [11:0] store_pixel_y,
    output wire        store_pixel_valid,
    output wire        store_block_start,
    output wire        store_block_complete,

    output reg         read_seen,
    output reg  [7:0]  sample_value,
    output reg         sample_nonzero,
    output reg         reconstructed_seen,
    output reg  [7:0]  reconstructed_value,
    output reg         persisted_seen,
    output reg  [7:0]  persisted_value,
    output reg         error
);

localparam [28:0]
    DDR_Y_BASE  = 29'h06000000,
    DDR_CB_BASE = 29'h0600A8C0,
    DDR_CR_BASE = 29'h0600D2F0,
    BANK_WORDS  = 29'h00010000;

localparam READ_REFERENCE = 1'b0,
           READ_VERIFY    = 1'b1;

function automatic [28:0] row90;
    input [3:0] r;
    reg [28:0] x;
    begin
        x = {25'd0, r};
        row90 = (x << 6) + (x << 4) + (x << 3) + (x << 1);
    end
endfunction

function automatic [28:0] row45;
    input [2:0] r;
    reg [28:0] x;
    begin
        x = {26'd0, r};
        row45 = (x << 5) + (x << 3) + (x << 2) + x;
    end
endfunction

function automatic [28:0] block_row_addr;
    input [28:0] bank_offset;
    input        macroblock_index;
    input [2:0]  block_index;
    input [2:0]  row_index;
    reg [3:0] luma_row;
    reg [2:0] luma_word;
    begin
        if (block_index < 3'd4) begin
            luma_row  = {block_index[1], row_index};
            luma_word = {macroblock_index, 1'b0} + block_index[0];
            block_row_addr = DDR_Y_BASE + bank_offset +
                             row90(luma_row) + {26'd0, luma_word};
        end
        else if (block_index == 3'd4) begin
            block_row_addr = DDR_CB_BASE + bank_offset +
                             row45(row_index) + {28'd0, macroblock_index};
        end
        else begin
            block_row_addr = DDR_CR_BASE + bank_offset +
                             row45(row_index) + {28'd0, macroblock_index};
        end
    end
endfunction

function automatic [7:0] byte_at;
    input [63:0] word_value;
    input [2:0] lane;
    begin
        case (lane)
            3'd0: byte_at = word_value[7:0];
            3'd1: byte_at = word_value[15:8];
            3'd2: byte_at = word_value[23:16];
            3'd3: byte_at = word_value[31:24];
            3'd4: byte_at = word_value[39:32];
            3'd5: byte_at = word_value[47:40];
            3'd6: byte_at = word_value[55:48];
            default: byte_at = word_value[63:56];
        endcase
    end
endfunction

reg [63:0] reference_rows [0:7];
integer i;

reg started;
reg latched_reference_bank;
reg latched_destination_bank;
reg read_kind;
reg request_active;
reg response_waiting;
reg macroblock_index;
reg [2:0] block_index;
reg [2:0] row_index;
reg [19:0] timeout;

wire [28:0] reference_offset =
    latched_reference_bank ? BANK_WORDS : 29'd0;
wire [28:0] destination_offset =
    latched_destination_bank ? BANK_WORDS : 29'd0;

assign ddram_burstcnt = request_active ? 8'd1 : 8'd0;
assign ddram_addr = request_active ?
    block_row_addr(read_kind == READ_REFERENCE ?
                   reference_offset : destination_offset,
                   macroblock_index, block_index, row_index) : 29'd0;
assign ddram_rd = request_active;

reg emit_active;
reg waiting_store;
reg [5:0] emit_index;
wire [2:0] emit_row  = emit_index[5:3];
wire [2:0] emit_lane = emit_index[2:0];
wire [3:0] luma_x = {block_index[0], emit_lane};
wire [3:0] luma_y = {block_index[1], emit_row};
wire [4:0] macroblock_luma_x =
    {macroblock_index, 4'b0000} + {1'b0, luma_x};
wire [3:0] macroblock_chroma_x =
    {macroblock_index, 3'b000} + {1'b0, emit_lane};

assign store_select         = emit_active;
assign store_pixel_value    = byte_at(reference_rows[emit_row], emit_lane);
assign store_pixel_valid    = emit_active;
assign store_block_start    = emit_active && (emit_index == 6'd0);
assign store_block_complete = emit_active && (emit_index == 6'd63);

// The active Phase 1T-q DDR writer transports P chroma through pixel_x[11:10]
// while the public top-level P-store component remains Y: 01=Cb, 10=Cr.
assign store_pixel_x =
    (block_index < 3'd4) ? {7'd0, macroblock_luma_x} :
    (block_index == 3'd4) ? {2'b01, 6'd0, macroblock_chroma_x} :
                            {2'b10, 6'd0, macroblock_chroma_x};
assign store_pixel_y =
    (block_index < 3'd4) ? {8'd0, luma_y} : {9'd0, emit_row};

always @(posedge clk) begin
    if (reset) begin
        started                  <= 1'b0;
        latched_reference_bank   <= 1'b0;
        latched_destination_bank <= 1'b0;
        read_kind                <= READ_REFERENCE;
        request_active           <= 1'b0;
        response_waiting         <= 1'b0;
        macroblock_index         <= 1'b0;
        block_index              <= 3'd0;
        row_index                <= 3'd0;
        timeout                  <= 20'd0;
        emit_active              <= 1'b0;
        waiting_store            <= 1'b0;
        emit_index               <= 6'd0;
        read_seen                <= 1'b0;
        sample_value             <= 8'd0;
        sample_nonzero           <= 1'b0;
        reconstructed_seen       <= 1'b0;
        reconstructed_value      <= 8'd0;
        persisted_seen           <= 1'b0;
        persisted_value          <= 8'd0;
        error                    <= 1'b0;
        for (i = 0; i < 8; i = i + 1)
            reference_rows[i] <= 64'd0;
    end
    else begin
        if (request && !started) begin
            started                  <= 1'b1;
            latched_reference_bank   <= reference_bank;
            latched_destination_bank <= destination_bank;
            macroblock_index         <= 1'b0;
            block_index              <= 3'd0;
            row_index                <= 3'd0;
            read_kind                <= READ_REFERENCE;
            timeout                  <= 20'hFFFFF;

            if (!reference_valid ||
                (reference_bank == destination_bank)) begin
                error <= 1'b1;
            end
            else begin
                request_active <= 1'b1;
            end
        end

        if (started && !persisted_seen && (timeout != 20'd0)) begin
            timeout <= timeout - 20'd1;
            if (timeout == 20'd1)
                error <= 1'b1;
        end

        if (request_active && !ddram_busy) begin
            request_active   <= 1'b0;
            response_waiting <= 1'b1;
        end

        if (ddram_dout_ready) begin
            if (!response_waiting) begin
                error <= 1'b1;
            end
            else begin
                response_waiting <= 1'b0;

                if (read_kind == READ_REFERENCE) begin
                    reference_rows[row_index] <= ddram_dout;

                    if (!macroblock_index &&
                        (block_index == 3'd0) &&
                        (row_index == 3'd0)) begin
                        read_seen      <= 1'b1;
                        sample_value   <= ddram_dout[7:0];
                        sample_nonzero <= |ddram_dout[7:0];
                    end

                    if (row_index == 3'd7) begin
                        emit_index  <= 6'd0;
                        emit_active <= 1'b1;
                    end
                    else begin
                        row_index      <= row_index + 3'd1;
                        request_active <= 1'b1;
                    end
                end
                else begin
                    if (ddram_dout != reference_rows[row_index])
                        error <= 1'b1;

                    if (!macroblock_index &&
                        (block_index == 3'd0) &&
                        (row_index == 3'd0) &&
                        (ddram_dout == reference_rows[0])) begin
                        persisted_value <= ddram_dout[7:0];
                    end

                    if (row_index == 3'd7) begin
                        if ((ddram_dout != reference_rows[7])) begin
                            error <= 1'b1;
                        end
                        else if (macroblock_index &&
                                 (block_index == 3'd5)) begin
                            persisted_seen      <= 1'b1;
                            reconstructed_seen  <= 1'b1;
                            reconstructed_value <= reference_rows[0][7:0];
                            timeout             <= 20'd0;
                        end
                        else begin
                            if (block_index == 3'd5) begin
                                macroblock_index <= 1'b1;
                                block_index      <= 3'd0;
                            end
                            else begin
                                block_index <= block_index + 3'd1;
                            end

                            row_index      <= 3'd0;
                            read_kind      <= READ_REFERENCE;
                            request_active <= 1'b1;
                        end
                    end
                    else begin
                        row_index      <= row_index + 3'd1;
                        request_active <= 1'b1;
                    end
                end
            end
        end

        if (emit_active) begin
            if (emit_index == 6'd63) begin
                emit_active   <= 1'b0;
                waiting_store <= 1'b1;
            end
            else begin
                emit_index <= emit_index + 6'd1;
            end
        end

        if (waiting_store && store_block_stored) begin
            waiting_store  <= 1'b0;
            read_kind      <= READ_VERIFY;
            row_index      <= 3'd0;
            request_active <= 1'b1;
        end
    end
end

endmodule
