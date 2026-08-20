`timescale 1ns/1ps

module tb_h262_hardware_cadence_profiler;
    reg clk_mpeg2=0,clk_video=0;
    always #5 clk_mpeg2=~clk_mpeg2;
    always #7 clk_video=~clk_video;

    reg reset_mpeg2=1,reset_video=1;
    reg fifo_pending=0,decoder_ready=1,presentation_hold=0;
    reg destination_hold=0,decoder_byte_accepted=0;
    reg [2:0] picture_coding_type=3'b001;
    reg [9:0] temporal_reference=0;
    reg [3:0] frame_rate_code=4'd3;
    reg [7:0] picture_count=0;
    reg reference_picture_complete=0,b_picture_complete=0;
    reg prediction_read=0,prediction_busy=1,prediction_data_ready=0;
    reg writer_write=0,writer_busy=1;
    reg display_frame_bank=0,display_scratch=0,display_scratch_bank=0;
    reg sequence_end_seen=0,session_quiet=0;
    reg [15:0] error_flags=0;
    reg [11:0] h_pos=0,v_pos=0;
    reg [7:0] base_r=8'h12,base_g=8'h34,base_b=8'h56;
    reg base_de=1;
    wire [7:0] video_r,video_g,video_b;
    wire snapshot_ready;
    integer i;
    reg [31:0] checksum;

    mpeg2_h262_hardware_cadence_profiler dut(
        .clk_mpeg2(clk_mpeg2),.reset_mpeg2(reset_mpeg2),
        .clk_video(clk_video),.reset_video(reset_video),
        .fifo_pending(fifo_pending),.decoder_ready(decoder_ready),
        .presentation_hold(presentation_hold),
        .destination_hold(destination_hold),
        .decoder_byte_accepted(decoder_byte_accepted),
        .picture_coding_type(picture_coding_type),
        .temporal_reference(temporal_reference),
        .frame_rate_code(frame_rate_code),.picture_count(picture_count),
        .reference_picture_complete(reference_picture_complete),
        .b_picture_complete(b_picture_complete),
        .prediction_read(prediction_read),.prediction_busy(prediction_busy),
        .prediction_data_ready(prediction_data_ready),
        .writer_write(writer_write),.writer_busy(writer_busy),
        .display_frame_bank(display_frame_bank),
        .display_scratch(display_scratch),
        .display_scratch_bank(display_scratch_bank),
        .sequence_end_seen(sequence_end_seen),.session_quiet(session_quiet),
        .error_flags(error_flags),.h_pos(h_pos),.v_pos(v_pos),
        .base_r(base_r),.base_g(base_g),.base_b(base_b),.base_de(base_de),
        .video_r(video_r),.video_g(video_g),.video_b(video_b),
        .snapshot_ready(snapshot_ready));

    task decoder_cycle;
        input accept;
        begin
            @(negedge clk_mpeg2);
            decoder_byte_accepted=accept;
            @(negedge clk_mpeg2);
            decoder_byte_accepted=0;
        end
    endtask

    task pulse_reference;
        begin
            @(negedge clk_mpeg2);reference_picture_complete=1;
            @(negedge clk_mpeg2);reference_picture_complete=0;
        end
    endtask

    task pulse_b;
        begin
            @(negedge clk_mpeg2);b_picture_complete=1;
            @(negedge clk_mpeg2);b_picture_complete=0;
        end
    endtask

    task sample_overlay;
        input [11:0] x;
        input [11:0] y;
        input expected_white;
        begin
            @(negedge clk_video);h_pos=x;v_pos=y;
            @(posedge clk_video);#1;
            if(expected_white)begin
                if({video_r,video_g,video_b}!==24'hffffff)
                    $fatal(1,"overlay expected white at %0d,%0d got %h/%h/%h",x,y,video_r,video_g,video_b);
            end else if({video_r,video_g,video_b}!==24'h000000)
                $fatal(1,"overlay expected black at %0d,%0d got %h/%h/%h",x,y,video_r,video_g,video_b);
        end
    endtask

    initial begin
        repeat(5)@(posedge clk_mpeg2);
        reset_mpeg2=0;
        repeat(5)@(posedge clk_video);
        reset_video=0;
        fifo_pending=1;

        for(i=0;i<8;i=i+1)decoder_cycle(1);
        decoder_ready=0;
        repeat(3)@(posedge clk_mpeg2);
        decoder_ready=1;
        picture_count=1;
        pulse_reference();

        picture_coding_type=3'b010;
        for(i=0;i<4;i=i+1)decoder_cycle(1);
        prediction_read=1;prediction_busy=1;
        repeat(2)@(posedge clk_mpeg2);
        prediction_busy=0;
        @(posedge clk_mpeg2);
        prediction_read=0;prediction_busy=1;
        repeat(4)@(posedge clk_mpeg2);
        prediction_data_ready=1;
        @(posedge clk_mpeg2);prediction_data_ready=0;

        picture_coding_type=3'b011;temporal_reference=1;
        pulse_b();
        @(negedge clk_mpeg2);display_scratch=1;
        repeat(3)@(posedge clk_mpeg2);
        temporal_reference=2;
        pulse_b();
        @(negedge clk_mpeg2);display_scratch_bank=1;
        repeat(3)@(posedge clk_mpeg2);

        picture_coding_type=3'b010;temporal_reference=3;picture_count=2;
        pulse_reference();
        @(negedge clk_mpeg2);display_scratch=0;display_frame_bank=1;
        writer_write=1;writer_busy=1;
        repeat(3)@(posedge clk_mpeg2);
        writer_write=0;

        sequence_end_seen=1;
        fifo_pending=0;
        session_quiet=1;
        wait(snapshot_ready);
        repeat(3)@(posedge clk_video);

        if(dut.snapshot_sync_2[31:0]!==32'h4d4d5031)
            $fatal(1,"bad snapshot magic %h",dut.snapshot_sync_2[31:0]);
        if(dut.snapshot_sync_2[63:32]!==32'h0115d2f0)
            $fatal(1,"bad snapshot format %h",dut.snapshot_sync_2[63:32]);
        if(dut.snapshot_sync_2[575:544]!==32'h02020403)
            $fatal(1,"bad picture counts %h",dut.snapshot_sync_2[575:544]);
        if(dut.snapshot_sync_2[223:192]==0)
            $fatal(1,"cadence span is zero");
        if(dut.snapshot_sync_2[639:608]!==0)
            $fatal(1,"unexpected error flags %h",dut.snapshot_sync_2[639:608]);

        checksum=0;
        for(i=0;i<20;i=i+1)
            checksum=checksum^dut.snapshot_sync_2[i*32+:32];
        if(checksum!==dut.snapshot_sync_2[671:640])
            $fatal(1,"checksum mismatch %h/%h",checksum,dut.snapshot_sync_2[671:640]);

        sample_overlay(12'd9,12'd513,1'b1);
        sample_overlay(12'd49,12'd513,1'b1);
        sample_overlay(12'd45,12'd513,1'b0);
        @(negedge clk_video);h_pos=12'd300;v_pos=12'd300;
        @(posedge clk_video);#1;
        if({video_r,video_g,video_b}!==24'h123456)
            $fatal(1,"base video changed outside overlay");

        $display("HARDWARE_CADENCE_PROFILER_PASS words=21 counts=%h cadence=%0d checksum=%h",
                 dut.snapshot_sync_2[575:544],dut.snapshot_sync_2[223:192],checksum);
        $finish;
    end

    initial begin
        repeat(10000)@(posedge clk_mpeg2);
        $fatal(1,"hardware cadence profiler timeout");
    end
endmodule
