# Removed MPEG2FPGA reference implementation

The project's early decoder integration used RTL from
[OldRepoPreservation/mpeg2fpga](https://github.com/OldRepoPreservation/mpeg2fpga)
through the [aquasock development fork](https://github.com/aquasock/mpeg2fpga),
imported at commit `1432159a37036feec257ea2ce6cbae1f13c98b64`.

It was excluded from the active Quartus design long before this cleanup. Gate
two removes `rtl/mpeg2fpga/` and the unused `rtl/mpeg2_decoder.sv` and
`rtl/mpeg2_ddram_bridge.sv` integration wrappers. Their source, comments and
notices remain recoverable in MiSTer-Media-Player Git history at `8e418b3`.
This deletion changes no decoder algorithm or FPGA resource usage by itself.

The active decoder is under `rtl/mpeg2_new/`. The repository's GPL-2.0 license,
notices on retained source, and licenses for other reference tools remain
unchanged. Earlier phase documents describe historical side-by-side operation;
they do not describe the current build graph.
