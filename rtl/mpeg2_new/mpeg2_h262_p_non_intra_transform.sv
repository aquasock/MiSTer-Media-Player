//============================================================================
// MiSTer Media Player - serialized H.262 P transform engine
//
// Normative basis: ITU-T H.262 / ISO/IEC 13818-2:2000, 7.3, 7.4 and 7.5.
//
// kate - Phase 1T-p factors the already-proven default-matrix non-intra IQ and
// IDCT datapath out of the controlled residual probe. One engine is reused for
// Y0, Y1, Y2 and Y3. QFS is accepted in scan order; inverse quantisation reads
// it back in natural coefficient order using the selected H.262 scan. Mismatch
// control is applied per block before the existing IDCT is driven.
//
// kate - Phase 1U-p pipelines the scan-address lookup at the QFS/IQ boundary.
// The block controls are latched when QFS capture closes, and the 64-way scan
// mapping now terminates at iq_qfs_index_reg instead of feeding the QFS mux,
// inverse-quant arithmetic and diagnostic checks in the same 54 MHz cycle.
//
// Entry 234 streams each completed inverse-quantised coefficient directly
// into the IDCT capture port.  The IDCT already stores one coefficient per
// cycle, so retaining a second 64-entry array and replaying it after inverse
// quantisation only serialized two storage phases without changing data.
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
    input  wire        intra_block,
    input  wire [1:0]  intra_dc_precision,

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

// H.262 6.3.11 normative default intra quantisation matrix.  The generalized
// P path uses this lookup in the same serialized engine as non-intra blocks so
// only one IDCT and one coefficient store are present in the FPGA image.
function automatic [7:0] default_intra_weight;
    input [5:0] linear;
    begin
        case (linear)
             0: default_intra_weight =  8;  1: default_intra_weight = 16;
             2: default_intra_weight = 19;  3: default_intra_weight = 22;
             4: default_intra_weight = 26;  5: default_intra_weight = 27;
             6: default_intra_weight = 29;  7: default_intra_weight = 34;
             8: default_intra_weight = 16;  9: default_intra_weight = 16;
            10: default_intra_weight = 22; 11: default_intra_weight = 24;
            12: default_intra_weight = 27; 13: default_intra_weight = 29;
            14: default_intra_weight = 34; 15: default_intra_weight = 37;
            16: default_intra_weight = 19; 17: default_intra_weight = 22;
            18: default_intra_weight = 26; 19: default_intra_weight = 27;
            20: default_intra_weight = 29; 21: default_intra_weight = 34;
            22: default_intra_weight = 34; 23: default_intra_weight = 38;
            24: default_intra_weight = 22; 25: default_intra_weight = 22;
            26: default_intra_weight = 26; 27: default_intra_weight = 27;
            28: default_intra_weight = 29; 29: default_intra_weight = 34;
            30: default_intra_weight = 37; 31: default_intra_weight = 40;
            32: default_intra_weight = 22; 33: default_intra_weight = 26;
            34: default_intra_weight = 27; 35: default_intra_weight = 29;
            36: default_intra_weight = 32; 37: default_intra_weight = 35;
            38: default_intra_weight = 40; 39: default_intra_weight = 48;
            40: default_intra_weight = 26; 41: default_intra_weight = 27;
            42: default_intra_weight = 29; 43: default_intra_weight = 32;
            44: default_intra_weight = 35; 45: default_intra_weight = 40;
            46: default_intra_weight = 48; 47: default_intra_weight = 58;
            48: default_intra_weight = 26; 49: default_intra_weight = 27;
            50: default_intra_weight = 29; 51: default_intra_weight = 34;
            52: default_intra_weight = 38; 53: default_intra_weight = 46;
            54: default_intra_weight = 56; 55: default_intra_weight = 69;
            56: default_intra_weight = 27; 57: default_intra_weight = 29;
            58: default_intra_weight = 35; 59: default_intra_weight = 38;
            60: default_intra_weight = 46; 61: default_intra_weight = 56;
            62: default_intra_weight = 69; 63: default_intra_weight = 83;
            default: default_intra_weight = 8'd16;
        endcase
    end
endfunction

reg        iq_active;
reg [5:0]  iq_index;
reg [5:0]  iq_qfs_index_reg;
reg        iq_parity;
reg        y0_f00_proven;
reg [4:0]  iq_quantiser_scale_code;
reg        iq_q_scale_type;
reg        iq_alternate_scan;
reg        iq_intra_block;
reg [1:0]  iq_intra_dc_precision;

wire signed [12:0] iq_qf = qfs[iq_qfs_index_reg];
wire signed [14:0] iq_qf_extended = {{2{iq_qf[12]}}, iq_qf};
wire [7:0] iq_qscale =
    quantiser_scale_value(iq_q_scale_type, iq_quantiser_scale_code);
wire [7:0] iq_intra_weight = default_intra_weight(iq_index);
wire [3:0] iq_dc_multiplier =
    (iq_intra_dc_precision==2'd0) ? 4'd8 :
    (iq_intra_dc_precision==2'd1) ? 4'd4 :
    (iq_intra_dc_precision==2'd2) ? 4'd2 : 4'd1;

reg signed [14:0] iq_precondition;
reg signed [23:0] iq_multiplier_a;
reg signed [8:0]  iq_multiplier_b;
wire signed [32:0] iq_multiplier_result =
    iq_multiplier_a * iq_multiplier_b;
reg               iq_stage_pending;
reg signed [31:0] iq_stage_product;
reg signed [31:0] iq_unclipped;
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

    iq_multiplier_a = 24'sd0;
    iq_multiplier_b = 9'sd0;
    iq_unclipped = 32'sd0;
    if (iq_stage_pending && iq_intra_block && (iq_index != 6'd0)) begin
        iq_multiplier_a = iq_stage_product[23:0];
        iq_multiplier_b = $signed({1'b0, iq_qscale});
        // H.262 7.4.2.3: (QF * W * quantiser_scale * 2) / 32.
        iq_unclipped = $signed(iq_multiplier_result) / 32'sd16;
    end
    else if (iq_intra_block && (iq_index == 6'd0)) begin
        iq_multiplier_a = {{11{iq_qf[12]}},iq_qf};
        iq_multiplier_b = $signed({5'd0, iq_dc_multiplier});
        // H.262 7.4.1: intra DC is independent of matrix and qscale.
        if (iq_stage_pending)
            iq_unclipped = iq_stage_product;
    end
    else if (iq_intra_block) begin
        iq_multiplier_a = {{11{iq_qf[12]}},iq_qf};
        iq_multiplier_b = $signed({1'b0, iq_intra_weight});
    end
    else begin
        iq_multiplier_a = {{9{iq_precondition[14]}},iq_precondition};
        iq_multiplier_b = $signed({1'b0, iq_qscale});
        if (iq_stage_pending)
            iq_unclipped = iq_stage_product / 32'sd2;
    end

    if (iq_unclipped > 32'sd2047)
        iq_saturated = 12'sd2047;
    else if (iq_unclipped < -32'sd2048)
        iq_saturated = 12'sh800;
    else
        iq_saturated = iq_unclipped[11:0];

    iq_parity_with_current = iq_parity ^ iq_saturated[0];
    if ((iq_index == 6'd63) && !iq_parity_with_current)
        iq_final_value = {iq_saturated[11:1], ~iq_saturated[0]};
    else
        iq_final_value = iq_saturated;
end

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
wire transform_busy = iq_active;
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
        iq_qfs_index_reg       <= 6'd0;
        iq_parity              <= 1'b0;
        y0_f00_proven          <= 1'b0;
        iq_quantiser_scale_code<= 5'd0;
        iq_q_scale_type        <= 1'b0;
        iq_alternate_scan      <= 1'b0;
        iq_intra_block         <= 1'b0;
        iq_intra_dc_precision  <= 2'd0;
        iq_stage_pending       <= 1'b0;
        iq_stage_product       <= 32'sd0;
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

        for (i = 0; i < 64; i = i + 1)
            qfs[i] <= 13'sd0;
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
                capture_active          <= 1'b0;
                iq_active               <= 1'b1;
                iq_index                <= 6'd0;
                iq_qfs_index_reg        <= scan_index(alternate_scan, 6'd0);
                iq_parity               <= 1'b0;
                iq_quantiser_scale_code <= quantiser_scale_code;
                iq_q_scale_type         <= q_scale_type;
                iq_alternate_scan       <= alternate_scan;
                iq_intra_block          <= intra_block;
                iq_intra_dc_precision   <= intra_dc_precision;
                iq_stage_pending        <= 1'b0;
            end
        end

        if (iq_active) begin
            if (!iq_stage_pending) begin
                iq_stage_product <= iq_multiplier_result[31:0];
                iq_stage_pending <= 1'b1;
            end
            else begin
                iq_stage_pending <= 1'b0;
                iq_parity <= iq_parity_with_current;
                idct_coeff_block_start <= (iq_index == 6'd0);
                idct_coeff_valid <= 1'b1;
                idct_coeff_index <= iq_index;
                idct_coeff_value <= iq_final_value;
                idct_coeff_block_end <= (iq_index == 6'd63);
                if (iq_index == 6'd0)
                    idct_sample_count <= 7'd0;

                if (!iq_intra_block &&
                    (active_block_index == 2'd0) && (iq_index == 6'd0)) begin
                    if ((iq_quantiser_scale_code == 5'd2) &&
                        !iq_q_scale_type &&
                        (iq_qf == 13'sd7) &&
                        (iq_final_value == 12'sd30))
                        y0_f00_proven <= 1'b1;
                    else
                        probe_error <= 1'b1;
                end

                if (iq_index == 6'd63) begin
                    iq_active <= 1'b0;
                end
                else begin
                    iq_index         <= iq_index + 6'd1;
                    iq_qfs_index_reg <= scan_index(iq_alternate_scan,
                                                   iq_index + 6'd1);
                end
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
