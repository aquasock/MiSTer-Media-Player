# Progressive Program Stream hardware gate

Use stock Main on MiSTer `10.10.0.45`. This candidate restores Program Stream
ingress on the accepted `a57079f` baseline.

1. Load the candidate, leave Audio test Off and repeat the raw `.m2v` control
   used to accept the baseline. Require unchanged image and completion.
2. Select a short progressive 720x480 `.mpg` with MP2 through the normal menu.
   Audio packets are skipped at this stage. Require normal video speed and
   no corruption or freeze.
3. Let it finish. Require final-picture retirement and return from the loader.
   Record final screen and LEDs. Cadence error bit 10 means container failure.
4. Repeat the MPG, then the raw control, to check both reset transitions.
5. After the short file passes, test a longer progressive file. Record source
   hash, seed, filename and any failure location.

PCM tones remain a separate baseline check. Movie audio, seeking, native
480p output and interlaced playback are not criteria for this stage.
