// 48 kHz PCM sink in CLK_AUDIO domain. The one-shot origin arrives through a
// CDC FIFO; its 90 kHz clock shares the physical sample clock with video STC.
// Word layout {EOF, PTS_valid, PTS[32:0], left[15:0], right[15:0]}.
module mp2_pcm_output (
    input wire clk,reset,
    input wire origin_valid,
    input wire [32:0] origin_pts,
    input wire [66:0] fifo_data,
    input wire fifo_empty,
    output wire fifo_rd,
    output reg signed [15:0] audio_l,audio_r,
    output reg underrun, timestamp_error, finished,
    output reg [31:0] samples_played
);
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
    ((!started&&(eof||due))||(sample_tick&&(eof||due)));
assign fifo_rd=take;
always @(posedge clk) begin
    if(reset) begin
        anchored<=0;started<=0;stc<=0;tick_phase<=0;sample_phase<=0;
        audio_l<=0;audio_r<=0;underrun<=0;timestamp_error<=0;finished<=0;samples_played<=0;
    end else begin
        if(origin_valid&&!anchored) begin anchored<=1;stc<=origin_pts;tick_phase<=0;end
        else if(anchored) begin
            if(tick_sum>=26'd24576000) begin tick_phase<=tick_sum-26'd24576000;stc<=stc+33'd1;end
            else tick_phase<=tick_sum[24:0];
        end
        if(started) sample_phase<=sample_phase+9'd1;
        if(take) begin
            if(eof) begin finished<=1;started<=0;audio_l<=0;audio_r<=0;end
            else begin
                started<=1;sample_phase<=0;audio_l<=fifo_data[31:16];audio_r<=fifo_data[15:0];
                samples_played<=samples_played+32'd1;
                if(has_pts&&!lateness[32]&&lateness>33'd2) timestamp_error<=1;
            end
        end else if(sample_tick) begin
            audio_l<=0;audio_r<=0;
            if(fifo_empty) underrun<=1;
        end
    end
end
endmodule
