// Additional native CD PLL; the existing movie/STC clock is never reclocked.
// Select/enable are held by the muted handoff controller. Consumers must
// acknowledge clock settling before releasing serializers or audible data.
module media_audio_clocks(
 input wire refclk,reset,movie_clock,select_cd,enable,
 output wire cd_clock,cd_locked,output_clock
);
 altera_pll #(
  .fractional_vco_multiplier("true"),.reference_clock_frequency("50.0 MHz"),
  .operation_mode("direct"),.number_of_clocks(1),
  .output_clock_frequency0("22.579200 MHz"),.phase_shift0("0 ps"),.duty_cycle0(50),
  .pll_type("General"),.pll_subtype("General")
 ) cd_pll(.refclk(refclk),.rst(reset),.outclk(cd_clock),.locked(cd_locked),.fboutclk(),.fbclk(1'b0));
 // Cyclone V clock-selector inputs 0/1 are clock pins; PLLs must use 2/3.
 altclkctrl #(.clock_type("Global Clock"),.number_of_clocks(4),.width_clkselect(2),
  .ena_register_mode("falling edge"),.use_glitch_free_switch_over_implementation("ON"))
 selector(.inclk({cd_clock,movie_clock,2'b00}),.clkselect({1'b1,select_cd}),.ena(enable),.outclk(output_clock));
endmodule
