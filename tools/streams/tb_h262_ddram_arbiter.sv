`timescale 1ns/1ps

`ifndef H262_PREDICTION_DESCRIPTOR_DEPTH
`define H262_PREDICTION_DESCRIPTOR_DEPTH 2
`endif

module tb_h262_ddram_arbiter;
    localparam integer EXPECTED_DEPTH=`H262_PREDICTION_DESCRIPTOR_DEPTH;
    reg clk=0,reset=1;

    reg [7:0] writer_burstcnt=1;
    reg [28:0] writer_addr=0;
    reg writer_rd=0;
    reg [63:0] writer_din=64'h0123456789ABCDEF;
    reg [7:0] writer_be=8'hFF;
    reg writer_we=0;
    wire writer_busy;

    reg [7:0] reader_burstcnt=1;
    reg [28:0] reader_addr=0;
    reg reader_rd=0;
    wire reader_busy,reader_dout_ready;

    reg [7:0] prediction_burstcnt=1;
    reg [28:0] prediction_addr=0;
    reg prediction_rd=0;
    wire prediction_busy,prediction_dout_ready;

    reg ddram_busy=0,ddram_dout_ready=0;
    wire [7:0] ddram_burstcnt;
    wire [28:0] ddram_addr;
    wire ddram_rd;
    wire [63:0] ddram_din;
    wire [7:0] ddram_be;
    wire ddram_we;

    integer max_descriptors=0;
    integer routed_prediction=0,routed_reader=0;
    integer test_index;

    always #5 clk=~clk;

    mpeg2_h262_ddram_arbiter dut(
        .clk(clk),.reset(reset),
        .writer_burstcnt(writer_burstcnt),.writer_addr(writer_addr),
        .writer_rd(writer_rd),.writer_din(writer_din),
        .writer_be(writer_be),.writer_we(writer_we),
        .writer_busy(writer_busy),
        .reader_burstcnt(reader_burstcnt),.reader_addr(reader_addr),
        .reader_rd(reader_rd),.reader_busy(reader_busy),
        .reader_dout_ready(reader_dout_ready),
        .prediction_burstcnt(prediction_burstcnt),
        .prediction_addr(prediction_addr),.prediction_rd(prediction_rd),
        .prediction_busy(prediction_busy),
        .prediction_dout_ready(prediction_dout_ready),
        .ddram_busy(ddram_busy),.ddram_dout_ready(ddram_dout_ready),
        .ddram_burstcnt(ddram_burstcnt),.ddram_addr(ddram_addr),
        .ddram_rd(ddram_rd),.ddram_din(ddram_din),
        .ddram_be(ddram_be),.ddram_we(ddram_we));

    always @(posedge clk) begin
        if(dut.read_descriptor_count>max_descriptors)
            max_descriptors<=dut.read_descriptor_count;
        if(reader_dout_ready)routed_reader<=routed_reader+1;
        if(prediction_dout_ready)
            routed_prediction<=routed_prediction+1;
        if(reader_dout_ready&&prediction_dout_ready)
            $fatal(1,"one DDR response routed to both read clients");
    end

    task automatic accept_prediction;
        input [28:0] addr;
        integer guard;
        begin
            @(negedge clk);
            prediction_addr=addr;
            prediction_burstcnt=1;
            prediction_rd=1;
            #1;
            guard=0;
            while(prediction_busy)begin
                @(negedge clk); #1;
                guard=guard+1;
                if(guard>30)$fatal(1,"prediction acceptance timeout");
            end
            if(!ddram_rd||(ddram_addr!=addr))
                $fatal(1,"wrong prediction command routing");
            @(posedge clk);
            @(negedge clk);
            prediction_rd=0;
        end
    endtask

    task automatic accept_reader;
        input [28:0] addr;
        input [7:0] words;
        integer guard;
        begin
            @(negedge clk);
            reader_addr=addr;
            reader_burstcnt=words;
            reader_rd=1;
            #1;
            guard=0;
            while(reader_busy)begin
                @(negedge clk); #1;
                guard=guard+1;
                if(guard>30)$fatal(1,"reader acceptance timeout");
            end
            if(!ddram_rd||(ddram_addr!=addr)||
               (ddram_burstcnt!=words))
                $fatal(1,"wrong display command routing");
            @(posedge clk);
            @(negedge clk);
            reader_rd=0;
        end
    endtask

    task automatic return_word;
        input expect_prediction;
        begin
            @(negedge clk);
            ddram_dout_ready=1;
            #1;
            if(expect_prediction)begin
                if(!prediction_dout_ready||reader_dout_ready)
                    $fatal(1,"response was not routed to prediction");
            end else begin
                if(!reader_dout_ready||prediction_dout_ready)
                    $fatal(1,"response was not routed to display");
            end
            @(posedge clk);
            @(negedge clk);
            ddram_dout_ready=0;
        end
    endtask

    initial begin
        repeat(4)@(posedge clk);
        reset=0;
        #1;
        if(reader_busy||prediction_busy)
            $fatal(1,"arbiter did not advertise idle read readiness");

        // Queue owner order P/D/P.  Display wins the second command slot, then
        // the first prediction response frees a descriptor on the same edge
        // that the held prediction successor is accepted.
        accept_prediction(29'h00100);
        @(negedge clk);
        reader_addr=29'h10100;
        reader_burstcnt=1;
        reader_rd=1;
        prediction_addr=29'h00101;
        prediction_burstcnt=1;
        prediction_rd=1;
        #1;
        if(reader_busy||!prediction_busy||!ddram_rd||
           (ddram_addr!=reader_addr))
            $fatal(1,"display did not win simultaneous arbitration");
        @(posedge clk);
        @(negedge clk);
        reader_rd=0;
        #1;
        if((dut.read_descriptor_count!=2)||
           ((EXPECTED_DEPTH==2)&&!prediction_busy)||
           ((EXPECTED_DEPTH>2)&&prediction_busy))
            $fatal(1,"configured descriptor readiness failed depth=%0d busy=%0d count=%0d",
                   EXPECTED_DEPTH,prediction_busy,
                   dut.read_descriptor_count);

        ddram_dout_ready=1;
        #1;
        if(!prediction_dout_ready||prediction_busy||
           !ddram_rd||(ddram_addr!=prediction_addr))
            $fatal(1,"same-cycle response/accept boundary failed");
        @(posedge clk);
        @(negedge clk);
        ddram_dout_ready=0;
        prediction_rd=0;
        if((dut.read_descriptor_count!=2)||
           dut.read_descriptor_owner[dut.read_descriptor_head]!==1'b0)
            $fatal(1,"display descriptor did not remain at queue head");
        return_word(1'b0);
        return_word(1'b1);
        if(dut.read_descriptor_count!=0)
            $fatal(1,"P/D/P sequence did not drain");

        // Fill the configured capacity, then retire the head response on the
        // same edge that a held successor enters the newly freed tail slot.
        for(test_index=0;test_index<EXPECTED_DEPTH;
            test_index=test_index+1)
            accept_prediction(29'h01000+test_index);
        if((dut.read_descriptor_count!=EXPECTED_DEPTH)||!prediction_busy)
            $fatal(1,"arbiter did not reach configured capacity depth=%0d count=%0d busy=%0d",
                   EXPECTED_DEPTH,dut.read_descriptor_count,prediction_busy);
        @(negedge clk);
        prediction_addr=29'h01100;
        prediction_burstcnt=1;
        prediction_rd=1;
        ddram_dout_ready=1;
        #1;
        if(!prediction_dout_ready||prediction_busy||!ddram_rd||
           (ddram_addr!=prediction_addr))
            $fatal(1,"full-queue response/accept reuse failed");
        @(posedge clk);
        @(negedge clk);
        prediction_rd=0;
        ddram_dout_ready=0;
        if(dut.read_descriptor_count!=EXPECTED_DEPTH)
            $fatal(1,"full-queue reuse changed occupancy");
        for(test_index=0;test_index<EXPECTED_DEPTH;
            test_index=test_index+1)
            return_word(1'b1);
        if(dut.read_descriptor_count!=0)
            $fatal(1,"configured descriptor queue did not drain");

        // A multiword display burst owns every response until its final word;
        // a queued prediction response follows it without misrouting.
        accept_reader(29'h20020,8'd3);
        accept_prediction(29'h00020);
        return_word(1'b0);
        if(dut.read_words_remaining!=2)
            $fatal(1,"display burst remaining count failed after word one");
        return_word(1'b0);
        if(dut.read_words_remaining!=1)
            $fatal(1,"display burst remaining count failed after word two");
        return_word(1'b0);
        return_word(1'b1);

        // An empty queue can accept and route a legal same-cycle response
        // without leaving a stale descriptor behind.
        @(negedge clk);
        reader_addr=29'h30030;
        reader_burstcnt=1;
        reader_rd=1;
        ddram_dout_ready=1;
        #1;
        if(reader_busy||!reader_dout_ready||prediction_dout_ready)
            $fatal(1,"direct display response routing failed");
        @(posedge clk);
        @(negedge clk);
        reader_rd=0;
        ddram_dout_ready=0;
        if(dut.read_descriptor_count!=0)
            $fatal(1,"direct response left a descriptor");

        // Writes remain blocked by reads and by the display-owned frame
        // region, but a different region is accepted after the queue drains.
        accept_prediction(29'h00040);
        @(negedge clk);
        writer_addr=29'h30040;
        writer_we=1;
        #1;
        if(!writer_busy||ddram_we)
            $fatal(1,"writer was admitted while a read was outstanding");
        writer_we=0;
        return_word(1'b1);
        @(negedge clk);
        writer_addr=29'h30040;
        writer_we=1;
        #1;
        if(!writer_busy||ddram_we)
            $fatal(1,"writer entered the display-owned frame region");
        writer_addr=29'h00040;
        #1;
        if(writer_busy||!ddram_we||(ddram_addr!=writer_addr)||
           (ddram_din!=writer_din)||(ddram_be!=writer_be))
            $fatal(1,"safe writer region was not admitted");
        @(posedge clk);
        @(negedge clk);
        writer_we=0;

        if(max_descriptors!=EXPECTED_DEPTH)
            $fatal(1,"arbiter descriptor depth coverage failed max=%0d",
                   max_descriptors);
        if((routed_prediction!=(5+EXPECTED_DEPTH))||(routed_reader!=5))
            $fatal(1,"response route totals failed prediction=%0d reader=%0d",
                   routed_prediction,routed_reader);

        $display("DDRAM_ARBITER_RESULT depth=%0d owner_order=P/D/P display_burst=3 prediction_responses=%0d display_responses=%0d same_cycle_reuse=1 direct_response=1 writer_exclusion=1",
                 max_descriptors,routed_prediction,routed_reader);
        $finish;
    end

    initial begin
        repeat(1000)@(posedge clk);
        $fatal(1,"DDR arbiter timed out");
    end
endmodule
