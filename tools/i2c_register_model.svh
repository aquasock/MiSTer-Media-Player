// Testbench-only byte-register I2C slave; shared by native audio bus tests.
 reg[7:0] registers[0:255];reg[7:0] shift=0,pointer=0,read_shift=0;
 integer bits=0,phase=0,starts=0,stops=0,writes=0,k;
 reg bus_active=0,reading=0;
 // Independent bit-level I2C register device model, including repeated START.
 always @(negedge pad_sda)if(pad_scl&&!reset)begin bus_active=1;reading=0;bits=0;phase=0;shift=0;starts=starts+1;end
 always @(posedge pad_sda)if(pad_scl&&!reset)begin bus_active=0;slave_sda_low=0;stops=stops+1;end
 always @(posedge pad_scl)if(bus_active&&!reset)begin
  if(bits<8)begin shift={shift[6:0],pad_sda};bits=bits+1;end
  else begin
   if(reading)begin if(!pad_sda)$fatal(1,"master did not NACK final read byte");reading=0;end
   else if(!nack)case(phase)
    0:begin
     if(shift!=8'h72&&shift!=8'h73)$fatal(1,"wrong I2C device %h",shift);
     reading=shift[0];phase=1;
     if(reading)read_shift=registers[pointer]^((bad_readback&&readback_pass)?8'h01:8'h00);
    end
    1:begin pointer=shift;phase=2;end
    2:begin registers[pointer]=shift;pointer=pointer+1'b1;writes=writes+1;end
    default:$fatal(1,"slave phase");
   endcase
   bits=0;shift=0;
  end
 end
 always @(negedge pad_scl)if(bus_active&&!reset)begin
  if(bits==8)slave_sda_low=!reading&&!nack;
  else if(reading)slave_sda_low=!read_shift[7-bits];
  else slave_sda_low=0;
 end
