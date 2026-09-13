`timescale 1ns/1ps
// Replay actual file bytes through the same ingress + metadata boundary as
// the core. Random readiness changes on every cycle catch output-byte loss;
// a second session in the same simulation checks all reset/EOF state.
module test_program_stream_ingress #(parameter APPEND_RAW_END=0);
reg clk=0, reset=1;
always #5 clk=~clk;
reg [7:0] input_data;
reg input_valid=0, input_end=0;
wire input_ready;
wire [7:0] ingress_data, output_data;
wire ingress_valid, ingress_ready, ingress_end, demux_error, output_valid;
reg output_ready=0;
wire metadata_valid;
mpeg2_program_stream_ingress #(.APPEND_RAW_END(APPEND_RAW_END)) dut (
    .clk(clk), .reset(reset), .input_data(input_data), .input_valid(input_valid),
    .input_ready(input_ready), .input_end(input_end),
    .output_data(ingress_data), .output_valid(ingress_valid),
    .output_ready(ingress_ready), .output_end(ingress_end), .demux_error(demux_error)
);
mpeg2_h262_inband_metadata metadata (
    .clk(clk), .reset(reset), .input_data(ingress_data),
    .input_valid(ingress_valid), .input_ready(ingress_ready), .input_end(ingress_end),
    .stream_data(output_data), .stream_valid(output_valid), .stream_ready(output_ready),
    .pts_90k(), .picture_structure(), .top_field_first(), .repeat_first_field(),
    .progressive_frame(), .metadata_valid(metadata_valid), .metadata_count()
);
reg [4095:0] input_path, expected_path;
integer source, expected, next_byte, want, count, cycles, idle, session;
reg [31:0] random_state=32'h1327ac91;
reg held=0, hold_input=0;
reg [7:0] held_data;
initial begin
    if (!$value$plusargs("INPUT=%s",input_path) ||
        !$value$plusargs("EXPECTED=%s",expected_path)) $fatal(1,"file arguments required");
    for (session=0;session<2;session=session+1) begin
        @(negedge clk); reset=1; input_valid=0; input_end=0; held=0; hold_input=0;
        repeat(5) @(negedge clk);
        reset=0;
        source=$fopen(input_path,"rb"); expected=$fopen(expected_path,"rb");
        if (!source || !expected) $fatal(1,"cannot open fixture");
        next_byte=$fgetc(source); count=0; cycles=0; idle=0;
        while(idle<100) begin
            @(negedge clk);
            random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
            output_ready=(session==0) || (random_state[3:0]<6 && cycles%4096<3900);
            input_valid=next_byte>=0 && (hold_input || session==0 || random_state[5:4]!=0);
            input_data=next_byte;
            input_end=next_byte<0;
            @(posedge clk);
            if (held && (!ingress_valid || ingress_data!==held_data))
                $fatal(1,"ingress changed a stalled byte");
            held=ingress_valid && !ingress_ready; held_data=ingress_data;
            hold_input=input_valid && !input_ready;
            if (input_valid && input_ready) next_byte=$fgetc(source);
            if (output_valid) begin
                if (!output_ready) $fatal(1,"decoder valid without readiness");
                want=$fgetc(expected);
                if (want<0 || output_data!==want[7:0])
                    $fatal(1,"byte %0d got %02x expected %02x",count,output_data,want);
                count=count+1;
            end
            if (demux_error) $fatal(1,"unexpected demux error");
            if (metadata_valid) $fatal(1,"ordinary media generated private metadata");
            if (ingress_end && !output_valid) idle=idle+1; else idle=0;
            cycles=cycles+1;
            if (cycles>100000000) $fatal(1,"replay timeout");
        end
        if ($fgetc(expected)>=0) $fatal(1,"missing output bytes");
        $fclose(source); $fclose(expected);
        $display("PASS session=%0d bytes=%0d cycles=%0d",session,count,cycles);
    end
    $finish;
end
endmodule
