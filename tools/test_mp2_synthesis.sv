module test_mp2_synthesis;
reg clk=0; always #5 clk=~clk;
reg reset=1,wr=0,start=0,ready=0;
reg [7:0] addr; reg signed [23:0] data;
wire busy,done,valid; wire signed [15:0] l,r;
mp2_synthesis dut(clk,reset,wr,addr,data,start,busy,done,valid,ready,l,r);
integer fd,outfd,rc,i,n=0,cycles=0,blocks; reg [23:0] value;
reg [1023:0] path;
always @(posedge clk) begin
    cycles<=cycles+1;
    if(cycles>20000000) $fatal(1,"timeout");
    if(valid&&ready) begin $fwrite(outfd,"%d %d\n",l,r); n<=n+1; end
end
initial begin
    if(!$value$plusargs("input=%s",path)) $fatal;
    fd=$fopen(path,"r"); outfd=$fopen("/tmp/mp2-synth-rtl.txt","w");
    repeat(5) @(negedge clk); reset=0;
    wait(!busy);
    while(!$feof(fd)) begin
        for(i=0;i<192;i=i+1) begin
            rc=$fscanf(fd,"%h\n",value);
            if(rc!=1) $fatal;
            @(negedge clk); wr=1; addr=i; data=value;
        end
        @(negedge clk); wr=0; start=1;
        @(negedge clk); start=0;
        while(!done) begin @(negedge clk); ready=($urandom_range(0,7)!=0); end
    end
    @(negedge clk); $display("samples %0d cycles %0d",n,cycles); $fclose(outfd); $finish;
end
endmodule
