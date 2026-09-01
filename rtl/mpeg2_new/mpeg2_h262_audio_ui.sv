// Audio-only ARM-rendered framebuffer uploader. A complete planar 720x480
// Y/Cb/Cr 4:2:0 frame occupies 64,800 DDR words. Writes always target the
// inactive one of frame regions zero and one; COMMIT merely arms publication,
// and the bank changes only at the established safe frame-window pulse.
module mpeg2_h262_audio_ui
(
    input  wire        clk,
    input  wire        reset,
    input  wire  [7:0] record_data,
    input  wire        record_start,
    input  wire        record_last,
    input  wire        record_valid,
    output wire        record_ready,
    output reg         protocol_error,

    output wire  [7:0] writer_burstcnt,
    output wire [28:0] writer_addr,
    output wire        writer_rd,
    output wire [63:0] writer_din,
    output wire  [7:0] writer_be,
    output wire        writer_we,
    input  wire        writer_busy,

    input  wire        publish_window,
    output reg         mode_active,
    output reg         loading_active,
    output reg         display_bank,
    output reg         picture_publish,
    output reg  [15:0] committed_frames
);

localparam [7:0] COMMAND_BEGIN=8'h10,
                 COMMAND_DATA=8'h11,
                 COMMAND_COMMIT=8'h12;
localparam [28:0] FRAME_BASE=29'h06000000;
localparam [28:0] FRAME_BANK_WORDS=29'h00010000;
localparam [19:0] FRAME_BYTES=20'd518400;
localparam [15:0] FRAME_WORDS=16'd64800;

reg [7:0] current_command;
reg [19:0] received_bytes;
reg [15:0] write_word_index;
reg [2:0] write_byte_lane;
reg [63:0] write_word;
reg write_pending;
reg commit_pending;
reg frame_open;

wire writer_accept=write_pending&&!writer_busy;
assign record_ready=!write_pending;
assign writer_burstcnt=write_pending?8'd1:8'd0;
assign writer_addr=FRAME_BASE+
    (display_bank?29'd0:FRAME_BANK_WORDS)+{13'd0,write_word_index};
assign writer_rd=1'b0;
assign writer_din=write_word;
assign writer_be=8'hff;
assign writer_we=write_pending;

always @(posedge clk) begin
    if(reset)begin
        current_command<=COMMAND_BEGIN;
        received_bytes<=0;write_word_index<=0;write_byte_lane<=0;
        write_word<=0;write_pending<=0;commit_pending<=0;frame_open<=0;
        protocol_error<=0;mode_active<=0;loading_active<=0;
        display_bank<=0;picture_publish<=0;committed_frames<=0;
    end else begin
        picture_publish<=1'b0;
        if(writer_accept)begin
            write_pending<=1'b0;
            write_word_index<=write_word_index+1'b1;
        end

        if(commit_pending&&publish_window)begin
            commit_pending<=1'b0;
            display_bank<=~display_bank;
            mode_active<=1'b1;
            loading_active<=1'b0;
            picture_publish<=1'b1;
            if(committed_frames!=16'hffff)
                committed_frames<=committed_frames+1'b1;
        end

        if(record_valid&&record_ready)begin
            if(record_start)begin
                current_command<=record_data;
                case(record_data)
                    COMMAND_BEGIN:begin
                        if(!record_last||commit_pending||frame_open)begin
                            protocol_error<=1'b1;
                        end else begin
                            received_bytes<=0;write_word_index<=0;
                            write_byte_lane<=0;write_word<=0;
                            frame_open<=1'b1;loading_active<=1'b1;
                        end
                    end
                    COMMAND_DATA:begin
                        if(record_last||!frame_open||commit_pending)
                            protocol_error<=1'b1;
                    end
                    COMMAND_COMMIT:begin
                        if(!record_last||!frame_open||commit_pending||
                           received_bytes!=FRAME_BYTES||
                           write_byte_lane!=0||write_pending||
                           write_word_index!=FRAME_WORDS)begin
                            protocol_error<=1'b1;
                        end else begin
                            commit_pending<=1'b1;
                            frame_open<=1'b0;
                        end
                    end
                    default:protocol_error<=1'b1;
                endcase
            end else if(current_command==COMMAND_DATA)begin
                if(!frame_open||received_bytes==FRAME_BYTES)begin
                    protocol_error<=1'b1;
                end else begin
                    write_word[write_byte_lane*8+:8]<=record_data;
                    received_bytes<=received_bytes+1'b1;
                    if(write_byte_lane==3'd7)begin
                        write_pending<=1'b1;
                        write_byte_lane<=0;
                    end else begin
                        write_byte_lane<=write_byte_lane+1'b1;
                    end
                end
            end else begin
                protocol_error<=1'b1;
            end
        end
    end
end

endmodule
