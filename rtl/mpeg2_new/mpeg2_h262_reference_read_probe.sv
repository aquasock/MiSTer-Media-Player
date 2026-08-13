//============================================================================
// MiSTer Media Player - Phase 1T H.262 reference-picture / reconstruction probe
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 7.6.4 and 7.6.8.
//   Prediction samples are read from the reference frame offset by the motion
//   vector. Motion vectors are in half-sample units. The integer-vector part and
//   half-sample flags are derived from the reconstructed vector itself:
//
//       int_vec[t]  = vector[t] DIV 2
//       half_flag[t]= (vector[t] - 2*int_vec[t]) != 0
//
//   For horizontal half-sample prediction with no vertical half-sample component:
//
//       pel_pred = (pel_ref[x] + pel_ref[x+1]) // 2
//
//   where // is integer division rounded to the nearest integer. For unsigned
//   reference samples this implementation is equivalently (a + b + 1) >> 1.
//
//   H.262 7.6.8 forms every decoded inter block sample by adding spatial-domain
//   residual f[y][x] to prediction p[y][x], then saturating to 0..255 for
//   x,y = 0..7.
//
// kate - Phase 1T-f through 1T-i retain the controlled explicit integer and
// half-pel reference-read diagnostics.
//
// kate - Phase 1T-l through 1T-n proved the first implicit-zero reconstructed P
// pel, first in a reserved DDR slot and then at the real luma (0,0) destination.
//
// kate - Phase 1T-o expands that proof to the complete first P Y0 8x8 block.
// The full 64-sample residual stream is captured from the already-proven P IDCT.
// Eight reference luma row words are read from the current reference frame,
// every byte is reconstructed under H.262 7.6.8, and the resulting 64 pels are
// emitted through the ordinary mpeg2_h262_ddram_store block writer. After that
// writer reports persistence, all eight destination row words are read back and
// compared bit-for-bit with the reconstructed rows. The old private prediction-
// channel write command is therefore no longer needed.
//
// P-picture publication and P reference promotion remain outside this phase.
//============================================================================

module mpeg2_h262_reference_read_probe
(
    input  wire        clk,
    input  wire        reset,

    input  wire        p_vector_proof_seen,
    input  wire        p_forward_vector_valid,
    input  wire signed [12:0] p_forward_vector_x,
    input  wire signed [12:0] p_forward_vector_y,
    input  wire [3:0]  forward_f_code_horizontal,
    input  wire [3:0]  forward_f_code_vertical,

    input  wire        p_implicit_reconstruct_request,
    input  wire        p_residual_sample_valid,
    input  wire [5:0]  p_residual_sample_index,
    input  wire signed [15:0] p_residual_sample_value,

    input  wire        reference_frame_valid,
    input  wire        reference_frame_bank,
    input  wire        destination_frame_bank,

    // Shared normal block writer completion pulse. It is consumed here only
    // while this probe is explicitly waiting for its emitted P block.
    input  wire        p_store_block_stored,

    input  wire        ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire        ddram_dout_ready,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,

    // First-P-block writer-side reconstruction stream. The top level muxes this
    // into the existing mpeg2_h262_ddram_store only while p_store_select is high.
    output wire        p_store_select,
    output wire [7:0]  p_store_pixel_value,
    output wire [11:0] p_store_pixel_x,
    output wire [11:0] p_store_pixel_y,
    output wire        p_store_pixel_valid,
    output wire        p_store_block_start,
    output wire        p_store_block_complete,

    output reg         read_seen,
    output reg  [7:0]  sample_value,
    output reg         sample_nonzero,
    output reg         half_sample_seen,
    output reg         reconstructed_seen,
    output reg  [7:0]  reconstructed_value,
    output reg         persisted_seen,
    output reg  [7:0]  persisted_value,
    output reg         probe_error
);

localparam [28:0] DDR_Y_BASE     = 29'h06000000;
localparam [28:0] DDR_BANK_WORDS = 29'h00010000;
localparam [7:0]  DIAG_EXPECTED_INTEGER_SAMPLE = 8'd162;

localparam [1:0]
    REQUEST_EXPLICIT        = 2'd0,
    REQUEST_BLOCK_REFERENCE = 2'd1,
    REQUEST_BLOCK_VERIFY    = 2'd2;

reg        trigger_seen;
reg        request_active;
reg        response_waiting;
reg [1:0]  request_kind;
reg [28:0] request_address;
reg [2:0]  request_lane;
reg        request_half_sample;
reg        request_implicit_reconstruct;
reg [2:0]  request_row;
reg [19:0] proof_timeout;

reg signed [15:0] residual_sample_mem [0:63];
reg [6:0] residual_sample_count;

reg [63:0] reference_rows [0:7];
reg [63:0] reconstructed_rows [0:7];
reg        persist_frame_bank_latched;

reg        reconstruct_active;
reg [5:0]  reconstruct_index;
reg        block_emit_active;
reg [5:0]  block_emit_index;
reg        waiting_for_store;

integer i;

function automatic [28:0] row_times_90;
    input [11:0] row;
    reg [28:0] r;
    begin
        r = {17'd0, row};
        row_times_90 = (r << 6) + (r << 4) + (r << 3) + (r << 1);
    end
endfunction

function automatic [7:0] clip_prediction_residual;
    input [7:0] prediction;
    input signed [15:0] residual;
    reg signed [16:0] prediction_ext;
    reg signed [16:0] residual_ext;
    reg signed [16:0] sum;
    begin
        prediction_ext = $signed({9'd0, prediction});
        residual_ext   = {residual[15], residual};
        sum = prediction_ext + residual_ext;

        if (sum < 17'sd0)
            clip_prediction_residual = 8'd0;
        else if (sum > 17'sd255)
            clip_prediction_residual = 8'd255;
        else
            clip_prediction_residual = sum[7:0];
    end
endfunction

wire controlled_integer_mode =
    p_forward_vector_valid &&
    (p_forward_vector_x == 13'sd4) &&
    (p_forward_vector_y == 13'sd0) &&
    (forward_f_code_horizontal == 4'd1) &&
    (forward_f_code_vertical   == 4'd1);

wire controlled_halfpel_mode =
    p_forward_vector_valid &&
    (p_forward_vector_x == 13'sd3) &&
    (p_forward_vector_y == 13'sd0) &&
    (forward_f_code_horizontal == 4'd2) &&
    (forward_f_code_vertical   == 4'd2);

wire controlled_explicit_mode =
    controlled_integer_mode || controlled_halfpel_mode;
wire controlled_implicit_mode = p_implicit_reconstruct_request;

wire signed [12:0] explicit_int_vec_x = p_forward_vector_x >>> 1;
wire signed [12:0] explicit_int_vec_y = p_forward_vector_y >>> 1;
wire signed [12:0] int_vec_x =
    controlled_implicit_mode ? 13'sd0 : explicit_int_vec_x;
wire signed [12:0] int_vec_y =
    controlled_implicit_mode ? 13'sd0 : explicit_int_vec_y;
wire signed [12:0] twice_int_vec_x = int_vec_x + int_vec_x;
wire signed [12:0] twice_int_vec_y = int_vec_y + int_vec_y;
wire half_flag_x = controlled_implicit_mode ? 1'b0 :
    ((p_forward_vector_x - twice_int_vec_x) != 13'sd0);
wire half_flag_y = controlled_implicit_mode ? 1'b0 :
    ((p_forward_vector_y - twice_int_vec_y) != 13'sd0);

wire [11:0] diag_destination_x =
    controlled_integer_mode ? 12'd7 : 12'd0;
wire [11:0] diag_destination_y = 12'd0;
wire signed [13:0] reference_x_signed =
    $signed({1'b0, diag_destination_x}) + int_vec_x;
wire signed [13:0] reference_y_signed =
    $signed({1'b0, diag_destination_y}) + int_vec_y;
wire [11:0] reference_x = reference_x_signed[11:0];
wire [11:0] reference_y = reference_y_signed[11:0];

wire vector_decomposition_ok =
    controlled_integer_mode ?
        ((int_vec_x == 13'sd2) && (int_vec_y == 13'sd0) &&
         !half_flag_x && !half_flag_y &&
         (reference_x_signed == 14'sd9) &&
         (reference_y_signed == 14'sd0)) :
    controlled_halfpel_mode ?
        ((int_vec_x == 13'sd1) && (int_vec_y == 13'sd0) &&
         half_flag_x && !half_flag_y &&
         (reference_x_signed == 14'sd1) &&
         (reference_y_signed == 14'sd0)) :
    controlled_implicit_mode ?
        ((int_vec_x == 13'sd0) && (int_vec_y == 13'sd0) &&
         !half_flag_x && !half_flag_y &&
         (reference_x_signed == 14'sd0) &&
         (reference_y_signed == 14'sd0)) :
        1'b0;

wire [28:0] reference_bank_offset =
    reference_frame_bank ? DDR_BANK_WORDS : 29'd0;
wire [28:0] calculated_address =
    DDR_Y_BASE + reference_bank_offset +
    row_times_90(reference_y) +
    {20'd0, reference_x[11:3]};

wire [28:0] persist_bank_offset =
    persist_frame_bank_latched ? DDR_BANK_WORDS : 29'd0;
wire [7:0] returned_sample =
    (request_lane == 3'd0) ? ddram_dout[7:0]   :
    (request_lane == 3'd1) ? ddram_dout[15:8]  :
    (request_lane == 3'd2) ? ddram_dout[23:16] :
    (request_lane == 3'd3) ? ddram_dout[31:24] :
    (request_lane == 3'd4) ? ddram_dout[39:32] :
    (request_lane == 3'd5) ? ddram_dout[47:40] :
    (request_lane == 3'd6) ? ddram_dout[55:48] :
                             ddram_dout[63:56];

wire [2:0] right_lane = request_lane + 3'd1;
wire [7:0] right_sample =
    (right_lane == 3'd0) ? ddram_dout[7:0]   :
    (right_lane == 3'd1) ? ddram_dout[15:8]  :
    (right_lane == 3'd2) ? ddram_dout[23:16] :
    (right_lane == 3'd3) ? ddram_dout[31:24] :
    (right_lane == 3'd4) ? ddram_dout[39:32] :
    (right_lane == 3'd5) ? ddram_dout[47:40] :
    (right_lane == 3'd6) ? ddram_dout[55:48] :
                           ddram_dout[63:56];

wire [8:0] halfpel_sum =
    {1'b0, returned_sample} + {1'b0, right_sample};
wire [8:0] halfpel_rounded_sum = halfpel_sum + 9'd1;
wire [7:0] halfpel_filtered_sample = halfpel_rounded_sum[8:1];
wire [8:0] halfpel_filtered_twice =
    {halfpel_filtered_sample, 1'b0};
wire halfpel_relation_ok =
    halfpel_sum[0] ?
        (halfpel_filtered_twice == (halfpel_sum + 9'd1)) :
        (halfpel_filtered_twice == halfpel_sum);
wire [7:0] halfpel_min =
    (returned_sample < right_sample) ? returned_sample : right_sample;
wire [7:0] halfpel_max =
    (returned_sample > right_sample) ? returned_sample : right_sample;
wire halfpel_nontrivial =
    (returned_sample != right_sample) &&
    (halfpel_filtered_sample > halfpel_min) &&
    (halfpel_filtered_sample < halfpel_max);

function automatic [7:0] select_row_byte;
    input [63:0] row_word;
    input [2:0] lane;
    begin
        case (lane)
            3'd0: select_row_byte = row_word[7:0];
            3'd1: select_row_byte = row_word[15:8];
            3'd2: select_row_byte = row_word[23:16];
            3'd3: select_row_byte = row_word[31:24];
            3'd4: select_row_byte = row_word[39:32];
            3'd5: select_row_byte = row_word[47:40];
            3'd6: select_row_byte = row_word[55:48];
            default: select_row_byte = row_word[63:56];
        endcase
    end
endfunction

wire [63:0] reconstruct_reference_row =
    reference_rows[reconstruct_index[5:3]];
wire [7:0] reconstruct_prediction_sample =
    select_row_byte(reconstruct_reference_row, reconstruct_index[2:0]);
wire signed [15:0] reconstruct_residual_sample =
    residual_sample_mem[reconstruct_index];
wire [7:0] reconstruct_pel =
    clip_prediction_residual(
        reconstruct_prediction_sample,
        reconstruct_residual_sample
    );

wire [63:0] emit_row_word = reconstructed_rows[block_emit_index[5:3]];
wire [5:0] reconstruct_byte_base = {reconstruct_index[2:0], 3'b000};

assign p_store_select         = block_emit_active;
assign p_store_pixel_value    =
    select_row_byte(emit_row_word, block_emit_index[2:0]);
assign p_store_pixel_x        = {9'd0, block_emit_index[2:0]};
assign p_store_pixel_y        = {9'd0, block_emit_index[5:3]};
assign p_store_pixel_valid    = block_emit_active;
assign p_store_block_start    = block_emit_active &&
                                (block_emit_index == 6'd0);
assign p_store_block_complete = block_emit_active &&
                                (block_emit_index == 6'd63);

assign ddram_burstcnt = request_active ? 8'd1 : 8'd0;
assign ddram_addr     = request_active ? request_address : 29'd0;
assign ddram_rd       = request_active;

wire proof_complete =
    request_implicit_reconstruct ? persisted_seen : read_seen;

always @(posedge clk) begin
    if (reset) begin
        trigger_seen                 <= 1'b0;
        request_active               <= 1'b0;
        response_waiting             <= 1'b0;
        request_kind                 <= REQUEST_EXPLICIT;
        request_address              <= 29'd0;
        request_lane                 <= 3'd0;
        request_half_sample          <= 1'b0;
        request_implicit_reconstruct <= 1'b0;
        request_row                  <= 3'd0;
        proof_timeout                <= 20'd0;
        residual_sample_count        <= 7'd0;
        persist_frame_bank_latched   <= 1'b0;
        reconstruct_active           <= 1'b0;
        reconstruct_index            <= 6'd0;
        block_emit_active            <= 1'b0;
        block_emit_index             <= 6'd0;
        waiting_for_store            <= 1'b0;
        read_seen                    <= 1'b0;
        sample_value                 <= 8'd0;
        sample_nonzero               <= 1'b0;
        half_sample_seen             <= 1'b0;
        reconstructed_seen           <= 1'b0;
        reconstructed_value          <= 8'd0;
        persisted_seen               <= 1'b0;
        persisted_value              <= 8'd0;
        probe_error                  <= 1'b0;

        for (i = 0; i < 64; i = i + 1)
            residual_sample_mem[i] <= 16'sd0;

        for (i = 0; i < 8; i = i + 1) begin
            reference_rows[i]     <= 64'd0;
            reconstructed_rows[i] <= 64'd0;
        end
    end
    else begin
        if (p_residual_sample_valid) begin
            if ((residual_sample_count >= 7'd64) ||
                (p_residual_sample_index != residual_sample_count[5:0])) begin
                probe_error <= 1'b1;
            end
            else begin
                residual_sample_mem[p_residual_sample_index] <=
                    p_residual_sample_value;
                residual_sample_count <= residual_sample_count + 7'd1;
            end
        end

        if ((((p_vector_proof_seen && controlled_explicit_mode) ||
              controlled_implicit_mode)) && !trigger_seen) begin
            trigger_seen  <= 1'b1;
            proof_timeout <= 20'hFFFFF;

            if (!reference_frame_valid || !vector_decomposition_ok ||
                (controlled_halfpel_mode && (reference_x[2:0] == 3'd7))) begin
                probe_error <= 1'b1;
            end
            else if (controlled_implicit_mode) begin
                request_implicit_reconstruct <= 1'b1;
                persist_frame_bank_latched   <= destination_frame_bank;

                if ((residual_sample_count != 7'd64) ||
                    (destination_frame_bank == reference_frame_bank)) begin
                    probe_error <= 1'b1;
                end
                else begin
                    request_kind    <= REQUEST_BLOCK_REFERENCE;
                    request_row     <= 3'd0;
                    request_address <= DDR_Y_BASE + reference_bank_offset;
                    request_lane    <= 3'd0;
                    request_active  <= 1'b1;
                end
            end
            else begin
                request_kind        <= REQUEST_EXPLICIT;
                request_address     <= calculated_address;
                request_lane        <= reference_x[2:0];
                request_half_sample <= controlled_halfpel_mode;
                request_active      <= 1'b1;
            end
        end

        if (trigger_seen && !proof_complete && (proof_timeout != 20'd0)) begin
            proof_timeout <= proof_timeout - 20'd1;
            if (proof_timeout == 20'd1)
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

                case (request_kind)
                    REQUEST_EXPLICIT: begin
                        read_seen <= 1'b1;

                        if (request_half_sample) begin
                            sample_value     <= halfpel_filtered_sample;
                            sample_nonzero   <= (halfpel_filtered_sample != 8'd0);
                            half_sample_seen <= 1'b1;

                            if (!halfpel_relation_ok ||
                                !halfpel_nontrivial ||
                                (halfpel_filtered_sample == 8'd0))
                                probe_error <= 1'b1;
                        end
                        else begin
                            sample_value   <= returned_sample;
                            sample_nonzero <= (returned_sample != 8'd0);

                            if (returned_sample != DIAG_EXPECTED_INTEGER_SAMPLE)
                                probe_error <= 1'b1;
                        end
                    end

                    REQUEST_BLOCK_REFERENCE: begin
                        reference_rows[request_row] <= ddram_dout;

                        if (request_row == 3'd0) begin
                            read_seen      <= 1'b1;
                            sample_value   <= ddram_dout[7:0];
                            sample_nonzero <= (ddram_dout[7:0] != 8'd0);
                        end

                        if (request_row == 3'd7) begin
                            reconstruct_index  <= 6'd0;
                            reconstruct_active <= 1'b1;
                        end
                        else begin
                            request_row     <= request_row + 3'd1;
                            request_address <= request_address + 29'd90;
                            request_active  <= 1'b1;
                        end
                    end

                    REQUEST_BLOCK_VERIFY: begin
                        if (ddram_dout != reconstructed_rows[request_row]) begin
                            probe_error <= 1'b1;
                        end
                        else if (request_row == 3'd0) begin
                            persisted_value <= ddram_dout[7:0];
                        end

                        if (request_row == 3'd7) begin
                            if (ddram_dout == reconstructed_rows[request_row]) begin
                                persisted_seen     <= 1'b1;
                                reconstructed_seen <= 1'b1;
                                proof_timeout      <= 20'd0;
                            end
                        end
                        else begin
                            request_row     <= request_row + 3'd1;
                            request_address <= request_address + 29'd90;
                            request_active  <= 1'b1;
                        end
                    end

                    default: begin
                        probe_error <= 1'b1;
                    end
                endcase
            end
        end

        if (reconstruct_active) begin
            reconstructed_rows[reconstruct_index[5:3]]
                [reconstruct_byte_base +: 8] <= reconstruct_pel;

            if (reconstruct_index == 6'd0)
                reconstructed_value <= reconstruct_pel;

            if (reconstruct_index == 6'd63) begin
                reconstruct_active <= 1'b0;
                block_emit_index   <= 6'd0;
                block_emit_active  <= 1'b1;
            end
            else begin
                reconstruct_index <= reconstruct_index + 6'd1;
            end
        end

        if (block_emit_active) begin
            if (block_emit_index == 6'd63) begin
                block_emit_active <= 1'b0;
                waiting_for_store <= 1'b1;
            end
            else begin
                block_emit_index <= block_emit_index + 6'd1;
            end
        end

        if (waiting_for_store && p_store_block_stored) begin
            waiting_for_store <= 1'b0;
            request_kind      <= REQUEST_BLOCK_VERIFY;
            request_row       <= 3'd0;
            request_address   <= DDR_Y_BASE + persist_bank_offset;
            request_lane      <= 3'd0;
            request_active    <= 1'b1;
        end
    end
end

endmodule
