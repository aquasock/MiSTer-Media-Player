//============================================================================
// MiSTer Media Player - Phase 1T-f H.262 reference-picture DDR read probe
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 7.6.4.
//   Prediction samples are read from the reference frame offset by the motion
//   vector. Motion vectors are in half-sample units; an even component therefore
//   maps directly to an integer-sample displacement via DIV 2.
//
// kate - Phase 1T-f consumes only the already-proven controlled forward vector
// (4,0). It performs one real luma DDR read from the current reference bank and
// selects one returned prediction sample. No half-sample interpolation, residual
// addition, P-picture reconstruction, frame persistence or reference promotion is
// performed here.
//
// Diagnostic coordinate:
//   destination luma sample = (7,0)
//   vector (4,0) => integer displacement (+2,0)
//   reference sample = (9,0)
// This deliberately crosses the 8-pel DDR packing boundary so the proven motion
// vector changes the requested DDR word address from word 0 to word 1.
//============================================================================

module mpeg2_h262_reference_read_probe
(
    input  wire        clk,
    input  wire        reset,

    input  wire        p_vector_proof_seen,
    input  wire [3:0]  forward_f_code_horizontal,
    input  wire [3:0]  forward_f_code_vertical,

    input  wire        reference_frame_valid,
    input  wire        reference_frame_bank,

    input  wire        ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire        ddram_dout_ready,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,

    output reg         read_seen,
    output reg  [7:0]  sample_value,
    output reg         sample_nonzero,
    output reg         probe_error
);

localparam [28:0] DDR_Y_BASE     = 29'h06000000;
localparam [28:0] DDR_BANK_WORDS = 29'h00010000;

// Phase 1T-e's controlled f_code=1 explicit-motion test accepts only the
// reconstructed forward vector (4,0). H.262 7.6.4 converts that to (+2,0)
// integer luma samples. Destination x=7 therefore reads reference x=9.
localparam [11:0] DIAG_REFERENCE_X = 12'd9;
localparam [11:0] DIAG_REFERENCE_Y = 12'd0;

reg        trigger_seen;
reg        request_active;
reg        response_waiting;
reg [28:0] request_address;
reg [2:0]  request_lane;

function automatic [28:0] row_times_90;
    input [11:0] row;
    reg [28:0] r;
    begin
        r = {17'd0, row};
        row_times_90 = (r << 6) + (r << 4) + (r << 3) + (r << 1);
    end
endfunction

wire controlled_f_code =
    (forward_f_code_horizontal == 4'd1) &&
    (forward_f_code_vertical   == 4'd1);
wire [28:0] reference_bank_offset =
    reference_frame_bank ? DDR_BANK_WORDS : 29'd0;
wire [28:0] calculated_address =
    DDR_Y_BASE + reference_bank_offset +
    row_times_90(DIAG_REFERENCE_Y) +
    {20'd0, DIAG_REFERENCE_X[11:3]};

wire [7:0] returned_sample =
    (request_lane == 3'd0) ? ddram_dout[7:0]   :
    (request_lane == 3'd1) ? ddram_dout[15:8]  :
    (request_lane == 3'd2) ? ddram_dout[23:16] :
    (request_lane == 3'd3) ? ddram_dout[31:24] :
    (request_lane == 3'd4) ? ddram_dout[39:32] :
    (request_lane == 3'd5) ? ddram_dout[47:40] :
    (request_lane == 3'd6) ? ddram_dout[55:48] :
                             ddram_dout[63:56];

assign ddram_burstcnt = request_active ? 8'd1 : 8'd0;
assign ddram_addr     = request_active ? request_address : 29'd0;
assign ddram_rd       = request_active;

always @(posedge clk) begin
    if (reset) begin
        trigger_seen     <= 1'b0;
        request_active   <= 1'b0;
        response_waiting <= 1'b0;
        request_address  <= 29'd0;
        request_lane     <= 3'd0;
        read_seen        <= 1'b0;
        sample_value     <= 8'd0;
        sample_nonzero   <= 1'b0;
        probe_error      <= 1'b0;
    end
    else begin
        // p_vector_proof_seen is the hardware-proven Phase 1T-e positive result.
        // Restrict this first DDR proof to the f_code=1,1 controlled vector so
        // the implied (4,0) value is unambiguous without yet broadening the
        // wrapper interface to a reusable motion-vector bus.
        if (p_vector_proof_seen && controlled_f_code && !trigger_seen) begin
            trigger_seen <= 1'b1;

            if (!reference_frame_valid) begin
                probe_error <= 1'b1;
            end
            else begin
                request_address <= calculated_address;
                request_lane    <= DIAG_REFERENCE_X[2:0];
                request_active  <= 1'b1;
            end
        end

        if (request_active && !ddram_busy) begin
            request_active   <= 1'b0;
            response_waiting <= 1'b1;
        end

        if (ddram_dout_ready) begin
            if (!response_waiting) begin
                probe_error <= 1'b1;
            end
            else begin
                response_waiting <= 1'b0;
                sample_value     <= returned_sample;
                sample_nonzero   <= (returned_sample != 8'd0);
                read_seen        <= 1'b1;
            end
        end
    end
end

endmodule
