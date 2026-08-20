`timescale 1ns/1ps

module tb_h262_prediction_block_fetcher;
    reg clk=0,reset=1,start=0;
    reg [1:0] phase_count=0;
    reg [28:0] phase0_base_addr=0,phase1_base_addr=0;
    reg phase0_two_words=0,phase1_two_words=0;
    reg [3:0] phase0_rows=0,phase1_rows=0;
    reg [6:0] row_words=0;

    reg zero_latency=0,inject_backpressure=0;
    integer service_cycle=0;
    wire memory_busy=inject_backpressure&&
        (((service_cycle%11)==2)||((service_cycle%11)==3));
    wire [28:0] memory_addr;
    wire memory_rd;
    reg delayed_dout_ready=0;
    reg [63:0] delayed_dout=0;
    reg [15:0] response_valid_pipe=0;
    reg [28:0] response_addr_pipe[0:15];
    integer response_stage;
    wire memory_dout_ready=zero_latency?
        (memory_rd&&!memory_busy):delayed_dout_ready;
    wire [63:0] memory_dout=zero_latency?
        word_for(memory_addr):delayed_dout;

    reg lookup_request=0,lookup_phase=0,lookup_column=0;
    reg [3:0] lookup_row=0;
    wire lookup_ready,lookup_valid;
    wire [63:0] lookup_data;
    wire active,complete,error;
    wire [6:0] issued_count,returned_count;
    wire [1:0] outstanding_count;

    reg [28:0] expected_addr[0:35];
    integer expected_count=0,accepted_count=0,response_count=0;
    integer model_outstanding=0,max_outstanding=0;
    integer simultaneous_accept_response=0;
    integer test_index,test_row,test_column;

    always #5 clk=~clk;

    function automatic [63:0] word_for;
        input [28:0] addr;
        begin
            word_for={6'd0,addr,addr};
        end
    endfunction

    mpeg2_h262_prediction_block_fetcher dut(
        .clk(clk),.reset(reset),.start(start),
        .phase_count(phase_count),
        .phase0_base_addr(phase0_base_addr),
        .phase1_base_addr(phase1_base_addr),
        .phase0_two_words(phase0_two_words),
        .phase1_two_words(phase1_two_words),
        .phase0_rows(phase0_rows),.phase1_rows(phase1_rows),
        .row_words(row_words),.memory_busy(memory_busy),
        .memory_dout(memory_dout),.memory_dout_ready(memory_dout_ready),
        .memory_addr(memory_addr),.memory_rd(memory_rd),
        .lookup_request(lookup_request),.lookup_phase(lookup_phase),
        .lookup_row(lookup_row),.lookup_column(lookup_column),
        .lookup_ready(lookup_ready),.lookup_valid(lookup_valid),
        .lookup_data(lookup_data),.active(active),.complete(complete),
        .error(error),.issued_count(issued_count),
        .returned_count(returned_count),
        .outstanding_count(outstanding_count));

    always @(posedge clk) begin
        service_cycle=service_cycle+1;
        delayed_dout_ready<=response_valid_pipe[9];
        if(response_valid_pipe[9])
            delayed_dout<=word_for(response_addr_pipe[9]);
        for(response_stage=15;response_stage>0;
            response_stage=response_stage-1)begin
            response_valid_pipe[response_stage]<=
                response_valid_pipe[response_stage-1];
            response_addr_pipe[response_stage]<=
                response_addr_pipe[response_stage-1];
        end
        response_valid_pipe[0]<=memory_rd&&!memory_busy&&!zero_latency;
        if(memory_rd&&!memory_busy&&!zero_latency)
            response_addr_pipe[0]<=memory_addr;
        if(zero_latency)begin
            response_valid_pipe<=0;
            delayed_dout_ready<=0;
        end

        if(memory_rd&&!memory_busy)begin
            if(accepted_count>=expected_count)
                $fatal(1,"unexpected address %h",memory_addr);
            if(memory_addr!==expected_addr[accepted_count])
                $fatal(1,"address order failed index=%0d got=%h expected=%h",
                       accepted_count,memory_addr,
                       expected_addr[accepted_count]);
            accepted_count=accepted_count+1;
        end
        if(memory_dout_ready)
            response_count=response_count+1;
        if(memory_rd&&!memory_busy&&memory_dout_ready)
            simultaneous_accept_response=simultaneous_accept_response+1;

        case({memory_rd&&!memory_busy,memory_dout_ready})
            2'b10:model_outstanding=model_outstanding+1;
            2'b01:model_outstanding=model_outstanding-1;
            default:model_outstanding=model_outstanding;
        endcase
        if(model_outstanding>max_outstanding)
            max_outstanding=model_outstanding;
        if(model_outstanding<0||model_outstanding>2)
            $fatal(1,"outstanding bound failed count=%0d",
                   model_outstanding);
    end

    task automatic prepare_expected;
        input [28:0] base0;
        input integer width0;
        input integer rows0;
        input [28:0] base1;
        input integer width1;
        input integer rows1;
        input integer phases;
        input integer stride;
        integer r,c,n;
        begin
            n=0;
            for(r=0;r<rows0;r=r+1)
                for(c=0;c<width0;c=c+1)begin
                    expected_addr[n]=base0+r*stride+c;
                    n=n+1;
                end
            if(phases==2)
                for(r=0;r<rows1;r=r+1)
                    for(c=0;c<width1;c=c+1)begin
                        expected_addr[n]=base1+r*stride+c;
                        n=n+1;
                    end
            expected_count=n;
            accepted_count=0;
            response_count=0;
            model_outstanding=0;
            max_outstanding=0;
            simultaneous_accept_response=0;
        end
    endtask

    task automatic launch;
        input integer phases;
        input [28:0] base0;
        input integer width0;
        input integer rows0;
        input [28:0] base1;
        input integer width1;
        input integer rows1;
        input integer stride;
        integer guard;
        begin
            prepare_expected(base0,width0,rows0,base1,width1,rows1,
                             phases,stride);
            @(negedge clk);
            phase_count=phases;
            phase0_base_addr=base0;
            phase1_base_addr=base1;
            phase0_two_words=(width0==2);
            phase1_two_words=(width1==2);
            phase0_rows=rows0;
            phase1_rows=rows1;
            row_words=stride;
            start=1;
            @(negedge clk);
            start=0;
            guard=0;
            while(!complete&&!error)begin
                @(negedge clk);
                guard=guard+1;
                if(guard>2000)$fatal(1,"fetch timeout");
            end
            if(error)$fatal(1,"fetcher asserted error");
            if(active||outstanding_count!=0||model_outstanding!=0||
               accepted_count!=expected_count||
               response_count!=expected_count||
               issued_count!=expected_count||
               returned_count!=expected_count)
                $fatal(1,"fetch accounting failed active=%0d outstanding=%0d/%0d accepted=%0d responses=%0d issued=%0d returned=%0d expected=%0d",
                       active,outstanding_count,model_outstanding,
                       accepted_count,response_count,issued_count,
                       returned_count,expected_count);
        end
    endtask

    task automatic check_lookup;
        input phase;
        input integer row_index;
        input integer column_index;
        input [28:0] expected_address;
        begin
            @(negedge clk);
            lookup_phase=phase;
            lookup_row=row_index;
            lookup_column=column_index;
            lookup_request=1;
            @(negedge clk);
            if(!lookup_ready||!lookup_valid||
               lookup_data!==word_for(expected_address))
                $fatal(1,"lookup failed phase=%0d row=%0d col=%0d got=%h expected=%h ready=%0d valid=%0d",
                       phase,row_index,column_index,lookup_data,
                       word_for(expected_address),lookup_ready,lookup_valid);
            lookup_request=0;
        end
    endtask

    task automatic check_invalid_lookup;
        begin
            @(negedge clk);
            lookup_phase=1;
            lookup_row=0;
            lookup_column=0;
            lookup_request=1;
            @(negedge clk);
            if(!lookup_ready||lookup_valid)
                $fatal(1,"invalid lookup was accepted");
            lookup_request=0;
        end
    endtask

    initial begin
        repeat(4)@(posedge clk);
        reset=0;

        launch(1,29'h06000007,1,8,29'd0,1,1,90);
        for(test_row=0;test_row<8;test_row=test_row+1)
            check_lookup(0,test_row,0,29'h06000007+test_row*90);
        check_invalid_lookup();

        inject_backpressure=1;
        launch(1,29'h0600a8c1,2,9,29'd0,1,1,45);
        if(max_outstanding!=2||simultaneous_accept_response==0)
            $fatal(1,"delayed service did not cover simultaneous response/accept depth=%0d simultaneous=%0d",
                   max_outstanding,simultaneous_accept_response);
        for(test_row=0;test_row<9;test_row=test_row+1)
            for(test_column=0;test_column<2;test_column=test_column+1)
                check_lookup(0,test_row,test_column,
                    29'h0600a8c1+test_row*45+test_column);
        inject_backpressure=0;

        launch(2,29'h0601000e,2,9,29'h06020011,2,9,90);
        if(max_outstanding!=2)
            $fatal(1,"dual rectangle did not reach depth two");
        for(test_index=0;test_index<2;test_index=test_index+1)
            for(test_row=0;test_row<9;test_row=test_row+1)
                for(test_column=0;test_column<2;
                    test_column=test_column+1)
                    check_lookup(test_index,test_row,test_column,
                        (test_index?29'h06020011:29'h0601000e)+
                        test_row*90+test_column);

        zero_latency=1;
        launch(2,29'h0600d2f2,1,8,29'h0601d2f4,2,9,45);
        for(test_row=0;test_row<8;test_row=test_row+1)
            check_lookup(0,test_row,0,29'h0600d2f2+test_row*45);
        for(test_row=0;test_row<9;test_row=test_row+1)
            for(test_column=0;test_column<2;test_column=test_column+1)
                check_lookup(1,test_row,test_column,
                    29'h0601d2f4+test_row*45+test_column);
        zero_latency=0;

        @(negedge clk);
        phase_count=0;
        phase0_rows=8;
        phase1_rows=8;
        row_words=90;
        start=1;
        @(negedge clk);
        start=0;
        if(!error||active||complete)
            $fatal(1,"invalid phase count was not rejected");

        $display("PREDICTION_BLOCK_FETCHER_RESULT transactions=4 phases=6 words=88 depth=2 delayed=1 backpressure=1 simultaneous=1 zero_latency=1 invalid=1");
        $finish;
    end
endmodule
