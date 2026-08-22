//============================================================================
// MiSTer Media Player - development hardware cadence profiler
//
// Entry 312: retain schema-v3 aggregates and capture the scheduler/hold state
// when each ranked gap first exceeds the legal cadence window.
// All inputs are observational; no output feeds decoder or presentation logic.
//============================================================================
`timescale 1ns/1ps
module mpeg2_h262_hardware_cadence_profiler #(
    parameter [23:0] TERMINAL_SNAPSHOT_DELAY = 24'd13500000,
    parameter [26:0] NO_PROGRESS_SNAPSHOT_DELAY = 27'd54000000,
    parameter [31:0] OUTLIER_GAP_CYCLES = 32'd2700000
)(
    input wire clk_mpeg2,input wire reset_mpeg2,
    input wire clk_video,input wire reset_video,
    input wire fifo_pending,input wire decoder_ready,
    input wire presentation_hold,input wire destination_hold,
    input wire scratch_available,input wire promotion_active,
    input wire frame_waiting,input wire [1:0] completed_frame_bank,
    input wire presentation_complete,input wire presentation_error,
    input wire [31:0] scheduler_debug_state,
    input wire decoder_byte_accepted,
    input wire [2:0] picture_coding_type,
    input wire [9:0] temporal_reference,
    input wire [3:0] frame_rate_code,input wire [7:0] picture_count,
    input wire reference_picture_complete,input wire b_picture_complete,
    input wire prediction_read,input wire prediction_busy,
    input wire prediction_data_ready,input wire writer_write,
    input wire writer_busy,input wire [1:0] display_frame_bank,
    input wire display_scratch,input wire display_scratch_bank,
    input wire sequence_end_seen,input wire session_quiet,
    input wire [15:0] error_flags,input wire [11:0] h_pos,
    input wire [11:0] v_pos,input wire [7:0] base_r,
    input wire [7:0] base_g,input wire [7:0] base_b,input wire base_de,
    output reg [7:0] video_r,output reg [7:0] video_g,
    output reg [7:0] video_b,output wire snapshot_ready
);

localparam integer SNAPSHOT_WORDS=38;
localparam integer SNAPSHOT_BITS=SNAPSHOT_WORDS*32;
localparam [23:0] TERMINAL_SNAPSHOT_LIMIT=
    TERMINAL_SNAPSHOT_DELAY-24'd1;
localparam [26:0] NO_PROGRESS_SNAPSHOT_LIMIT=
    NO_PROGRESS_SNAPSHOT_DELAY-27'd1;
localparam [31:0] SNAPSHOT_MAGIC=32'h4d4d5031;
localparam [31:0] SNAPSHOT_FORMAT={8'd4,8'd38,16'd54000};
localparam [11:0] OVERLAY_X=12'd8,OVERLAY_Y=12'd444;
localparam [11:0] OVERLAY_WIDTH=12'd172,OVERLAY_HEIGHT=12'd152;

reg session_active;
reg fifo_pending_q,decoder_ready_q,presentation_hold_q,destination_hold_q;
reg scratch_available_q,promotion_active_q,frame_waiting_q;
reg [1:0] completed_frame_bank_q;
reg presentation_complete_q,presentation_error_q;
reg [31:0] scheduler_debug_state_q;
reg decoder_byte_accepted_q;
reg [2:0] picture_coding_type_q;
reg [9:0] temporal_reference_q;
reg [3:0] frame_rate_code_q;
reg [7:0] picture_count_q;
reg reference_picture_complete_q,b_picture_complete_q;
reg prediction_read_q,prediction_busy_q,prediction_data_ready_q;
reg writer_write_q,writer_busy_q;
reg [1:0] display_frame_bank_q;
reg display_scratch_q,display_scratch_bank_q;
reg sequence_end_seen_q,session_quiet_q;
reg [15:0] error_flags_q;

reg [31:0] session_cycles,accepted_bytes;
reg [31:0] first_present_cycle,last_present_cycle;
reg first_present_valid;
reg [31:0] decoder_stall_cycles,presentation_stall_cycles;
reg [31:0] destination_stall_cycles;
reg [31:0] presentation_hold_total_cycles,destination_hold_total_cycles;
reg [31:0] hold_overlap_cycles,hold_scratch_available_cycles;
reg [31:0] hold_promotion_pending_cycles;
reg [31:0] i_stall_cycles,p_stall_cycles,b_stall_cycles;
reg [31:0] prediction_requests,prediction_request_wait_cycles;
reg [31:0] prediction_response_cycles;
reg prediction_outstanding;
reg [31:0] writer_wait_cycles;
reg [7:0] reference_picture_count,b_picture_count;
reg [7:0] display_picture_count,display_swap_count;
reg b_picture_complete_d;
reg [1:0] display_frame_bank_d;
reg display_scratch_d,display_scratch_bank_d;

reg [31:0] largest_gap_0,largest_gap_1,largest_gap_2;
reg [31:0] largest_gap_meta_0,largest_gap_meta_1,largest_gap_meta_2;
reg [31:0] largest_gap_state_0,largest_gap_state_1,largest_gap_state_2;
reg [31:0] current_gap_meta,current_gap_state;
reg current_gap_context_valid;
reg [15:0] gap_outlier_count;
reg [9:0] quiet_count;
reg [23:0] terminal_wait_count;
reg [26:0] no_progress_wait_count;
reg [1:0] snapshot_reason;
reg [SNAPSHOT_BITS-1:0] snapshot_mpeg2;
reg snapshot_ready_mpeg2;

wire b_picture_complete_edge=b_picture_complete_q&&!b_picture_complete_d;
wire display_swap_now=first_present_valid&&
    ((display_frame_bank_q!=display_frame_bank_d)||
     (display_scratch_q!=display_scratch_d)||
     (display_scratch_q&&(display_scratch_bank_q!=display_scratch_bank_d)));
wire prediction_request_accepted=prediction_read_q&&!prediction_busy_q;
wire session_progress=decoder_byte_accepted_q||reference_picture_complete_q||
    b_picture_complete_edge||display_swap_now||prediction_request_accepted||
    prediction_data_ready_q||writer_write_q;
wire [31:0] display_gap_now=session_cycles-last_present_cycle;
wire cadence_rate_supported=(frame_rate_code_q==4'h2)||
                            (frame_rate_code_q==4'h3);
wire [31:0] display_gap_meta_now={
    display_picture_count+1'b1,
    presentation_hold_q,destination_hold_q,fifo_pending_q,decoder_ready_q,
    scratch_available_q,promotion_active_q,frame_waiting_q,
    presentation_complete_q,presentation_error_q,
    sequence_end_seen_q,session_quiet_q,
    completed_frame_bank_q,display_frame_bank_q,
    display_scratch_q,display_scratch_bank_q,7'd0
};
wire [31:0] completed_gap_meta=current_gap_context_valid?
    current_gap_meta:display_gap_meta_now;
wire [31:0] completed_gap_state=current_gap_context_valid?
    current_gap_state:scheduler_debug_state_q;

wire [31:0] snapshot_word_00=SNAPSHOT_MAGIC;
wire [31:0] snapshot_word_01=SNAPSHOT_FORMAT;
wire [31:0] snapshot_word_02=accepted_bytes;
wire [31:0] snapshot_word_03=session_cycles;
wire [31:0] snapshot_word_04=first_present_cycle;
wire [31:0] snapshot_word_05=last_present_cycle;
wire [31:0] snapshot_word_06=last_present_cycle-first_present_cycle;
wire [31:0] snapshot_word_07=decoder_stall_cycles;
wire [31:0] snapshot_word_08=presentation_stall_cycles;
wire [31:0] snapshot_word_09=destination_stall_cycles;
wire [31:0] snapshot_word_10=i_stall_cycles;
wire [31:0] snapshot_word_11=p_stall_cycles;
wire [31:0] snapshot_word_12=b_stall_cycles;
wire [31:0] snapshot_word_13=prediction_requests;
wire [31:0] snapshot_word_14=prediction_request_wait_cycles;
wire [31:0] snapshot_word_15=prediction_response_cycles;
wire [31:0] snapshot_word_16=writer_wait_cycles;
wire [31:0] snapshot_word_17={reference_picture_count,b_picture_count,
    display_picture_count,display_swap_count};
wire [31:0] snapshot_word_18={frame_rate_code_q,picture_coding_type_q,
    temporal_reference_q,picture_count_q,7'd0};
wire [31:0] snapshot_word_19={error_flags_q,16'd0};
wire [31:0] snapshot_word_20=presentation_hold_total_cycles;
wire [31:0] snapshot_word_21=destination_hold_total_cycles;
wire [31:0] snapshot_word_22=hold_overlap_cycles;
wire [31:0] snapshot_word_23=hold_scratch_available_cycles;
wire [31:0] snapshot_word_24=hold_promotion_pending_cycles;
wire [31:0] snapshot_word_25={snapshot_reason,14'd0,gap_outlier_count};
wire [31:0] snapshot_word_26=largest_gap_0;
wire [31:0] snapshot_word_27=largest_gap_meta_0;
wire [31:0] snapshot_word_28=largest_gap_state_0;
wire [31:0] snapshot_word_29=largest_gap_1;
wire [31:0] snapshot_word_30=largest_gap_meta_1;
wire [31:0] snapshot_word_31=largest_gap_state_1;
wire [31:0] snapshot_word_32=largest_gap_2;
wire [31:0] snapshot_word_33=largest_gap_meta_2;
wire [31:0] snapshot_word_34=largest_gap_state_2;
wire [31:0] snapshot_word_35={completed_frame_bank_q,display_frame_bank_q,
    display_scratch_q,display_scratch_bank_q,frame_waiting_q,
    presentation_hold_q,destination_hold_q,session_quiet_q,
    sequence_end_seen_q,presentation_complete_q,presentation_error_q,19'd0};
wire [31:0] snapshot_word_36=scheduler_debug_state_q;
wire [31:0] snapshot_word_37=snapshot_word_00^snapshot_word_01^
    snapshot_word_02^snapshot_word_03^snapshot_word_04^snapshot_word_05^
    snapshot_word_06^snapshot_word_07^snapshot_word_08^snapshot_word_09^
    snapshot_word_10^snapshot_word_11^snapshot_word_12^snapshot_word_13^
    snapshot_word_14^snapshot_word_15^snapshot_word_16^snapshot_word_17^
    snapshot_word_18^snapshot_word_19^snapshot_word_20^snapshot_word_21^
    snapshot_word_22^snapshot_word_23^snapshot_word_24^snapshot_word_25^
    snapshot_word_26^snapshot_word_27^snapshot_word_28^snapshot_word_29^
    snapshot_word_30^snapshot_word_31^snapshot_word_32^snapshot_word_33^
    snapshot_word_34^snapshot_word_35^snapshot_word_36;

task capture_snapshot;
begin
    snapshot_mpeg2<={snapshot_word_37,snapshot_word_36,snapshot_word_35,
        snapshot_word_34,snapshot_word_33,snapshot_word_32,
        snapshot_word_31,snapshot_word_30,snapshot_word_29,snapshot_word_28,
        snapshot_word_27,snapshot_word_26,snapshot_word_25,snapshot_word_24,
        snapshot_word_23,snapshot_word_22,snapshot_word_21,snapshot_word_20,
        snapshot_word_19,snapshot_word_18,snapshot_word_17,snapshot_word_16,
        snapshot_word_15,snapshot_word_14,snapshot_word_13,snapshot_word_12,
        snapshot_word_11,snapshot_word_10,snapshot_word_09,snapshot_word_08,
        snapshot_word_07,snapshot_word_06,snapshot_word_05,snapshot_word_04,
        snapshot_word_03,snapshot_word_02,snapshot_word_01,snapshot_word_00};
    snapshot_ready_mpeg2<=1'b1;
end
endtask

always @(posedge clk_mpeg2) begin
    if(reset_mpeg2)begin
        session_active<=0;fifo_pending_q<=0;decoder_ready_q<=0;
        presentation_hold_q<=0;destination_hold_q<=0;
        scratch_available_q<=0;promotion_active_q<=0;frame_waiting_q<=0;
        completed_frame_bank_q<=0;presentation_complete_q<=0;
        presentation_error_q<=0;scheduler_debug_state_q<=0;
        decoder_byte_accepted_q<=0;picture_coding_type_q<=0;
        temporal_reference_q<=0;frame_rate_code_q<=0;picture_count_q<=0;
        reference_picture_complete_q<=0;b_picture_complete_q<=0;
        prediction_read_q<=0;prediction_busy_q<=0;
        prediction_data_ready_q<=0;writer_write_q<=0;writer_busy_q<=0;
        display_frame_bank_q<=0;display_scratch_q<=0;
        display_scratch_bank_q<=0;sequence_end_seen_q<=0;
        session_quiet_q<=0;error_flags_q<=0;
        session_cycles<=0;accepted_bytes<=0;first_present_cycle<=0;
        last_present_cycle<=0;first_present_valid<=0;
        decoder_stall_cycles<=0;presentation_stall_cycles<=0;
        destination_stall_cycles<=0;presentation_hold_total_cycles<=0;
        destination_hold_total_cycles<=0;hold_overlap_cycles<=0;
        hold_scratch_available_cycles<=0;hold_promotion_pending_cycles<=0;
        i_stall_cycles<=0;p_stall_cycles<=0;b_stall_cycles<=0;
        prediction_requests<=0;prediction_request_wait_cycles<=0;
        prediction_response_cycles<=0;prediction_outstanding<=0;
        writer_wait_cycles<=0;reference_picture_count<=0;b_picture_count<=0;
        display_picture_count<=0;display_swap_count<=0;
        b_picture_complete_d<=0;display_frame_bank_d<=0;
        display_scratch_d<=0;display_scratch_bank_d<=0;
        largest_gap_0<=0;largest_gap_1<=0;largest_gap_2<=0;
        largest_gap_meta_0<=0;largest_gap_meta_1<=0;largest_gap_meta_2<=0;
        largest_gap_state_0<=0;largest_gap_state_1<=0;largest_gap_state_2<=0;
        current_gap_meta<=0;current_gap_state<=0;current_gap_context_valid<=0;
        gap_outlier_count<=0;quiet_count<=0;terminal_wait_count<=0;
        no_progress_wait_count<=0;
        snapshot_reason<=0;snapshot_mpeg2<=0;snapshot_ready_mpeg2<=0;
    end else begin
        fifo_pending_q<=fifo_pending;decoder_ready_q<=decoder_ready;
        presentation_hold_q<=presentation_hold;
        destination_hold_q<=destination_hold;
        scratch_available_q<=scratch_available;promotion_active_q<=promotion_active;
        frame_waiting_q<=frame_waiting;completed_frame_bank_q<=completed_frame_bank;
        presentation_complete_q<=presentation_complete;
        presentation_error_q<=presentation_error;
        scheduler_debug_state_q<=scheduler_debug_state;
        decoder_byte_accepted_q<=decoder_byte_accepted;
        picture_coding_type_q<=picture_coding_type;
        temporal_reference_q<=temporal_reference;frame_rate_code_q<=frame_rate_code;
        picture_count_q<=picture_count;
        reference_picture_complete_q<=reference_picture_complete;
        b_picture_complete_q<=b_picture_complete;
        prediction_read_q<=prediction_read;prediction_busy_q<=prediction_busy;
        prediction_data_ready_q<=prediction_data_ready;
        writer_write_q<=writer_write;writer_busy_q<=writer_busy;
        display_frame_bank_q<=display_frame_bank;display_scratch_q<=display_scratch;
        display_scratch_bank_q<=display_scratch_bank;
        sequence_end_seen_q<=sequence_end_seen;session_quiet_q<=session_quiet;
        error_flags_q<=error_flags;
        b_picture_complete_d<=b_picture_complete_q;
        display_frame_bank_d<=display_frame_bank_q;
        display_scratch_d<=display_scratch_q;
        display_scratch_bank_d<=display_scratch_bank_q;

        if(decoder_byte_accepted_q)session_active<=1;
        if(!snapshot_ready_mpeg2&&(session_active||decoder_byte_accepted_q))begin
            session_cycles<=session_cycles+1'b1;
            if(decoder_byte_accepted_q)accepted_bytes<=accepted_bytes+1'b1;
            if(fifo_pending_q)begin
                if(!decoder_ready_q)begin
                    decoder_stall_cycles<=decoder_stall_cycles+1'b1;
                    case(picture_coding_type_q)
                    3'b001:i_stall_cycles<=i_stall_cycles+1'b1;
                    3'b010:p_stall_cycles<=p_stall_cycles+1'b1;
                    3'b011:b_stall_cycles<=b_stall_cycles+1'b1;
                    default:;
                    endcase
                end else if(presentation_hold_q)
                    presentation_stall_cycles<=presentation_stall_cycles+1'b1;
                else if(destination_hold_q)
                    destination_stall_cycles<=destination_stall_cycles+1'b1;
            end
            if(presentation_hold_q)
                presentation_hold_total_cycles<=presentation_hold_total_cycles+1'b1;
            if(destination_hold_q)
                destination_hold_total_cycles<=destination_hold_total_cycles+1'b1;
            if(presentation_hold_q&&destination_hold_q)
                hold_overlap_cycles<=hold_overlap_cycles+1'b1;
            if(presentation_hold_q&&scratch_available_q)
                hold_scratch_available_cycles<=hold_scratch_available_cycles+1'b1;
            if(presentation_hold_q&&promotion_active_q)
                hold_promotion_pending_cycles<=hold_promotion_pending_cycles+1'b1;
            if(prediction_request_accepted)
                prediction_requests<=prediction_requests+1'b1;
            if(prediction_read_q&&prediction_busy_q)
                prediction_request_wait_cycles<=prediction_request_wait_cycles+1'b1;
            if(prediction_outstanding)
                prediction_response_cycles<=prediction_response_cycles+1'b1;
            if(writer_write_q&&writer_busy_q)
                writer_wait_cycles<=writer_wait_cycles+1'b1;
            case({prediction_request_accepted,prediction_data_ready_q})
            2'b10:prediction_outstanding<=1;
            2'b01:prediction_outstanding<=0;
            2'b11:prediction_outstanding<=1;
            default:;
            endcase
            if(reference_picture_complete_q)begin
                reference_picture_count<=reference_picture_count+1'b1;
                if(!first_present_valid)begin
                    first_present_valid<=1;first_present_cycle<=session_cycles;
                    last_present_cycle<=session_cycles;display_picture_count<=1;
                end
            end
            if(b_picture_complete_edge)b_picture_count<=b_picture_count+1'b1;

            // Capture the blocking state at threshold crossing, not at the
            // eventual swap where the scheduler may already have released it.
            if(first_present_valid&&!display_swap_now&&
               !current_gap_context_valid&&cadence_rate_supported&&
               (display_gap_now>OUTLIER_GAP_CYCLES))begin
                current_gap_meta<=display_gap_meta_now;
                current_gap_state<=scheduler_debug_state_q;
                current_gap_context_valid<=1;
            end
            if(display_swap_now)begin
                last_present_cycle<=session_cycles;
                display_swap_count<=display_swap_count+1'b1;
                display_picture_count<=display_picture_count+1'b1;
                current_gap_context_valid<=0;
                if(cadence_rate_supported&&
                   (display_gap_now>OUTLIER_GAP_CYCLES)&&
                   (gap_outlier_count!=16'hffff))
                    gap_outlier_count<=gap_outlier_count+1'b1;
                if(display_gap_now>largest_gap_0)begin
                    largest_gap_2<=largest_gap_1;
                    largest_gap_meta_2<=largest_gap_meta_1;
                    largest_gap_state_2<=largest_gap_state_1;
                    largest_gap_1<=largest_gap_0;
                    largest_gap_meta_1<=largest_gap_meta_0;
                    largest_gap_state_1<=largest_gap_state_0;
                    largest_gap_0<=display_gap_now;
                    largest_gap_meta_0<=completed_gap_meta;
                    largest_gap_state_0<=completed_gap_state;
                end else if(display_gap_now>largest_gap_1)begin
                    largest_gap_2<=largest_gap_1;
                    largest_gap_meta_2<=largest_gap_meta_1;
                    largest_gap_state_2<=largest_gap_state_1;
                    largest_gap_1<=display_gap_now;
                    largest_gap_meta_1<=completed_gap_meta;
                    largest_gap_state_1<=completed_gap_state;
                end else if(display_gap_now>largest_gap_2)begin
                    largest_gap_2<=display_gap_now;
                    largest_gap_meta_2<=completed_gap_meta;
                    largest_gap_state_2<=completed_gap_state;
                end
            end
        end

        // Entry 314: a fatal transport result can suppress all later decoder
        // validity, including the sequence-end code that previously gated
        // this snapshot.  Capture the first settled fatal state directly.
        if(!snapshot_ready_mpeg2&&session_active&&(error_flags_q!=0))begin
            snapshot_reason<=3;terminal_wait_count<=0;
            no_progress_wait_count<=0;
            if(quiet_count==10'd1)capture_snapshot();
            else quiet_count<=quiet_count+1'b1;
        end else if(!snapshot_ready_mpeg2&&session_active&&sequence_end_seen_q&&
           session_quiet_q)begin
            snapshot_reason<=1;terminal_wait_count<=0;no_progress_wait_count<=0;
            if(quiet_count==10'd1023)capture_snapshot();
            else quiet_count<=quiet_count+1'b1;
        end else if(!snapshot_ready_mpeg2&&session_active&&sequence_end_seen_q)begin
            snapshot_reason<=2;quiet_count<=0;no_progress_wait_count<=0;
            if(terminal_wait_count==TERMINAL_SNAPSHOT_LIMIT)capture_snapshot();
            else terminal_wait_count<=terminal_wait_count+1'b1;
        end else if(!snapshot_ready_mpeg2&&session_active)begin
            snapshot_reason<=3;quiet_count<=0;terminal_wait_count<=0;
            if(session_progress)
                no_progress_wait_count<=0;
            else if(no_progress_wait_count==NO_PROGRESS_SNAPSHOT_LIMIT)begin
                no_progress_wait_count<=0;
                capture_snapshot();
            end else
                no_progress_wait_count<=no_progress_wait_count+1'b1;
        end else begin
            quiet_count<=0;terminal_wait_count<=0;no_progress_wait_count<=0;
        end
    end
end

(* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [SNAPSHOT_BITS-1:0] snapshot_sync_1;
(* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [SNAPSHOT_BITS-1:0] snapshot_sync_2;
(* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] snapshot_ready_sync;
always @(posedge clk_video)begin
    if(reset_video)begin snapshot_sync_1<=0;snapshot_sync_2<=0;
        snapshot_ready_sync<=0;end
    else begin snapshot_sync_1<=snapshot_mpeg2;snapshot_sync_2<=snapshot_sync_1;
        snapshot_ready_sync<={snapshot_ready_sync[1:0],snapshot_ready_mpeg2};end
end
assign snapshot_ready=snapshot_ready_sync[2];

reg [42:0] overlay_shift;
reg [31:0] overlay_row_word;
wire [11:0] overlay_row_offset=(v_pos-OVERLAY_Y)>>2;
wire [5:0] overlay_row_index=overlay_row_offset[5:0];
always @* begin
    case(overlay_row_index)
    0:overlay_row_word=snapshot_sync_2[31:0];
    1:overlay_row_word=snapshot_sync_2[63:32];
    2:overlay_row_word=snapshot_sync_2[95:64];
    3:overlay_row_word=snapshot_sync_2[127:96];
    4:overlay_row_word=snapshot_sync_2[159:128];
    5:overlay_row_word=snapshot_sync_2[191:160];
    6:overlay_row_word=snapshot_sync_2[223:192];
    7:overlay_row_word=snapshot_sync_2[255:224];
    8:overlay_row_word=snapshot_sync_2[287:256];
    9:overlay_row_word=snapshot_sync_2[319:288];
    10:overlay_row_word=snapshot_sync_2[351:320];
    11:overlay_row_word=snapshot_sync_2[383:352];
    12:overlay_row_word=snapshot_sync_2[415:384];
    13:overlay_row_word=snapshot_sync_2[447:416];
    14:overlay_row_word=snapshot_sync_2[479:448];
    15:overlay_row_word=snapshot_sync_2[511:480];
    16:overlay_row_word=snapshot_sync_2[543:512];
    17:overlay_row_word=snapshot_sync_2[575:544];
    18:overlay_row_word=snapshot_sync_2[607:576];
    19:overlay_row_word=snapshot_sync_2[639:608];
    20:overlay_row_word=snapshot_sync_2[671:640];
    21:overlay_row_word=snapshot_sync_2[703:672];
    22:overlay_row_word=snapshot_sync_2[735:704];
    23:overlay_row_word=snapshot_sync_2[767:736];
    24:overlay_row_word=snapshot_sync_2[799:768];
    25:overlay_row_word=snapshot_sync_2[831:800];
    26:overlay_row_word=snapshot_sync_2[863:832];
    27:overlay_row_word=snapshot_sync_2[895:864];
    28:overlay_row_word=snapshot_sync_2[927:896];
    29:overlay_row_word=snapshot_sync_2[959:928];
    30:overlay_row_word=snapshot_sync_2[991:960];
    31:overlay_row_word=snapshot_sync_2[1023:992];
    32:overlay_row_word=snapshot_sync_2[1055:1024];
    33:overlay_row_word=snapshot_sync_2[1087:1056];
    34:overlay_row_word=snapshot_sync_2[1119:1088];
    35:overlay_row_word=snapshot_sync_2[1151:1120];
    36:overlay_row_word=snapshot_sync_2[1183:1152];
    37:overlay_row_word=snapshot_sync_2[1215:1184];
    default:overlay_row_word=0;
    endcase
end
always @(posedge clk_video)begin
    if(reset_video)overlay_shift<=0;
    else if(h_pos==0)begin
        if(snapshot_ready&&(v_pos>=OVERLAY_Y)&&(v_pos<OVERLAY_Y+OVERLAY_HEIGHT))
            overlay_shift<={4'b1010,overlay_row_index,overlay_row_word,
                           ^overlay_row_word};
        else overlay_shift<=0;
    end else if((h_pos>=OVERLAY_X)&&(h_pos<OVERLAY_X+OVERLAY_WIDTH)&&
                (h_pos[1:0]==2'b11))
        overlay_shift<={overlay_shift[41:0],1'b0};
end
always @* begin
    video_r=base_r;video_g=base_g;video_b=base_b;
    if(snapshot_ready&&base_de&&(h_pos>=OVERLAY_X)&&
       (h_pos<OVERLAY_X+OVERLAY_WIDTH)&&(v_pos>=OVERLAY_Y)&&
       (v_pos<OVERLAY_Y+OVERLAY_HEIGHT))begin
        video_r=overlay_shift[42]?8'hff:8'h00;
        video_g=overlay_shift[42]?8'hff:8'h00;
        video_b=overlay_shift[42]?8'hff:8'h00;
    end
end
endmodule
