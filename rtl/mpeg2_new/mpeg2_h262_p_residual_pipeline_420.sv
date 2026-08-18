//============================================================================
// MiSTer Media Player - shared H.262 P residual pipeline
//
// Commit 202 replaces the wide path's flattened picture plan with synchronous
// read ports into parser-owned M10K memories. One sparse block at a time is
// loaded into the existing serialized inverse-quantisation/IDCT engine, then
// replayed immediately to the generalized raster engine. No transform is
// duplicated and only one 64-sample spatial buffer is retained here.
// Entry 204 starts this transaction at every completed parser row; A2FE retires
// an intermediate row and A2FF retains its established final-picture meaning.
//============================================================================
module mpeg2_h262_p_residual_probe
(
    input wire clk,
    input wire reset,
    input wire [7:0] stream_data,
    input wire stream_valid,
    input wire p_picture_expected,

    input wire general_mode,
    input wire general_picture_complete,
    input wire [383:0] general_motion_x_plan,
    input wire [383:0] general_motion_y_plan,
    input wire [287:0] general_residual_block_plan,
    input wire [4:0] general_residual_block_count,
    input wire [383:0] general_coeff_index_plan,
    input wire [831:0] general_coeff_value_plan,
    input wire [63:0] general_coeff_last_plan,
    input wire [6:0] general_coeff_count,
    input wire [79:0] general_qscale_plan,
    input wire general_q_scale_type,
    input wire general_alternate_scan,

    input wire wide_mode,
    input wire wide_row_complete,
    input wire wide_row_final,
    output reg [10:0] wide_block_read_address,
    input wire [10:0] wide_block_read_mb,
    input wire [2:0] wide_block_read_index,
    input wire wide_block_read_intra,
    input wire [4:0] wide_block_read_qscale,
    input wire [11:0] wide_residual_block_count,
    output reg [14:0] wide_coeff_read_address,
    input wire [5:0] wide_coeff_read_index,
    input wire signed [12:0] wide_coeff_read_value,
    input wire wide_coeff_read_last,
    input wire [15:0] wide_coeff_count,
    input wire wide_q_scale_type,
    input wire wide_alternate_scan,
    input wire [1:0] wide_intra_dc_precision,

    output wire decision_complete,
    output wire residual_required,
    output wire residual_success,
    output wire mixed_replay_active,
    output wire first_sample_valid,
    output wire signed [15:0] first_sample_value,
    output wire residual_sample_valid,
    output wire [5:0] residual_sample_index,
    output wire signed [15:0] residual_sample_value,
    output wire probe_error
);

localparam [3:0]
    G_IDLE          = 4'd0,
    G_BLOCK_WAIT    = 4'd1,
    G_BLOCK_CAPTURE = 4'd2,
    G_START         = 4'd3,
    G_COEFF_WRITE   = 4'd4,
    G_COEFF_WAIT    = 4'd5,
    G_END           = 4'd6,
    G_WAIT          = 4'd7,
    G_DESC          = 4'd8,
    G_DESC2         = 4'd9,
    G_SAMPLES       = 4'd10,
    G_FINISH        = 4'd11;

reg [3:0] gstate;
reg g_decision, g_required, g_success, g_error;
reg [11:0] expected_blocks, block_slot;
reg [15:0] expected_coeffs, coeff_consumed;
reg [10:0] current_mb;
reg [2:0] current_block;
reg current_intra;
reg [4:0] current_qscale;
reg g_qtype, g_alt;
reg [1:0] g_intra_dc_precision;
reg g_row_final;

reg gstart, gwe, gend;
reg [5:0] gwidx;
reg signed [12:0] gwval;
wire transform_done, tfvalid, tvalid, terr;
wire signed [15:0] tfvalue, tvalue;
wire [1:0] unused_block;
wire [5:0] tidx;

reg signed [15:0] block_sample_mem [0:63];
reg [6:0] sample_cap_count;
reg [5:0] replay_sample;
reg replay_valid, first_valid_reg;
reg [5:0] replay_index;
reg signed [15:0] replay_value, first_value_reg;

mpeg2_h262_p_non_intra_transform transform
(
    .clk(clk),
    .reset(reset),
    .qfs_block_index(2'd1),
    .qfs_block_start(gstart),
    .qfs_write_en(gwe),
    .qfs_write_index(gwidx),
    .qfs_write_value(gwval),
    .qfs_block_end(gend),
    .quantiser_scale_code(current_qscale),
    .q_scale_type(g_qtype),
    .alternate_scan(g_alt),
    .intra_block(current_intra),
    .intra_dc_precision(g_intra_dc_precision),
    .block_done(transform_done),
    .first_sample_valid(tfvalid),
    .first_sample_value(tfvalue),
    .residual_sample_valid(tvalid),
    .residual_sample_block_index(unused_block),
    .residual_sample_index(tidx),
    .residual_sample_value(tvalue),
    .probe_error(terr)
);

wire unused_legacy=&{
    1'b0,stream_data[0],stream_valid,p_picture_expected,general_mode,
    general_picture_complete,general_motion_x_plan[0],
    general_motion_y_plan[0],general_residual_block_plan[0],
    general_residual_block_count[0],general_coeff_index_plan[0],
    general_coeff_value_plan[0],general_coeff_last_plan[0],
    general_coeff_count[0],general_qscale_plan[0],general_q_scale_type,
    general_alternate_scan,tfvalid,tfvalue[0],unused_block[0]
};

always @(posedge clk) begin
    if(reset) begin
        gstate<=G_IDLE;
        g_decision<=0;
        g_required<=0;
        g_success<=0;
        g_error<=0;
        expected_blocks<=0;
        block_slot<=0;
        expected_coeffs<=0;
        coeff_consumed<=0;
        wide_block_read_address<=0;
        wide_coeff_read_address<=0;
        current_mb<=0;
        current_block<=0;
        current_intra<=0;
        current_qscale<=0;
        g_qtype<=0;
        g_alt<=0;
        g_intra_dc_precision<=0;
        g_row_final<=0;
        gstart<=0;
        gwe<=0;
        gend<=0;
        gwidx<=0;
        gwval<=0;
        sample_cap_count<=0;
        replay_sample<=0;
        replay_valid<=0;
        first_valid_reg<=0;

        if(!wide_mode&&(gstate==G_IDLE)) begin
            g_decision<=0;
            g_required<=0;
            g_success<=0;
        end
        replay_index<=0;
        replay_value<=0;
        first_value_reg<=0;
    end else begin
        gstart<=0;
        gwe<=0;
        gend<=0;
        replay_valid<=0;
        first_valid_reg<=0;

        if(tvalid) begin
            if((tidx!=sample_cap_count[5:0]) ||
               (sample_cap_count>=7'd64)) begin
                g_error<=1;
            end else begin
                block_sample_mem[tidx]<=tvalue;
                sample_cap_count<=sample_cap_count+1'b1;
            end
        end

        if(wide_row_complete) begin
            g_decision<=1;
            g_required<=g_required||(wide_residual_block_count!=0);
            g_success<=0;
            g_row_final<=wide_row_final;
            expected_blocks<=wide_residual_block_count;
            expected_coeffs<=wide_coeff_count;
            block_slot<=0;
            coeff_consumed<=0;
            wide_block_read_address<=0;
            wide_coeff_read_address<=0;
            sample_cap_count<=0;
            replay_sample<=0;
            g_qtype<=wide_q_scale_type;
            g_alt<=wide_alternate_scan;
            g_intra_dc_precision<=wide_intra_dc_precision;
            if(wide_residual_block_count!=0) begin
                gstate<=G_BLOCK_WAIT;
            end else begin
                if(wide_coeff_count!=0) g_error<=1;
                g_success<=(wide_coeff_count==0);
                gstate<=G_FINISH;
            end
        end else begin
            case(gstate)
            G_BLOCK_WAIT: begin
                // Parser memories are synchronous; the following state sees
                // the word selected by wide_block_read_address.
                gstate<=G_BLOCK_CAPTURE;
            end

            G_BLOCK_CAPTURE: begin
                if((block_slot>=expected_blocks) ||
                   (wide_block_read_mb>=11'd1350) ||
                   (wide_block_read_index>=3'd6)) begin
                    g_error<=1;
                    gstate<=G_IDLE;
                end else begin
                    current_mb<=wide_block_read_mb;
                    current_block<=wide_block_read_index;
                    current_intra<=wide_block_read_intra;
                    current_qscale<=wide_block_read_qscale;
                    sample_cap_count<=0;
                    gstate<=G_START;
                end
            end

            G_START: begin
                gstart<=1;
                gstate<=G_COEFF_WRITE;
            end

            G_COEFF_WRITE: begin
                if(coeff_consumed>=expected_coeffs) begin
                    g_error<=1;
                    gstate<=G_IDLE;
                end else begin
                    gwe<=1;
                    gwidx<=wide_coeff_read_index;
                    gwval<=wide_coeff_read_value;
                    coeff_consumed<=coeff_consumed+1'b1;
                    wide_coeff_read_address<=wide_coeff_read_address+1'b1;
                    if(wide_coeff_read_last)
                        gstate<=G_END;
                    else
                        gstate<=G_COEFF_WAIT;
                end
            end

            G_COEFF_WAIT: begin
                // One-cycle synchronous coefficient-memory read latency.
                gstate<=G_COEFF_WRITE;
            end

            G_END: begin
                gend<=1;
                gstate<=G_WAIT;
            end

            G_WAIT: if(transform_done) begin
                if((sample_cap_count+(tvalid?7'd1:7'd0))!=7'd64) begin
                    g_error<=1;
                    gstate<=G_IDLE;
                end else begin
                    replay_sample<=0;
                    gstate<=G_DESC;
                end
            end

            G_DESC: begin
                replay_valid<=1;
                replay_index<=6'h3c;
                replay_value<=$signed({5'd0,current_mb});
                gstate<=G_DESC2;
            end

            G_DESC2: begin
                replay_valid<=1;
                replay_index<=6'h3d;
                replay_value<=$signed({12'd0,current_intra,current_block});
                replay_sample<=0;
                gstate<=G_SAMPLES;
            end

            G_SAMPLES: begin
                replay_valid<=1;
                replay_index<=replay_sample;
                replay_value<=block_sample_mem[replay_sample];
                if((block_slot==0)&&(replay_sample==0)) begin
                    first_valid_reg<=1;
                    first_value_reg<=block_sample_mem[0];
                end
                if(replay_sample==6'd63) begin
                    if(block_slot+1'b1>=expected_blocks) begin
                        if(coeff_consumed!=expected_coeffs)
                            g_error<=1;
                        else
                            g_success<=1;
                        gstate<=G_FINISH;
                    end else begin
                        block_slot<=block_slot+1'b1;
                        wide_block_read_address<=wide_block_read_address+1'b1;
                        sample_cap_count<=0;
                        gstate<=G_BLOCK_WAIT;
                    end
                end else begin
                    replay_sample<=replay_sample+1'b1;
                end
            end

            G_FINISH: begin
                replay_valid<=1;
                replay_index<=6'h3f;
                replay_value<=g_row_final?16'shA2FF:16'shA2FE;
                gstate<=G_IDLE;
            end
            default:;
            endcase
        end
    end
end

assign decision_complete=wide_mode?g_decision:1'b0;
assign residual_required=wide_mode?g_required:1'b0;
assign residual_success=wide_mode?g_success:1'b0;
assign mixed_replay_active=wide_mode&&
    ((gstate==G_DESC)||(gstate==G_DESC2)||
     (gstate==G_SAMPLES)||(gstate==G_FINISH));
assign first_sample_valid=wide_mode?first_valid_reg:1'b0;
assign first_sample_value=wide_mode?first_value_reg:16'sd0;
assign residual_sample_valid=wide_mode?replay_valid:1'b0;
assign residual_sample_index=wide_mode?replay_index:6'd0;
assign residual_sample_value=wide_mode?replay_value:16'sd0;
assign probe_error=terr|g_error;

endmodule
