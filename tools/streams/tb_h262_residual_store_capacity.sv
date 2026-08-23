`timescale 1ns/1ps

// Entry 347: prove the power-of-two residual bank mapping at the complete
// supported 720-pixel row capacity, independently of compressed stream shape.
module tb_h262_residual_store_capacity;
    localparam integer BLOCKS_PER_ROW=270;
    localparam integer SAMPLES_PER_ROW=BLOCKS_PER_ROW*64;

    reg clk=0;
    reg reset=1;
    reg residual_valid=0;
    reg [5:0] residual_index=0;
    reg signed [15:0] residual_value=0;
    wire residual_store_write;
    wire [15:0] residual_store_write_address;
    wire signed [15:0] residual_store_write_data;
    wire [15:0] residual_store_read_address;
    reg signed [15:0] residual_store_read_data=0;
    reg signed [15:0] residual_store [0:65535];
    wire active,error;
    wire [4:0] error_source;
    integer write_count=0;
    integer mb,block_index,sample_index;
    integer writes_before_overflow;
    integer expected_address;

    always #5 clk=~clk;

    always @(posedge clk) begin
        if(residual_store_write) begin
            expected_address=(write_count<SAMPLES_PER_ROW) ?
                write_count : 16'h8000+(write_count-SAMPLES_PER_ROW);
            if(residual_store_write_address!==expected_address[15:0])
                $fatal(1,"write %0d used address %0h, expected %0h",
                       write_count,residual_store_write_address,
                       expected_address[15:0]);
            residual_store[residual_store_write_address]
                <=residual_store_write_data;
            write_count<=write_count+1;
        end
        residual_store_read_data<=
            residual_store[residual_store_read_address];
    end

    task automatic send_word;
        input [5:0] word_index;
        input signed [15:0] word_value;
        begin
            @(negedge clk);
            residual_index<=word_index;
            residual_value<=word_value;
            residual_valid<=1;
            @(negedge clk);
            residual_valid<=0;
        end
    endtask

    task automatic send_row;
        input integer row_number;
        integer row_mb;
        integer row_block;
        integer row_sample;
        integer descriptor_number;
        begin
            for(row_mb=0;row_mb<45;row_mb=row_mb+1)
                send_word(6'h3e,16'sd0);
            descriptor_number=0;
            for(row_mb=0;row_mb<45;row_mb=row_mb+1) begin
                for(row_block=0;row_block<6;row_block=row_block+1) begin
                    send_word(6'h3c,$signed(row_number*45+row_mb));
                    send_word(6'h3d,$signed(row_block));
                    for(row_sample=0;row_sample<64;
                        row_sample=row_sample+1)
                        send_word(row_sample[5:0],
                                  $signed(row_number*10000+
                                          descriptor_number*64+row_sample));
                    descriptor_number=descriptor_number+1;
                end
            end
        end
    endtask

    mpeg2_h262_p_motion_residual_raster_engine dut(
        .clk(clk),.reset(reset),.capture_enable(1'b1),.request(1'b0),
        .horizontal_size(14'd720),.vertical_size(14'd480),
        .shift_right_map(48'd0),.residual_valid(residual_valid),
        .residual_index(residual_index),.residual_value(residual_value),
        .motion_vector_x(13'sd0),.motion_vector_y(13'sd0),
        .residual_store_write(residual_store_write),
        .residual_store_write_address(residual_store_write_address),
        .residual_store_write_data(residual_store_write_data),
        .residual_store_read_address(residual_store_read_address),
        .residual_store_read_data(residual_store_read_data),
        .reference_valid(1'b0),.reference_bank(2'd0),
        .destination_bank(2'd1),.store_block_stored(1'b0),
        .ddram_busy(1'b0),.ddram_dout(64'd0),.ddram_dout_ready(1'b0),
        .ddram_lookup_ready(1'b0),.ddram_lookup_hit(1'b0),
        .ddram_lookup_data(64'd0),.active(active),.error(error),
        .error_source(error_source)
    );

    initial begin
        repeat(5) @(posedge clk);
        @(negedge clk);
        reset<=0;

        send_row(0);
        if(dut.bank_desc_count[0]!==BLOCKS_PER_ROW)
            $fatal(1,"bank zero descriptor count %0d",
                   dut.bank_desc_count[0]);
        send_word(6'h3f,16'shA2FE);
        if(dut.capture_bank!==1'b1||dut.bank_ready[0]!==1'b1)
            $fatal(1,"bank zero did not retire into bank one capture");

        send_row(1);
        if(dut.bank_desc_count[1]!==BLOCKS_PER_ROW)
            $fatal(1,"bank one descriptor count %0d",
                   dut.bank_desc_count[1]);
        if(write_count!==(2*SAMPLES_PER_ROW))
            $fatal(1,"captured %0d residual samples, expected %0d",
                   write_count,2*SAMPLES_PER_ROW);
        if(residual_store[16'h0000]!==16'sd0||
           residual_store[16'h437f]!==16'sd17279||
           residual_store[16'h8000]!==16'sd10000||
           residual_store[16'hc37f]!==16'sd27279)
            $fatal(1,"first/last residual bank samples did not remain distinct");

        writes_before_overflow=write_count;
        send_word(6'h3c,16'sd90);
        if(!error||error_source!==5'd3)
            $fatal(1,"descriptor 271 was not rejected at the row bound");
        repeat(3) @(posedge clk);
        if(write_count!==writes_before_overflow)
            $fatal(1,"descriptor 271 caused a residual sample write");

        $display("PASS residual capacity blocks=%0d banks=2 writes=%0d last=%0h",
                 BLOCKS_PER_ROW,write_count,16'hc37f);
        $finish;
    end
endmodule
