// Auto-detect Program Streams while preserving raw elementary bytes. Outputs
// use ordinary valid/ready. ENABLE_AUDIO retains video-only regression use;
// production enables the independent audio queue and forwards first-byte PTS.
module mpeg2_program_stream_ingress #(parameter ENABLE_AUDIO=0, parameter APPEND_RAW_END=0, parameter ENABLE_FILE_POSITION=0) (
    input wire clk, reset,
    input wire [7:0] input_data,
    input wire input_valid,
    output wire input_ready,
    input wire input_end,
    output wire [7:0] output_data,
    output wire output_valid,
    input wire output_ready,
    output wire output_end,
    output wire [32:0] video_pts,
    output wire video_pts_valid,
    output wire [7:0] audio_data,
    output wire audio_valid,
    input wire audio_ready,
    output wire [32:0] audio_pts,
    output wire audio_pts_valid,
    output wire is_program_stream,
    output wire demux_error,
    input wire force_program_stream,
    input wire [40:0] start_file_position,
    output wire [40:0] video_file_position,video_pack_position
);
localparam DETECT=3'd0, REPLAY=3'd1, RUN=3'd2, DRAIN=3'd3,
           END_CODE=3'd4, DONE=3'd5;
reg [2:0] state;
reg [31:0] prefix, video_tail;
reg [2:0] count;
reg [1:0] end_index;
reg program_stream, video_seen;
reg [40:0] file_position;
always @(posedge clk) begin
    if(reset) file_position<=ENABLE_FILE_POSITION ? start_file_position : 41'd0;
    else if(ENABLE_FILE_POSITION && input_valid && input_ready) file_position<=file_position+41'd1;
end
wire [40:0] source_position=state==REPLAY ? file_position-{38'd0,count} : file_position;
wire replay = state == REPLAY;
wire feed = replay || state == RUN;
wire [7:0] source_data = replay ? prefix[31:24] : input_data;
wire source_valid = replay ? count != 0 : input_valid;
wire demux_ready, video_valid;
wire [7:0] video_data;
wire source_ready = program_stream ? demux_ready : output_ready;

assign input_ready = state == DETECT || (state == RUN && source_ready);
assign output_valid = state == END_CODE ||
    (program_stream ? video_valid : (feed && source_valid));
assign output_data = state == END_CODE ?
    (end_index == 2'd3 ? 8'hb7 : end_index == 2'd2 ? 8'h01 : 8'h00) :
    (program_stream ? video_data : source_data);
assign output_end = state == DONE;
assign is_program_stream = program_stream;
wire demux_pts_valid;
assign video_pts_valid=demux_pts_valid&&state!=END_CODE&&program_stream;

mpeg2_h262_program_stream_demux #(.ENABLE_FILE_POSITION(ENABLE_FILE_POSITION)) demux (
    .clk(clk), .reset(reset),
    .input_file_position(source_position),.video_file_position(video_file_position),
    .video_pack_position(video_pack_position),
    .in_data(source_data), .in_valid(feed && program_stream && source_valid),
    .in_ready(demux_ready),
    .video_data(video_data), .video_valid(video_valid), .video_ready(output_ready),
    .video_pts(video_pts), .video_pts_valid(demux_pts_valid),
    .audio_data(audio_data), .audio_valid(audio_valid), .audio_ready(ENABLE_AUDIO ? audio_ready : 1'b1),
    .audio_pts(audio_pts), .audio_pts_valid(audio_pts_valid), .stream_end(), .demux_error(demux_error)
);

always @(posedge clk) begin
    if (reset) begin
        state <= DETECT;
        prefix <= 0;
        count <= 0;
        program_stream <= 0;
        video_tail <= 0;
        video_seen <= 0;
        end_index <= 0;
    end else begin
        if (output_valid && output_ready) begin
            video_tail <= {video_tail[23:0], output_data};
            video_seen <= 1;
        end
        case (state)
        DETECT: begin
            if (input_valid) begin
                prefix <= {prefix[23:0], input_data};
                if(count<3'd4) count <= count + 3'd1;
                // A probe may begin inside any PES payload. Search for a pack
                // before enabling the length-delimited demux, never interpret
                // arbitrary payload bytes as PES headers.
                if(ENABLE_FILE_POSITION && force_program_stream) begin
                    if(count>=3 && {prefix[23:0],input_data}==32'h000001ba) begin
                        program_stream<=1;count<=4;state<=REPLAY;
                    end
                end else if (count == 3'd3) begin
                    program_stream <= {prefix[23:0], input_data} == 32'h000001ba;
                    state <= REPLAY;
                end
            end else if (input_end) begin
                // Probing EOF without finding a pack emits no raw bytes.
                if(ENABLE_FILE_POSITION && force_program_stream) begin state<=DONE;count<=0;end
                else begin
                // Preserve short raw files, including the stock-Main odd pad.
                prefix <= prefix << ((4-count)*8);
                state <= count == 0 ? DONE : REPLAY;
                end
            end
        end
        REPLAY: if (source_ready) begin
            prefix <= {prefix[23:0], 8'd0};
            count <= count - 3'd1;
            if (count == 3'd1) state <= RUN;
        end
        RUN: if (input_end && !input_valid) state <= DRAIN;
        DRAIN: if (!video_valid && (!ENABLE_AUDIO || !audio_valid)) begin
            // FFmpeg MPEG-PS can end without H.262 sequence_end_code.
            // Close the decoder only after the physical input and retained
            // output byte drain, so its final reordered reference can retire.
            if ((program_stream || APPEND_RAW_END) && video_seen && video_tail != 32'h000001b7) begin
                end_index <= 0;
                state <= END_CODE;
            end else state <= DONE;
        end
        END_CODE: if (output_ready) begin
            end_index <= end_index + 2'd1;
            if (end_index == 2'd3) state <= DONE;
        end
        default: state <= DONE;
        endcase
    end
end
endmodule
