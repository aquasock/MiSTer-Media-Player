# MPEG2FPGA

This directory contains MPEG-2 decoder RTL derived from:

https://github.com/OldRepoPreservation/mpeg2fpga

Development/testing fork used during MiSTer-Media-Player development:

https://github.com/aquasock/mpeg2fpga

The original decoder RTL is located under `mpeg2/`.

The `compat/` directory contains generic FIFO and dual-port RAM wrappers
required to synthesize the decoder with Quartus Prime 17 for the Cyclone V
device used by MiSTer.

Do not make MiSTer-specific changes directly to the imported decoder unless
necessary. MiSTer integration logic should live outside this directory where
practical.

Imported from aquasock/mpeg2fpga commit: 1432159a37036feec257ea2ce6cbae1f13c98b64
