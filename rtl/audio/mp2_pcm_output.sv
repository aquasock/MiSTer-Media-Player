// 48 kHz PCM sink in CLK_AUDIO domain. The one-shot origin arrives through a
// CDC FIFO; its 90 kHz clock shares the physical sample clock with video STC.
// Word layout {EOF, PTS_valid, PTS[32:0], left[15:0], right[15:0]}.
module mp2_pcm_output #(parameter ENABLE_PLAYBACK_CONTROL=0) (
    input wire clk,reset,
    input wire pause,seek,
    input wire [32:0] seek_target,
    input wire origin_valid,
    input wire [32:0] origin_pts,
    input wire [66:0] fifo_data,
    input wire fifo_empty,
    output wire fifo_rd,
    output wire signed [15:0] audio_l,audio_r,
    output reg underrun, timestamp_error, finished,
    output reg [31:0] samples_played
);
reg signed [15:0] sample_l,sample_r;
wire paused=ENABLE_PLAYBACK_CONTROL && pause;
wire seeking=ENABLE_PLAYBACK_CONTROL && seek;
reg seek_q,catchup;
reg [35:0] next_sample_q;
reg position_valid;
wire [35:0] sample_position_q=fifo_data[65]?{fifo_data[64:32],3'b0}:
 (position_valid?next_sample_q:{origin_pts+33'd9000,3'b0});
wire [35:0] sample_distance=sample_position_q-{seek_target,3'b0};
wire skipping=seeking||catchup;
wire skip_take=skipping && (eof || sample_distance[35]);
assign audio_l=(paused||skipping)?16'sd0:sample_l;
assign audio_r=(paused||skipping)?16'sd0:sample_r;
reg anchored,started;
reg [32:0] stc;
reg [24:0] tick_phase;
reg [8:0] sample_phase;
wire [25:0] tick_sum={1'b0,tick_phase}+26'd90000;
wire [32:0] lateness=stc-fifo_data[64:32];
wire eof=fifo_data[66];
wire has_pts=fifo_data[65];
wire due=anchored&&(!has_pts||!lateness[32]);
wire sample_tick=started&&sample_phase==9'd511;
wire take=!reset&&!finished&&!fifo_empty&&
    (skipping ? (anchored&&skip_take) :
     (!paused&&((!started&&(eof||due))||(sample_tick&&(eof||due)))));
assign fifo_rd=take;
always @(posedge clk) begin
    if(reset) begin
        seek_q<=0;catchup<=0;next_sample_q<=0;position_valid<=0;
        anchored<=0;started<=0;stc<=0;tick_phase<=0;sample_phase<=0;
        sample_l<=0;sample_r<=0;underrun<=0;timestamp_error<=0;finished<=0;samples_played<=0;
    end else begin
        seek_q<=seeking;
        if(seeking) catchup<=1;
        else if(catchup&&!fifo_empty&&!sample_distance[35]) catchup<=0;
        if(origin_valid&&!anchored) begin
            anchored<=1;stc<=origin_pts;tick_phase<=0;
            next_sample_q<={origin_pts+33'd9000,3'b0};position_valid<=1;
        end
        else if(anchored&&!paused&&!skipping) begin
            if(tick_sum>=26'd24576000) begin tick_phase<=tick_sum-26'd24576000;stc<=stc+33'd1;end
            else tick_phase<=tick_sum[24:0];
        end
        if(started&&!paused&&!skipping) sample_phase<=sample_phase+9'd1;
        if(ENABLE_PLAYBACK_CONTROL && seek_q && !seeking) begin
            stc<=seek_target;tick_phase<=0;sample_phase<=0;started<=0;
        end
        if(take) begin
            if(!eof) begin
                next_sample_q<=sample_position_q+36'd15;
                position_valid<=1;
            end
            if(eof) begin finished<=1;started<=0;sample_l<=0;sample_r<=0;end
            else if(!skipping) begin
                started<=1;sample_phase<=0;sample_l<=fifo_data[31:16];sample_r<=fifo_data[15:0];
                samples_played<=samples_played+32'd1;
                if(has_pts&&!lateness[32]&&lateness>33'd2) timestamp_error<=1;
            end
        end else if(sample_tick&&!paused&&!skipping) begin
            sample_l<=0;sample_r<=0;
            if(fifo_empty) underrun<=1;
        end
    end
end
endmodule
