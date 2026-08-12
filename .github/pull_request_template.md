## Summary

Describe the change and why it is needed.

## Scope

- [ ] Change is focused and does not include unrelated cleanup.
- [ ] Active source-file changes are reflected in `files.qip` when required.
- [ ] Standards-related behavior is based on H.262 / H.222.0 rather than an assumed implementation rule.

## Validation

- [ ] Quartus full compile completed successfully.
- [ ] `quartus_sta -t tools/phase1p_timing.tcl` was run when timing/placement could materially change.
- [ ] Relevant setup/hold/recovery/removal results were reviewed.
- [ ] `test_flat_gray_i.m2v` tested on hardware when applicable.
- [ ] `test_all_i.m2v` tested on hardware when applicable.
- [ ] USER LED behavior matches the intended phase behavior.
- [ ] No new visible flicker, corruption, line-cache artifacts, or unexpected color regression observed.

If any item was not performed or does not apply, explain why below.

## Timing / resources

Summarize meaningful timing margins and resource changes for active RTL modifications.

## Hardware observations

Describe visible behavior, USER timing, and any known limitation or regression.
