# Entry 687 diagnostic reproduction record

These are the exact one-off scripts and commands used for the approved entry
686 investigation. They ran on the build PC against unchanged production source
83c138e. `entry686_setup_sim.py` generates isolated copies of the existing native
testbench and adds the production extractor, clean-video queue, audio FIFO and
audio adapter. The original production and testbench files are not edited.

The scripts contain the recorded build-PC paths. Before rerunning, choose a new
work directory and adjust those paths; do not overwrite the retained evidence.
The local selected VOB opening and earlier pixel-oracle fixture are intentionally
not published. Their paths and source hashes are retained in the report.

The simulated source is ideal or uniformly rate capped, not recorded Main/SPI
traffic. The existing behavioral vendor FIFO models omit CDC delays; DDR uses
the native testbench's ideal response model. The 3.0-second passthrough and
2.1-second decoded-audio cases are bounded reproductions, not full-movie passes.
The second case changes both payload and source rate and is a sensitivity case,
not a one-variable codec comparison or replay of the accepted HDMI hardware run.

`entry686_compare.py` includes a deliberately rough host-log diagnostic column
that assumes a 30 ms audio start (`carrier_minus_time_samples`). This is not a
measured FIFO occupancy or proof of a hardware deficit. The diagnosis relies on
the integrated FIFO trace, not that exploratory column.

`entry686_horizon.py` adds log-only instrumentation to a temporary helper copy
and verifies its complete output against the uninstrumented transport. No helper
behavior, media bytes, FIFO capacity, or FPGA production logic is changed.
