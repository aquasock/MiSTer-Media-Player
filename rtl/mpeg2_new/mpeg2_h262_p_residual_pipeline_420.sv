//============================================================================
// MiSTer Media Player - shared H.262 P residual pipeline
//
// Legacy generalized mode consumes the historical 48-macroblock packed plan.
// kate - Commit 166 adds a wide mode that reuses the same non-intra transform
// and sparse residual RAM while motion metadata streams directly to the shared
// raster engine. Wide residual descriptors carry an 11-bit macroblock index.
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
    input wire wide_picture_complete,
    input wire [351:0] wide_residual_mb_plan,
    input wire [95:0] wide_residual_block_index_plan,
    input wire [5:0] wide_residual_block_count,
    input wire [383:0] wide_coeff_index_plan,
    input wire [831:0] wide_coeff_value_plan,
    input wire [63:0] wide_coeff_last_plan,
    input wire [6:0] wide_coeff_count,
    input wire [159:0] wide_qscale_plan,
    input wire wide_q_scale_type,
    input wire wide_alternate_scan,

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

localparam [5:0] MAX_BLOCKS=6'd32;
localparam [6:0] MAX_COEFF_EVENTS=7'd64;
wire any_general_mode = general_mode || wide_mode;

// Accepted legacy first-macroblock parser remains available outside either
// generalized raster client.
wire old_decision, old_required, old_success, old_parser_error;
wire [4:0] old_qscale;
wire old_qtype, old_alt;
wire [2:0] old_block;
wire old_start, old_we, old_end;
wire [5:0] old_widx;
wire signed [12:0] old_wval;
wire transform_done;

mpeg2_h262_p_residual_parser_420 parser
(
    .clk(clk), .reset(reset),
    .stream_data(stream_data), .stream_valid(stream_valid),
    .p_picture_expected(p_picture_expected),
    .transform_block_done(transform_done&&!any_general_mode),
    .decision_complete(old_decision),
    .residual_required(old_required),
    .residual_success(old_success),
    .quantiser_scale_code(old_qscale),
    .q_scale_type(old_qtype),
    .alternate_scan(old_alt),
    .qfs_block_index(old_block),
    .qfs_block_start(old_start),
    .qfs_write_en(old_we),
    .qfs_write_index(old_widx),
    .qfs_write_value(old_wval),
    .qfs_block_end(old_end),
    .probe_error(old_parser_error)
);

localparam [3:0]
    G_IDLE=4'd0,
    G_SCAN=4'd1,
    G_START=4'd2,
    G_WRITE=4'd3,
    G_END=4'd4,
    G_WAIT=4'd5,
    G_MOTION=4'd6,
    G_DESC=4'd7,
    G_DESC2=4'd8,
    G_SAMPLES=4'd9,
    G_FINISH=4'd10;
reg [3:0] gstate;
reg g_decision, g_required, g_success, g_error, g_wide;

reg [383:0] g_motion_x, g_motion_y;
reg [287:0] gplan;
reg [383:0] g_coeff_index;
reg [831:0] g_coeff_value;
reg [63:0] g_coeff_last;
reg [159:0] g_qscale;
reg g_qtype, g_alt;
reg [5:0] expected_blocks, slot_count;
reg [6:0] expected_coeffs, coeff_read_index;

reg [8:0] scan_index;
reg [5:0] scan_mb;
reg [2:0] scan_block, current_block;
reg [4:0] current_qscale;
reg [10:0] desc_mb [0:31];
reg [2:0] desc_block [0:31];
reg signed [15:0] gmem [0:2047];
reg [6:0] sample_cap_count;

reg gstart, gwe, gend;
reg [5:0] gwidx;
reg signed [12:0] gwval;

reg [5:0] replay_motion_mb;
reg [5:0] replay_slot;
reg [5:0] replay_sample;
reg replay_valid, first_valid_reg;
reg [5:0] replay_index;
reg signed [15:0] replay_value, first_value_reg;
integer i;

wire [10:0] replay_mem_index =
    {replay_slot[4:0],6'b000000}+{5'd0,replay_sample};
wire [5:0] coeff_idx_current =
    g_coeff_index[(coeff_read_index*6)+:6];
wire signed [12:0] coeff_val_current =
    $signed(g_coeff_value[(coeff_read_index*13)+:13]);
wire coeff_last_current = g_coeff_last[coeff_read_index];
wire signed [7:0] replay_mvx =
    $signed(g_motion_x[(replay_motion_mb*8)+:8]);
wire signed [7:0] replay_mvy =
    $signed(g_motion_y[(replay_motion_mb*8)+:8]);

wire [2:0] qblock = any_general_mode ? current_block : old_block;
wire qstart = any_general_mode ? gstart : old_start;
wire qwe    = any_general_mode ? gwe    : old_we;
wire qend   = any_general_mode ? gend   : old_end;
wire [5:0] qwidx = any_general_mode ? gwidx : old_widx;
wire signed [12:0] qwval =
    any_general_mode ? gwval : old_wval;
wire [4:0] qscale =
    any_general_mode ? current_qscale : old_qscale;
wire qtype = any_general_mode ? g_qtype : old_qtype;
wire alt   = any_general_mode ? g_alt : old_alt;

// The transform's block-index 0 is reserved for the legacy Phase-1T proof.
// Generalized syntax must not inherit that diagnostic key.
wire [1:0] tblock =
    any_general_mode ? 2'd1 :
    ((qblock==0)?2'd0:2'd1);
wire tfvalid, tvalid, terr;
wire signed [15:0] tfvalue, tvalue;
wire [1:0] unused_block;
wire [5:0] tidx;

mpeg2_h262_p_non_intra_transform transform
(
    .clk(clk), .reset(reset),
    .qfs_block_index(tblock),
    .qfs_block_start(qstart),
    .qfs_write_en(qwe),
    .qfs_write_index(qwidx),
    .qfs_write_value(qwval),
    .qfs_block_end(qend),
    .quantiser_scale_code(qscale),
    .q_scale_type(qtype),
    .alternate_scan(alt),
    .block_done(transform_done),
    .first_sample_valid(tfvalid),
    .first_sample_value(tfvalue),
    .residual_sample_valid(tvalid),
    .residual_sample_block_index(unused_block),
    .residual_sample_index(tidx),
    .residual_sample_value(tvalue),
    .probe_error(terr)
);

always @(posedge clk) begin
    if(reset) begin
        gstate<=G_IDLE;
        g_decision<=0;
        g_required<=0;
        g_success<=0;
        g_error<=0;
        g_wide<=0;
        g_motion_x<=0;
        g_motion_y<=0;
        gplan<=0;
        g_coeff_index<=0;
        g_coeff_value<=0;
        g_coeff_last<=0;
        g_qscale<=0;
        g_qtype<=0;
        g_alt<=0;
        expected_blocks<=0;
        slot_count<=0;
        expected_coeffs<=0;
        coeff_read_index<=0;
        scan_index<=0;
        scan_mb<=0;
        scan_block<=0;
        current_block<=0;
        current_qscale<=0;
        sample_cap_count<=0;
        gstart<=0;
        gwe<=0;
        gend<=0;
        gwidx<=0;
        gwval<=0;
        replay_motion_mb<=0;
        replay_slot<=0;
        replay_sample<=0;
        replay_valid<=0;
        first_valid_reg<=0;
        replay_index<=0;
        replay_value<=0;
        first_value_reg<=0;
        for(i=0;i<32;i=i+1) begin
            desc_mb[i]<=0;
            desc_block[i]<=0;
        end
    end else begin
        gstart<=0;
        gwe<=0;
        gend<=0;
        replay_valid<=0;
        first_valid_reg<=0;

        // kate - Commit 166: wide geometry reuses this exact transform and
        // spatial residual buffer; only descriptor addressing is widened.
        if(wide_picture_complete) begin
            g_wide<=1;
            g_decision<=1;
            g_required<=(wide_residual_block_count!=0);
            g_success<=0;
            g_coeff_index<=wide_coeff_index_plan;
            g_coeff_value<=wide_coeff_value_plan;
            g_coeff_last<=wide_coeff_last_plan;
            g_qscale<=wide_qscale_plan;
            g_qtype<=wide_q_scale_type;
            g_alt<=wide_alternate_scan;
            expected_blocks<=wide_residual_block_count;
            expected_coeffs<=wide_coeff_count;
            slot_count<=0;
            coeff_read_index<=0;
            sample_cap_count<=0;
            replay_slot<=0;
            replay_sample<=0;
            for(i=0;i<32;i=i+1) begin
                desc_mb[i]<=wide_residual_mb_plan[(i*11)+:11];
                desc_block[i]<=
                    wide_residual_block_index_plan[(i*3)+:3];
            end
            if((wide_residual_block_count>MAX_BLOCKS) ||
               (wide_coeff_count>MAX_COEFF_EVENTS)) begin
                g_error<=1;
                gstate<=G_IDLE;
            end else if(wide_residual_block_count!=0) begin
                current_block<=wide_residual_block_index_plan[2:0];
                current_qscale<=wide_qscale_plan[4:0];
                gstate<=G_START;
            end else begin
                if(wide_coeff_count!=0) g_error<=1;
                g_success<=1;
                gstate<=G_FINISH;
            end
        end else if(general_picture_complete) begin
            g_wide<=0;
            g_decision<=1;
            g_required<=(general_residual_block_count!=0);
            g_success<=0;
            g_motion_x<=general_motion_x_plan;
            g_motion_y<=general_motion_y_plan;
            gplan<=general_residual_block_plan;
            g_coeff_index<=general_coeff_index_plan;
            g_coeff_value<=general_coeff_value_plan;
            g_coeff_last<=general_coeff_last_plan;
            g_qscale<=general_qscale_plan;
            g_qtype<=general_q_scale_type;
            g_alt<=general_alternate_scan;
            expected_blocks<=general_residual_block_count;
            expected_coeffs<=general_coeff_count;
            slot_count<=0;
            coeff_read_index<=0;
            scan_index<=0;
            scan_mb<=0;
            scan_block<=0;
            sample_cap_count<=0;
            replay_motion_mb<=0;
            replay_slot<=0;
            replay_sample<=0;
            if((general_residual_block_count>MAX_BLOCKS) ||
               (general_coeff_count>MAX_COEFF_EVENTS)) begin
                g_error<=1;
                gstate<=G_IDLE;
            end else if(general_residual_block_count!=0) begin
                gstate<=G_SCAN;
            end else begin
                if(general_coeff_count!=0) g_error<=1;
                g_success<=1;
                gstate<=G_MOTION;
            end
        end

        if(any_general_mode&&tvalid) begin
            if(slot_count>=MAX_BLOCKS ||
               tidx!=sample_cap_count[5:0] ||
               sample_cap_count>=7'd64) begin
                g_error<=1;
            end else begin
                gmem[{slot_count[3:0],6'b000000}+tidx]<=tvalue;
                sample_cap_count<=sample_cap_count+1'b1;
            end
        end

        case(gstate)
        G_SCAN: begin
            if(scan_index>=9'd288) begin
                if((slot_count!=expected_blocks) ||
                   (slot_count==0) ||
                   (coeff_read_index!=expected_coeffs)) begin
                    g_error<=1;
                    gstate<=G_IDLE;
                end else begin
                    g_success<=1;
                    replay_motion_mb<=0;
                    gstate<=G_MOTION;
                end
            end else if(gplan[scan_index]) begin
                if(slot_count>=MAX_BLOCKS ||
                   slot_count>=expected_blocks) begin
                    g_error<=1;
                    gstate<=G_IDLE;
                end else begin
                    desc_mb[slot_count]<={5'd0,scan_mb};
                    desc_block[slot_count]<=scan_block;
                    current_block<=scan_block;
                    current_qscale<=
                        g_qscale[(slot_count*5)+:5];
                    sample_cap_count<=0;
                    gstate<=G_START;
                end
            end else begin
                scan_index<=scan_index+1'b1;
                if(scan_block==5) begin
                    scan_block<=0;
                    scan_mb<=scan_mb+1'b1;
                end else scan_block<=scan_block+1'b1;
            end
        end

        G_START: begin
            gstart<=1;
            gstate<=G_WRITE;
        end

        G_WRITE: begin
            if(coeff_read_index>=expected_coeffs ||
               coeff_read_index>=MAX_COEFF_EVENTS) begin
                g_error<=1;
                gstate<=G_IDLE;
            end else begin
                gwe<=1;
                gwidx<=coeff_idx_current;
                gwval<=coeff_val_current;
                coeff_read_index<=coeff_read_index+1'b1;
                if(coeff_last_current) gstate<=G_END;
            end
        end

        G_END: begin
            gend<=1;
            gstate<=G_WAIT;
        end

        G_WAIT: if(transform_done) begin
            if((sample_cap_count+(tvalid?7'd1:7'd0))!=7'd64)
                g_error<=1;
            if(g_wide) begin
                if(slot_count+1'b1>=expected_blocks) begin
                    slot_count<=slot_count+1'b1;
                    if(coeff_read_index!=expected_coeffs)
                        g_error<=1;
                    g_success<=1;
                    replay_slot<=0;
                    gstate<=G_DESC;
                end else begin
                    slot_count<=slot_count+1'b1;
                    current_block<=desc_block[slot_count+1'b1];
                    current_qscale<=
                        g_qscale[((slot_count+1'b1)*5)+:5];
                    sample_cap_count<=0;
                    gstate<=G_START;
                end
            end else begin
                slot_count<=slot_count+1'b1;
                scan_index<=scan_index+1'b1;
                if(scan_block==5) begin
                    scan_block<=0;
                    scan_mb<=scan_mb+1'b1;
                end else scan_block<=scan_block+1'b1;
                gstate<=G_SCAN;
            end
        end

        G_MOTION: begin
            replay_valid<=1;
            replay_index<=6'h3e;
            replay_value<=$signed({replay_mvx[7:0],replay_mvy[7:0]});
            if(replay_motion_mb==6'd47) begin
                if(slot_count==0) gstate<=G_FINISH;
                else begin
                    replay_slot<=0;
                    gstate<=G_DESC;
                end
            end else replay_motion_mb<=replay_motion_mb+1'b1;
        end

        G_DESC: begin
            replay_valid<=1;
            if(g_wide) begin
                replay_index<=6'h3c;
                replay_value<=$signed({5'd0,desc_mb[replay_slot]});
                gstate<=G_DESC2;
            end else begin
                replay_index<=6'h3f;
                replay_value<=$signed({
                    4'hB,3'b000,
                    desc_mb[replay_slot][5:0],
                    desc_block[replay_slot]
                });
                replay_sample<=0;
                gstate<=G_SAMPLES;
            end
        end

        G_DESC2: begin
            replay_valid<=1;
            replay_index<=6'h3d;
            replay_value<=$signed({13'd0,desc_block[replay_slot]});
            replay_sample<=0;
            gstate<=G_SAMPLES;
        end

        G_SAMPLES: begin
            replay_valid<=1;
            replay_index<=replay_sample;
            replay_value<=gmem[replay_mem_index];
            if((replay_slot==0)&&(replay_sample==0)) begin
                first_valid_reg<=1;
                first_value_reg<=gmem[replay_mem_index];
            end
            if(replay_sample==6'd63) begin
                if(replay_slot+1'b1>=slot_count)
                    gstate<=G_FINISH;
                else begin
                    replay_slot<=replay_slot+1'b1;
                    gstate<=G_DESC;
                end
            end else replay_sample<=replay_sample+1'b1;
        end

        G_FINISH: begin
            replay_valid<=1;
            replay_index<=6'h3f;
            replay_value<=16'shA2FF;
            gstate<=G_IDLE;
        end
        default:;
        endcase
    end
end

assign decision_complete =
    any_general_mode ? g_decision : old_decision;
assign residual_required =
    any_general_mode ? g_required : old_required;
assign residual_success =
    any_general_mode ? g_success : old_success;
assign mixed_replay_active = any_general_mode &&
    ((gstate==G_MOTION) ||
     (gstate==G_DESC) ||
     (gstate==G_DESC2) ||
     (gstate==G_SAMPLES) ||
     (gstate==G_FINISH));
assign first_sample_valid =
    any_general_mode ? first_valid_reg : tfvalid;
assign first_sample_value =
    any_general_mode ? first_value_reg : tfvalue;
assign residual_sample_valid =
    any_general_mode ? replay_valid : tvalid;
assign residual_sample_index =
    any_general_mode ? replay_index : tidx;
assign residual_sample_value =
    any_general_mode ? replay_value : tvalue;
assign probe_error =
    terr | g_error | (!any_general_mode && old_parser_error);

endmodule
