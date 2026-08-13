//============================================================================
// MiSTer Media Player - Phase 1T-f/1T-g/1T-h H.262 reference-picture probe
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 7.6.4.
//   Prediction samples are read from the reference frame offset by the motion
//   vector. Motion vectors are in half-sample units. For horizontal half-sample
//   prediction with no vertical half-sample component, H.262 forms:
//
//       pel_pred = (pel_ref[x] + pel_ref[x+1]) // 2
//
//   where // is integer division rounded to the nearest integer (H.262 4.1).
//   Reference samples are unsigned, so this implementation is equivalently
//   (a + b + 1) >> 1.
//
// kate - Phase 1T-f consumes only the already-proven controlled forward vector
// (4,0). It performs one real luma DDR read from the current reference bank and
// selects one returned prediction sample. No P-picture reconstruction, frame
// persistence or reference promotion is performed here.
//
// kate - Phase 1T-g tightens that read from merely non-zero to the exact expected
// regression-vector sample value. In test_ip_motion_nores_end.m2v the reference
// I-picture reconstructs luma sample (9,0) as 8'd162. Requiring that exact byte
// makes the USER proof sensitive to the selected DDR word and byte lane. 162 is
// a controlled test-vector value, not an H.262 validity requirement.
//
// kate - Phase 1T-h deliberately proves the half-sample FILTER ARITHMETIC before
// changing the accepted motion-vector diagnostic to an odd vector. The existing
// (4,0) proof still selects packed DDR word 1. That returned word also contains
// adjacent reference samples (8,0) and (9,0) in byte lanes 0 and 1. Phase 1T-h
// applies the normative horizontal half-sample filter to those two real DDR
// samples, exports the filtered result as sample_value, and makes sample_nonzero
// depend on the filtered result. The existing exact (9,0)==162 check remains.
// This is an implementation diagnostic staging step: the current P motion vector
// is still even and therefore does not normatively request half-sample prediction.
// Odd-vector selection of this proven filter is intentionally left to the next
// phase so syntax/vector selection and interpolation arithmetic are not changed
// in the same hardware-test boundary.
//
// Diagnostic coordinate used by the existing integer-vector proof:
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

// kate - Phase 1T-g exact readback value for test_ip_motion_nores_end.m2v.
// This is deliberately an implementation regression constant rather than a
// normative video-syntax restriction.
localparam [7:0] DIAG_EXPECTED_SAMPLE = 8'd162;

reg        trigger_seen;
reg        request_active;
reg        response_waiting;
reg [28:0] request_address;
reg [2:0]  request_lane;
reg [15:0] proof_timeout;

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

// kate - Phase 1T-h horizontal half-sample arithmetic proof. Word 1 contains
// luma x=8 in lane 0 and x=9 in lane 1. H.262 7.6.4 uses nearest-integer //2;
// because both inputs are non-negative this is exactly (a+b+1)>>1.
wire [7:0] halfpel_left_sample  = ddram_dout[7:0];
wire [7:0] halfpel_right_sample = ddram_dout[15:8];
wire [8:0] halfpel_sum =
    {1'b0, halfpel_left_sample} + {1'b0, halfpel_right_sample};
wire [8:0] halfpel_rounded_sum = halfpel_sum + 9'd1;
wire [7:0] halfpel_filtered_sample = halfpel_rounded_sum[8:1];
wire [8:0] halfpel_filtered_twice =
    {halfpel_filtered_sample, 1'b0};
wire       halfpel_relation_ok =
    halfpel_sum[0] ?
        (halfpel_filtered_twice == (halfpel_sum + 9'd1)) :
        (halfpel_filtered_twice == halfpel_sum);

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
        proof_timeout    <= 16'd0;
        read_seen        <= 1'b0;
        sample_value     <= 8'd0;
        sample_nonzero   <= 1'b0;
        probe_error      <= 1'b0;
    end
    else begin
        // p_vector_proof_seen is the hardware-proven Phase 1T-e positive result.
        // Restrict this DDR/filter proof to the f_code=1,1 controlled vector so
        // the implied (4,0) value is unambiguous without yet broadening the
        // wrapper interface to a reusable motion-vector bus.
        if (p_vector_proof_seen && controlled_f_code && !trigger_seen) begin
            trigger_seen  <= 1'b1;
            proof_timeout <= 16'hFFFF;

            if (!reference_frame_valid) begin
                probe_error <= 1'b1;
            end
            else begin
                request_address <= calculated_address;
                request_lane    <= DIAG_REFERENCE_X[2:0];
                request_active  <= 1'b1;
            end
        end

        // A controlled Phase 1T-f/1T-g/1T-h proof must produce its one-word
        // response in a bounded interval. At 54 MHz this is about 1.2 ms, far
        // longer than normal single-read latency but short enough to fail before
        // the following I picture can make the legacy P-syntax USER gates true.
        if (trigger_seen && !read_seen && (proof_timeout != 16'd0)) begin
            proof_timeout <= proof_timeout - 16'd1;
            if (proof_timeout == 16'd1)
                probe_error <= 1'b1;
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
                proof_timeout    <= 16'd0;
                read_seen        <= 1'b1;

                // Phase 1T-g still proves the exact x=9 byte lane. Phase 1T-h
                // additionally consumes x=8/x=9 through the normative horizontal
                // half-sample filter. Make the existing top-level non-zero gate
                // depend on the FILTERED result, not the old integer sample.
                sample_value   <= halfpel_filtered_sample;
                sample_nonzero <= (halfpel_filtered_sample != 8'd0);

                if ((returned_sample != DIAG_EXPECTED_SAMPLE) ||
                    (halfpel_left_sample == halfpel_right_sample) ||
                    !halfpel_relation_ok ||
                    (halfpel_filtered_sample == 8'd0))
                    probe_error <= 1'b1;
            end
        end
    end
end

endmodule
