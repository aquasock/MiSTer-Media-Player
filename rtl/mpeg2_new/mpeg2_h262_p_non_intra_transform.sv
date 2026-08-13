//============================================================================
// MiSTer Media Player - serialized H.262 P non-intra transform engine
//
// Normative basis: ITU-T H.262 / ISO/IEC 13818-2:2000, 7.3, 7.4 and 7.5.
//
// kate - Phase 1T-p factors the already-proven default-matrix non-intra IQ and
// IDCT datapath out of the controlled residual probe. One engine is reused for
// Y0, Y1, Y2 and Y3. QFS is accepted in scan order; inverse quantisation reads
// it back in natural coefficient order using the selected H.262 scan. Mismatch
// control is applied per block before the existing IDCT is driven.
//============================================================================

module mpeg2_h262_p_non_intra_transform
(
    input  wire        clk,
    input  wire        reset,

    input  wire [1:0]  qfs_block_index,
    input  wire        qfs_block_start,
    input  wire        qfs_write_en,
    input  wire [5:0]  qfs_write_index,
    input  wire signed [12:0] qfs_write_value,
    input  wire        qfs_block_end,

    input  wire [4:0]  quantiser_scale_code,
    input  wire        q_scale_type,
    input  wire        alternate_scan,

    output reg         block_done,
    output reg         first_sample_valid,
    output reg signed [15:0] first_sample_value,
    output wire        residual_sample_valid,
    output wire [1:0]  residual_sample_block_index,
    output wire [5:0]  residual_sample_index,
    output wire signed [15:0] residual_sample_value,
    output reg         probe_error
);

reg signed [12:0] qfs [0:63];
reg signed [11:0] iq_coeff [0:63];
integer i;

reg        capture_active;
reg [1:0]  active_block_index;

function automatic [5:0] scan_index;
    input       alternate;
    input [5:0] linear;
    begin
        if (!alternate) begin
            case (linear)
                 0: scan_index =  0;  1: scan_index =  1;
                 2: scan_index =  5;  3: scan_index =  6;
                 4: scan_index = 14;  5: scan_index = 15;
                 6: scan_index = 27;  7: scan_index = 28;
                 8: scan_index =  2;  9: scan_index =  4;
                10: scan_index =  7; 11: scan_index = 13;
                12: scan_index = 16; 13: scan_index = 26;
                14: scan_index = 29; 15: scan_index = 42;
                16: scan_index =  3; 17: scan_index =  8;
                18: scan_index = 12; 19: scan_index = 17;
                20: scan_index = 25; 21: scan_index = 30;
                22: scan_index = 41; 23: scan_index = 43;
                24: scan_index =  9; 25: scan_index = 11;
                26: scan_index = 18; 27: scan_index = 24;
                28: scan_index = 31; 29: scan_index = 40;
                30: scan_index = 44; 31: scan_index = 53;
                32: scan_index = 10; 33: scan_index = 19;
                34: scan_index = 23; 35: scan_index = 32;
                36: scan_index = 39; 37: scan_index = 45;
                38: scan_index = 52; 39: scan_index = 54;
                40: scan_index = 20; 41: scan_index = 22;
                42: scan_index = 33; 43: scan_index = 38;
                44: scan_index = 46; 45: scan_index = 51;
                46: scan_index = 55; 47: scan_index = 60;
                48: scan_index = 21; 49: scan_index = 34;
                50: scan_index = 37; 51: scan_index = 47;
                52: scan_index = 50; 53: scan_index = 56;
                54: scan_index = 59; 55: scan_index = 61;
                56: scan_index = 35; 57: scan_index = 36;
                58: scan_index = 48; 59: scan_index = 49;
                60: scan_index = 57; 61: scan_index = 58;
                62: scan_index = 62; 63: scan_index = 63;
                default: scan_index = 6'd0;
            endcase
        end
        else begin
            case (linear)
                 0: scan_index =  0;  1: scan_index =  4;
                 2: scan_index =  6;  3: scan_index = 20;
                 4: scan_index = 22;  5: scan_index = 36;
                 6: scan_index = 38;  7: scan_index = 52;
                 8: scan_index =  1;  9: scan_index =  5;
                10: scan_index =  7; 11: scan_index = 21;
                12: scan_index = 23; 13: scan_index = 37;
                14: scan_index = 39; 15: scan_index = 53;
                16: scan_index =  2; 17: scan_index =  8;
                18: scan_index = 19; 19: scan_index = 24;
                20: scan_index = 34; 21: scan_index = 40;
                22: scan_index = 50; 23: scan_index = 54;
                24: scan_index =  3; 25: scan_index =  9;
                26: scan_index = 18; 27: scan_index = 25;
                28: scan_index = 35; 29: scan_index = 41;
                30: scan_index = 51; 31: scan_index = 55;
                32: scan_index = 10; 33: scan_index = 17;
                34: scan_index = 26; 35: scan_index = 30;
                36: scan_index = 42; 37: scan_index = 46;
                38: scan_index = 56; 39: scan_index = 60;
                40: scan_index = 11; 41: scan_index = 16;
                42: scan_index = 27; 43: scan_index = 31;
                44: scan_index = 43; 45: scan_index = 47;
                46: scan_index = 57; 47: scan_index = 61;
                48: scan_index = 12; 49: scan_index = 15;
                50: scan_index = 28; 51: scan_index = 32;
                52: scan_index = 44; 53: scan_index = 48;
                54: scan_index = 58; 55: scan_index = 62;
                56: scan_index = 13; 57: scan_index = 14;
                58: scan_index = 29; 59: scan_index = 33;
                60: scan_index = 45; 61: scan_index = 49;
                62: scan_index = 59; 63: scan_index = 63;
                default: scan_index = 6'd0;
            endcase
        end
    end
endfunction

function automatic [7:0] quantiser_scale_value;
    input       nonlinear;
    input [4:0] code;
    begin
        if (!nonlinear) begin
            quantiser_scale_value = {code, 1'b0};
        end
        else begin
            case (code)
                 1: quantiser_scale_value =   1;
                 2: quantiser_scale_value =   2;
                 3: quantiser_scale_value =   3;
                 4: quantiser_scale_value =   4;
                 5: quantiser_scale_value =   5;
                 6: quantiser_scale_value =   6;
                 7: quantiser_scale_value =   7;
                 8: quantiser_scale_value =   8;
                 9: quantiser_scale_value =  10;
                10: quantiser_scale_value =  12;
                11: quantiser_scale_value =  14;
                12: quantiser_scale_value =  16;
                13: quantiser_scale_value =  18;
                14: quantiser_scale_value =  20;
                15: quantiser_scale_value =  22;
                16: quantiser_scale_value =  24;
                17: quantiser_scale_value =  28;
                18: quantiser_scale_value =  32;
                19: quantiser_scale_value =  36;
                20: quantiser_scale_value =  40;
                21: quantiser_scale_value =  44;
                22: quantiser_scale_value =  48;
                23: quantiser_scale_value =  52;
                24: quantiser_scale_value =  56;
                25: quantiser_scale_value =  64;
                26: quantiser_scale_value =  72;
                27: quantiser_scale_value =  80;
                28: quantiser_scale_value =  88;
                29: quantiser_scale_value =  96;
                30: quantiser_scale_value = 104;
                31: quantiser_scale_value = 112;
                default: quantiser_scale_value = 8'd0;
            endcase
        end
    end
endfunction

reg        iq_active;
reg [5:0]  iq_index;
reg        iq_parity;
reg        y0_f00_proven;
wire [5:0] iq_qfs_index = scan_index(alternate_scan, iq_index);
wire signed [12:0] iq_qf = qfs[iq_qfs_index];
wire signed [14:0] iq_qf_extended = {{2{iq_qf[12]}}, iq_qf};
wire [7:0] iq_qscale =
    quantiser_scale_value(q_scale_type, quantiser_scale_code);

reg signed [14:0] iq_precondition;
reg signed [23:0] iq_product;
reg signed [23:0] iq_unclipped;
reg signed [11:0] iq_saturated;
reg signed [11:0] iq_final_value;
reg               iq_parity_with_current;

always @* begin
    if (iq_qf > 13'sd0)
        iq_precondition = (iq_qf_extended <<< 1) + 15'sd1;
    else if (iq_qf < 13'sd0)
        iq_precondition = (iq_qf_extended <<< 1) - 15'sd1;
    else
        iq_precondition = 15'sd0;

    iq_product   = iq_precondition * $signed({1'b0, iq_qscale});
    iq_unclipped = iq_product / 24'sd2;

    if (iq_unclipped > 24'sd2047)
        iq_saturated = 12'sd2047;
    else if (iq_unclipped < -24'sd2048)
        iq_saturated = 12'sh800;
    else
        iq_saturated = iq_unclipped[11:0];

    iq_parity_with_current = iq_parity ^ iq_saturated[0];
    if ((iq_index == 6'd63) && !iq_parity_with_current)
        iq_final_value = {iq_saturated[11:1], ~iq_saturated[0]};
    else
        iq_final_value = iq_saturated;
end

reg        emit_pending;
reg        emit_active;
reg [5:0]  emit_index;
reg        idct_coeff_block_start;
reg        idct_coeff_valid;
reg [5:0]  idct_coeff_index;
reg signed [11:0] idct_coeff_value;
reg        idct_coeff_block_end;

wire       idct_block_complete;
wire       idct_error;
wire       idct_sample_valid;
wire [5:0] idct_sample_index;
wire signed [15:0] idct_sample_value;
wire signed [15:0] idct_first_sample00;
wire signed [15:0] idct_first_sample77;

mpeg2_h262_idct p_residual_idct
(
    .clk                 (clk),
    .reset               (reset),
    .coeff_block_start   (idct_coeff_block_start),
    .coeff_valid         (idct_coeff_valid),
    .coeff_index         (idct_coeff_index),
    .coeff_value         (idct_coeff_value),
    .coeff_block_end     (idct_coeff_block_end),
    .block_complete      (idct_block_complete),
    .idct_error          (idct_error),
    .sample_valid        (idct_sample_valid),
    .sample_index        (idct_sample_index),
    .sample_value        (idct_sample_value),
    .first_luma_sample00 (idct_first_sample00),
    .first_luma_sample77 (idct_first_sample77)
);

reg [6:0] idct_sample_count;
wire transform_busy = iq_active || emit_pending || emit_active;
wire unused_idct_values =
    &{1'b0, idct_first_sample00[0], idct_first_sample77[0]};

assign residual_sample_valid       = idct_sample_valid;
assign residual_sample_block_index = active_block_index;
assign residual_sample_index       = idct_sample_index;
assign residual_sample_value       = idct_sample_value;

always @(posedge clk) begin
    if (reset) begin
        capture_active         <= 1'b0;
        active_block_index     <= 2'd0;
        iq_active              <= 1'b0;
        iq_index               <= 6'd0;
        iq_parity              <= 1'b0;
        y0_f00_proven          <= 1'b0;
        emit_pending           <= 1'b0;
        emit_active            <= 1'b0;
        emit_index             <= 6'd0;
        idct_coeff_block_start <= 1'b0;
        idct_coeff_valid       <= 1'b0;
        idct_coeff_index       <= 6'd0;
        idct_coeff_value       <= 12'sd0;
        idct_coeff_block_end   <= 1'b0;
        idct_sample_count      <= 7'd0;
        block_done             <= 1'b0;
        first_sample_valid     <= 1'b0;
        first_sample_value     <= 16'sd0;
        probe_error            <= 1'b0;

        for (i = 0; i < 64; i = i + 1) begin
            qfs[i]      <= 13'sd0;
            iq_coeff[i] <= 12'sd0;
        end
    end
    else begin
        idct_coeff_block_start <= 1'b0;
        idct_coeff_valid       <= 1'b0;
        idct_coeff_block_end   <= 1'b0;
        block_done             <= 1'b0;

        if (idct_error)
            probe_error <= 1'b1;

        if (qfs_block_start) begin
            if (capture_active || transform_busy)
                probe_error <= 1'b1;

            capture_active     <= 1'b1;
            active_block_index <= qfs_block_index;
            if (qfs_block_index == 2'd0)
                y0_f00_proven <= 1'b0;

            for (i = 0; i < 64; i = i + 1)
                qfs[i] <= 13'sd0;
        end

        if (qfs_write_en) begin
            if (!capture_active)
                probe_error <= 1'b1;
            else
                qfs[qfs_write_index] <= qfs_write_value;
        end

        if (qfs_block_end) begin
            if (!capture_active || transform_busy) begin
                probe_error <= 1'b1;
            end
            else begin
                capture_active <= 1'b0;
                iq_active      <= 1'b1;
                iq_index       <= 6'd0;
                iq_parity      <= 1'b0;
            end
        end

        if (iq_active) begin
            iq_coeff[iq_index] <= iq_final_value;
            iq_parity <= iq_parity_with_current;

            if ((active_block_index == 2'd0) && (iq_index == 6'd0)) begin
                if ((quantiser_scale_code == 5'd2) &&
                    !q_scale_type &&
                    (iq_qf == 13'sd7) &&
                    (iq_final_value == 12'sd30))
                    y0_f00_proven <= 1'b1;
                else
                    probe_error <= 1'b1;
            end

            if (iq_index == 6'd63) begin
                iq_active    <= 1'b0;
                emit_pending <= 1'b1;
                emit_index   <= 6'd0;
            end
            else begin
                iq_index <= iq_index + 6'd1;
            end
        end

        if (emit_pending) begin
            emit_pending           <= 1'b0;
            emit_active            <= 1'b1;
            emit_index             <= 6'd1;
            idct_coeff_block_start <= 1'b1;
            idct_coeff_valid       <= 1'b1;
            idct_coeff_index       <= 6'd0;
            idct_coeff_value       <= iq_coeff[0];
            idct_sample_count      <= 7'd0;
        end
        else if (emit_active) begin
            idct_coeff_valid <= 1'b1;
            idct_coeff_index <= emit_index;
            idct_coeff_value <= iq_coeff[emit_index];

            if (emit_index == 6'd63) begin
                idct_coeff_block_end <= 1'b1;
                emit_active          <= 1'b0;
            end
            else begin
                emit_index <= emit_index + 6'd1;
            end
        end

        if (idct_sample_valid) begin
            if (idct_sample_index != idct_sample_count[5:0]) begin
                probe_error <= 1'b1;
            end
            else begin
                if ((active_block_index == 2'd0) &&
                    (idct_sample_index == 6'd0)) begin
                    first_sample_valid <= 1'b1;
                    first_sample_value <= idct_sample_value;
                end

                if (idct_sample_index == 6'd63) begin
                    if ((idct_sample_count != 7'd63) ||
                        !idct_block_complete || idct_error ||
                        ((active_block_index == 2'd0) && !y0_f00_proven))
                        probe_error <= 1'b1;
                    else
                        block_done <= 1'b1;
                end
            end

            if (idct_sample_count < 7'd64)
                idct_sample_count <= idct_sample_count + 7'd1;
        end
    end
end

endmodule
