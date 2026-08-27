from pathlib import Path
import re, json, hashlib, subprocess

root=Path('/home/vash/MiSTer-Media-Player');results=root/'.ai/current_results'
build=json.loads((results/'entry604_build.json').read_text())
status=json.loads((results/'entry604_build-only-status.json').read_text())
review=json.loads((results/'entry604_warning-review.json').read_text())
rbf=root/'output_files/entry604/MediaPlayer.rbf'
assert hashlib.sha256(rbf.read_bytes()).hexdigest()==build['rbf_sha256']
assert build['timing_positive'] and build['errors']==0 and review['reviewed']
assert status['deployed_by_agent'] is False
s=build['worst_slack_ns']
log=root/'.ai/core-log.md';old=log.read_text()
entries=[x for x in re.split(r'(?=^## \d+ (?:COMMIT|VERSION) )',old,flags=re.M) if x.strip()]
assert len(entries)==40 and entries[0].startswith('## 604 COMMIT Unreleased ??? ')
first=entries[0].replace('COMMIT Unreleased ???','COMMIT Unreleased d466bed',1)
outcome=f"""Published source d466bed removes the per-candidate timestamp-active restriction from native all-I overlap admission and secondary retention, while preserving the three-bank ownership and capacity guards, P/B and mode exclusions, cadence floor and timestamp-due gate. The existing native ownership test gains a second top with production timestamp association and timeline modules, connected through the existing runner. Before the user's scope change, its ten timestamp/ownership cases and the legacy ownership case pass; the old scheduler fails the new case and a mutant bypassing timestamp-due fails the future-PTS check as expected. The exact first 100 full-movie access units with helper timestamps complete all 100 pictures with zero errors or missed slots in the modeled video pipeline; this excludes physical PCM, HPS, scaler and CDC behavior. Nine completed focused/reconstruction regression jobs and the shared P/B raster test also pass. The user then explicitly skips A/V simulations and narrows this run to an RBF build and timing checks, retaining deployment responsibility. Remaining long A/V, pressure, two ceiling simulations and the unfinished native suite are stopped; none is claimed as a completed pass, and the original full qualification plan is not fulfilled. GUNSMOKE pulls exact published source d466bed into a clean build directory and completes Quartus 17.0.2 seed {build['seed']} in {build['elapsed_seconds']:.1f} seconds with {build['errors']} errors and {build['warnings']} warnings. The normalized warning set has no additions versus accepted f615ce0 and there are no newly ignored timing filters. Worst reported setup is {s['setup']:+.3f} ns, hold {s['hold']:+.3f} ns, recovery {s['recovery']:+.3f} ns, removal {s['removal']:+.3f} ns and minimum pulse width {s['minimum_pulse_width']:+.3f} ns, with every reported TNS zero. The {build['rbf_bytes']:,}-byte RBF has SHA256 {build['rbf_sha256']}; its Pi copy at output_files/entry604/MediaPlayer.rbf is independently hash-verified. No candidate is uploaded to the MiSTer, activated or played by the agent. Earlier read-only backups of the installed f615ce0 RBF and retained Main are verified and persisted under /home/vash/mister-builds/entry604-backup; Main, media and settings remain untouched by this cycle. Bounded build reports, completed evidence, cancellation scope and reproducible drivers are retained as .ai/current_results/entry604_*, with raw logs compressed losslessly. Built is checked; hardware Passed remains unchecked."""
next_steps="""The user will deploy the supplied RBF and reload the MediaPlayer core, then replay the unchanged games/MediaPlayer/bbb_full_480i_tff_av_10080kbps.mpg with audio. Record the selected Bob/Weave mode and reload lifecycle explicitly, observe whether playback passes the former opening freeze and continues through the end with sound, sync and a responsive menu, and leave telemetry ready. On the next report, retrieve the helper log first and a fresh checksum-valid screenshot, verify the installed candidate hash and inspect presentation and audio errors, counts and deadline records. Hardware acceptance and long A/V simulation remain open; do not describe positive FPGA timing or the completed opening model as proof that the full movie or commercial DVDs play correctly. Use modular per-frame timing and full picture/transport counts because the 32-bit 60 MHz session timer wraps during the full film. Retain restoration artifacts, restricted core.md and the forty-entry ring."""
first=re.sub(r'(?<=#### Outcome:\n\n).*?(?=\n\n#### Next Steps:)',lambda _:outcome,first,flags=re.S)
first=re.sub(r'(?<=#### Next Steps:\n\n).*?(?=\n\n#### Files Modified:)',lambda _:next_steps,first,flags=re.S)
first=first.replace('- [ ] Built','- [x] Built')
text=first+''.join(entries[1:])
parts=[x for x in re.split(r'(?=^## \d+ (?:COMMIT|VERSION) )',text,flags=re.M) if x.strip()]
assert len(parts)==40 and parts[1:]==entries[1:] and 'Unreleased ???' not in text
for p in parts:
    assert re.findall(r'^#### (.+)$',p,re.M)==['Coming From:','Purpose:','Outcome:','Next Steps:','Files Modified:','Status:']
    assert re.search(r'#### Status:\n\n- \[[ x]\] Built\n- \[[ x]\] Passed\n',p)
    assert p.rstrip().endswith('---')
assert subprocess.check_output(['git','hash-object','.ai/core.md'],cwd=root,text=True).strip()=='6ccaa838b8afac82857eab9fc3fadd488038abfc'
log.write_text(text)
(rbf.parent/'SHA256SUMS').write_text(build['rbf_sha256']+'  MediaPlayer.rbf\n')
(rbf.parent/'BUILD.txt').write_text(f"Source: {build['source_commit']}\nQuartus: {build['quartus_version']}\nSeed: {build['seed']}\nErrors: {build['errors']}\nWarnings: {build['warnings']} (no added normalized warnings versus f615ce0)\nWorst reported slack (ns): {json.dumps(s,sort_keys=True)}\nAll reported TNS: 0\n\nUser-managed deployment; no deployment performed by agent.\nRemaining A/V simulations canceled at user request; hardware validation pending.\n")
print('PASS: RBF hash, build/timing review, 40-entry syntax audit, settled entries unchanged, core.md restricted hash retained')
