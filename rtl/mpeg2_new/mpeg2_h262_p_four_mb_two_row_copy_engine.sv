//============================================================================
// MiSTer Media Player - controlled 2x2-macroblock H.262 P copy/readback engine
//
// Standards authority: core-standards.md, source_id H262.
//   H262-003 prediction samples come from the applicable reference picture.
//   H262-006 4:2:0 block order is Y0,Y1,Y2,Y3,Cb,Cr.
//   H262-008 slice vertical position selects the macroblock row.
//   H262-009 macroblock addressing advances within each slice row.
//
// kate - Phase 1T-s proves four motion-forward-only P macroblocks arranged as
// two columns by two slice rows.  All decoded vectors are (0,0) and there is no
// residual, so each reconstructed pel equals the colocated reference pel.  All
// twenty-four 8x8 blocks are copied through the ordinary DDR block writer and
// then read back from the destination bank for exact comparison.
//============================================================================

module mpeg2_h262_p_four_mb_two_row_copy_engine
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
    DDR_Y_BASE     = 29'h06000000,
    DDR_CB_BASE    = 29'h0600A8C0,
    DDR_CR_BASE    = 29'h0600D2F0,
    DDR_BANK_WORDS = 29'h00010000;

localparam READ_REFERENCE = 1'b0,
           READ_VERIFY    = 1'b1;

function automatic [28:0] row_times_90;
    input [4:0] row;
    reg [28:0] r;
    begin
        r = {24'd0, row};
        row_times_90 = (r << 6) + (r << 4) + (r << 3) + (r << 1);
    end
endfunction

function automatic [28:0] row_times_45;
    input [3:0] row;
    reg [28:0] r;
    begin
        r = {25'd0, row};
        row_times_45 = (r << 5) + (r << 3) + (r << 2) + r;
    end
endfunction

function automatic [28:0] block_row_address;
    input [28:0] bank_offset;
    input [1:0]  macroblock_index;
    input [2:0]  block_index;
    input [2:0]  row_index;
    reg [4:0] luma_row;
    reg [1:0] luma_word;
    reg [3:0] chroma_row;
    begin
        if (block_index < 3'd4) begin
            // macroblock_index[1] is the slice row and [0] is the column.
            // Y0/Y1 occupy rows +0..7; Y2/Y3 occupy rows +8..15.
            luma_row  = {macroblock_index[1], 4'b0000} +
                        {1'b0, block_index[1], row_index};
            luma_word = {macroblock_index[0], 1'b0} + block_index[0];
            block_row_address = DDR_Y_BASE + bank_offset +
                                row_times_90(luma_row) +
                                {27'd0, luma_word};
        end
        else begin
            // 4:2:0 chroma has one 8x8 Cb and Cr block per macroblock.
            // The second macroblock row begins eight chroma rows lower.
            chroma_row = {macroblock_index[1], 3'b000} +
                         {1'b0, row_index};
            if (block_index == 3'd4)
                block_row_address = DDR_CB_BASE + bank_offset +
                                    row_times_45(chroma_row) +
                                    {28'd0, macroblock_index[0]};
            else
                block_row_address = DDR_CR_BASE + bank_offset +
                                    row_times_45(chroma_row) +
                                    {28'd0, macroblock_index[0]};
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

reg        started;
reg        latched_reference_bank;
reg        latched_destination_bank;
reg        read_kind;
reg        request_active;
reg        response_waiting;
reg [1:0]  macroblock_index;
reg [2:0]  block_index;
reg [2:0]  row_index;
reg [19:0] timeout;

reg        emit_active;
reg        waiting_for_store;
reg [5:0]  emit_index;

wire [28:0] reference_bank_offset =
    latched_reference_bank ? DDR_BANK_WORDS : 29'd0;
wire [28:0] destination_bank_offset =
    latched_destination_bank ? DDR_BANK_WORDS : 29'd0;

assign ddram_burstcnt = request_active ? 8'd1 : 8'd0;
assign ddram_addr = request_active ?
    block_row_address(
        (read_kind == READ_REFERENCE) ?
            reference_bank_offset : destination_bank_offset,
        macroblock_index,
        block_index,
        row_index
    ) : 29'd0;
assign ddram_rd = request_active;

wire [2:0] emit_row  = emit_index[5:3];
wire [2:0] emit_lane = emit_index[2:0];
wire [4:0] luma_x =
    {macroblock_index[0], 4'b0000} +
    {1'b0, block_index[0], emit_lane};
wire [4:0] luma_y =
    {macroblock_index[1], 4'b0000} +
    {1'b0, block_index[1], emit_row};
wire [3:0] chroma_x =
    {macroblock_index[0], 3'b000} + {1'b0, emit_lane};
wire [3:0] chroma_y =
    {macroblock_index[1], 3'b000} + {1'b0, emit_row};

assign store_select         = emit_active;
assign store_pixel_value    = byte_at(reference_rows[emit_row], emit_lane);
assign store_pixel_valid    = emit_active;
assign store_block_start    = emit_active && (emit_index == 6'd0);
assign store_block_complete = emit_active && (emit_index == 6'd63);

// The accepted Phase 1T-q writer carries P chroma component identity in
// pixel_x[11:10] while its public component input remains Y:
//   01 = Cb, 10 = Cr.
assign store_pixel_x =
    (block_index < 3'd4) ? {7'd0, luma_x} :
    (block_index == 3'd4) ? {2'b01, 6'd0, chroma_x} :
                            {2'b10, 6'd0, chroma_x};
assign store_pixel_y =
    (block_index < 3'd4) ? {7'd0, luma_y} : {8'd0, chroma_y};

always @(posedge clk) begin
    if (reset) begin
        started                  <= 1'b0;
        latched_reference_bank   <= 1'b0;
        latched_destination_bank <= 1'b0;
        read_kind                <= READ_REFERENCE;
        request_active           <= 1'b0;
        response_waiting         <= 1'b0;
        macroblock_index         <= 2'd0;
        block_index              <= 3'd0;
        row_index                <= 3'd0;
        timeout                  <= 20'd0;
        emit_active              <= 1'b0;
        waiting_for_store        <= 1'b0;
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
            read_kind                <= READ_REFERENCE;
            macroblock_index         <= 2'd0;
            block_index              <= 3'd0;
            row_index                <= 3'd0;
            timeout                  <= 20'hFFFFF;

            if (!reference_valid ||
                (destination_bank == reference_bank)) begin
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

                    if ((macroblock_index == 2'd0) &&
                        (block_index == 3'd0) &&
                        (row_index == 3'd0)) begin
                        read_seen      <= 1'b1;
                        sample_value   <= ddram_dout[7:0];
                        sample_nonzero <= (ddram_dout[7:0] != 8'd0);
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

                    if ((macroblock_index == 2'd0) &&
                        (block_index == 3'd0) &&
                        (row_index == 3'd0) &&
                        (ddram_dout == reference_rows[0])) begin
                        persisted_value <= ddram_dout[7:0];
                    end

                    if (row_index == 3'd7) begin
                        if (block_index == 3'd5) begin
                            if (macroblock_index == 2'd3) begin
                                if (ddram_dout == reference_rows[7]) begin
                                    persisted_seen     <= 1'b1;
                                    reconstructed_seen <= 1'b1;
                                    timeout            <= 20'd0;
                                end
                            end
                            else begin
                                macroblock_index <= macroblock_index + 2'd1;
                                block_index      <= 3'd0;
                                row_index        <= 3'd0;
                                read_kind        <= READ_REFERENCE;
                                request_active   <= 1'b1;
                            end
                        end
                        else begin
                            block_index    <= block_index + 3'd1;
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
            if ((macroblock_index == 2'd0) &&
                (block_index == 3'd0) &&
                (emit_index == 6'd0)) begin
                reconstructed_value <= store_pixel_value;
            end

            if (emit_index == 6'd63) begin
                emit_active       <= 1'b0;
                waiting_for_store <= 1'b1;
            end
            else begin
                emit_index <= emit_index + 6'd1;
            end
        end

        if (waiting_for_store && store_block_stored) begin
            waiting_for_store <= 1'b0;
            read_kind         <= READ_VERIFY;
            row_index         <= 3'd0;
            request_active    <= 1'b1;
        end
    end
end

endmodule
