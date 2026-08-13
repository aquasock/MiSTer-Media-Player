//============================================================================
// MiSTer Media Player - Phase 1T controlled P-picture stream hold
//
// kate - Phase 1T-n turns the previously passive first-P residual diagnostic
// into a narrowly backpressured proof boundary. The existing residual probe
// captures at most 256 bytes from the first P slice and begins its local decode
// when either the next start code is accepted or that 256-byte bound is reached.
// This controller observes the same accepted stream boundary and then holds the
// compressed-input FIFO so a following picture cannot begin writing the
// destination frame bank while the controlled P pel is reconstructed/persisted.
//
// Explicit-motion regressions release as soon as their already-proven P
// macroblock result is published and no residual is required. The controlled
// pattern-only residual case remains held until the reconstructed pel has made
// its DDR write/readback round trip. This is an implementation diagnostic
// boundary, not an H.262 syntax requirement.
//============================================================================

module mpeg2_h262_p_stream_hold
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    input  wire       p_picture_active,
    input  wire       p_macroblock_type_seen,
    input  wire       p_residual_required,
    input  wire       p_persistence_complete,

    output wire       stream_hold,
    output reg        hold_seen,
    output reg        hold_error
);

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);

reg       slice_capture_active;
reg [7:0] slice_capture_count;
reg       hold_active;
reg       proof_done;
reg [19:0] hold_timeout;

assign stream_hold = hold_active;

always @(posedge clk) begin
    if (reset) begin
        byte_window           <= 32'd0;
        slice_capture_active  <= 1'b0;
        slice_capture_count   <= 8'd0;
        hold_active           <= 1'b0;
        proof_done            <= 1'b0;
        hold_timeout          <= 20'd0;
        hold_seen             <= 1'b0;
        hold_error            <= 1'b0;
    end
    else begin
        if (stream_valid) begin
            byte_window <= byte_window_next;

            if (!proof_done && p_picture_active) begin
                if (slice_capture_active) begin
                    if (start_code_now) begin
                        slice_capture_active <= 1'b0;
                        hold_active          <= 1'b1;
                        hold_seen            <= 1'b1;
                        hold_timeout         <= 20'hFFFFF;
                    end
                    else if (slice_capture_count == 8'hFF) begin
                        slice_capture_active <= 1'b0;
                        slice_capture_count  <= 8'd0;
                        hold_active          <= 1'b1;
                        hold_seen            <= 1'b1;
                        hold_timeout         <= 20'hFFFFF;
                    end
                    else begin
                        slice_capture_count <= slice_capture_count + 8'd1;
                    end
                end
                else if (slice_start_now) begin
                    slice_capture_active <= 1'b1;
                    slice_capture_count  <= 8'd0;
                end
            end
        end

        if (hold_active) begin
            if ((p_macroblock_type_seen && !p_residual_required) ||
                (p_residual_required && p_persistence_complete)) begin
                hold_active  <= 1'b0;
                proof_done   <= 1'b1;
                hold_timeout <= 20'd0;
            end
            else if (hold_timeout == 20'd1) begin
                hold_active  <= 1'b0;
                proof_done   <= 1'b1;
                hold_timeout <= 20'd0;
                hold_error   <= 1'b1;
            end
            else if (hold_timeout != 20'd0) begin
                hold_timeout <= hold_timeout - 20'd1;
            end
        end
    end
end

endmodule
