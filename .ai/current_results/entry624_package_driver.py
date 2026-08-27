from pathlib import Path
import json,hashlib,gzip,shutil,zipfile,subprocess
base=Path('/home/vash/mister-builds/entry624');root=base/'official';source='140a5b711e84821688641c8903000e02e78f580c'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==source
assert not subprocess.check_output(['git','diff','HEAD'],cwd=root,text=True)
main=json.loads((base/'main-build.json').read_text());official=json.loads((base/'official-results.json').read_text());av=json.loads((base/'audio-video-checks.json').read_text());negative=json.loads((base/'negative-controls.json').read_text());backup=json.loads((base/'handoff-verification.json').read_text());manifest=json.loads((base/'suite/manifest.json').read_text())
assert official['all_passed'] and av['all_passed'] and not main['warnings'] and all(r['rejected'] for r in negative)
assert backup['persistent_backups_verified'] and backup['two_generations_byte_identical']
for name in ('ac3-decode.json','ac3-passthrough.json','dts-passthrough.json'):assert json.loads((base/name).read_text())['passed']
package=base/'package';(package/'games/MediaPlayer').mkdir(parents=True,exist_ok=True)
shutil.copy2(base/'Main_MiSTer/bin/MiSTer',package/'MiSTer')
files={}
for entry in manifest['tests']:
 path=base/'suite'/entry['file'];assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256']
 shutil.copy2(path,package/'games/MediaPlayer'/path.name)
for path in [package/'MiSTer']+sorted((package/'games/MediaPlayer').glob('*.mpg')):
 data=path.read_bytes();files[str(path.relative_to(package))]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
assert files['MiSTer']['sha256']==main['sha256']
(package/'SHA256SUMS').write_text(''.join(r['sha256']+'  '+name+'\n' for name,r in files.items()))
(package/'README.txt').write_text('''MiSTer Media Player regression update — source 140a5b7

Contains a new Main executable and six corrected 12-second regression fixtures.
No RBF or helper update is needed. Keep the installed seed-17 RBF (aa7f064)
and helper (078d36b). This is a hardware-test candidate, not an accepted release.

Manual installation:
1. Preserve the current MiSTer executable and test files before replacement.
   Agent-verified backups also exist on GUNSMOKE at
   /home/vash/mister-builds/entry624-backup.
2. Copy MiSTer to /media/fat/MiSTer and keep it executable.
3. Copy games/MediaPlayer/test_*.mpg to the matching SD-card folder.
4. Reboot once to activate the replacement Main, then load MediaPlayer.

First validation run:
Select Bob and play test_1_interlace_tff.mpg once. The white bar should move
steadily downward and wrap; a 440 Hz tone should play. Exercise the menu during
playback and after it ends, then leave the terminal screen ready. Report whether
the menu is responsive. Do not play another file until its helper log is captured.
Then test BFF with test_2_interlace_bff.mpg in a separately captured run.

Remaining suite:
3: Scrolling eight-pixel bands for Bob/Weave comparison.
4: Progressive all-I moving test pattern.
5: AC-3 channel sweep; HDMI is stereo downmix, S/PDIF carries compressed audio.
6: DTS channel sweep; select S/PDIF (there is no DTS HDMI decoder).
Channel order in 5/6: FL, FR, FC, LFE, BL, BR, two seconds each.
HDMI downmix intentionally omits LFE. A 2.1 system cannot prove discrete 5.1 routing.

Main now yields at zero verified credits, retains unsent bytes, and limits each
step to 2048 bytes with a 2 ms work budget checked between steps (maximum eight
steps and one pipe read per poll). This is not a hard OS scheduling guarantee.
Legacy acknowledged-only cores retain their existing blocking handshake behavior.
Host diagnostics are profile_version=2 / credit_step_v1: pipe_read entries cover
all source bytes, while transfer entries are sampled. Old log parsers need updating.

The new bar fields and ordering, source byte preservation, audio outputs,
credit handling and fault guards passed software checks. Physical menu response,
full-rate throughput and corrected-fixture playback still need hardware validation.
''')
qualification={'source_commit':source,'ready_for_user_hardware_test':True,'hardware_accepted':False,'deployed_by_agent':False,'new_rbf_required':False,'main':main,'files':files,'passed':['native_loader_and_transport','address_undefined_sanitizers','production_RTL_bridge_legacy_and_credit','20_step_resume_cases_and_fault_guards','24_seeded_short_read_credit_sequences','six_corrected_fixtures_360_pictures_each','720_temporal_field_positions_each_bar_fixture','two_generations_byte_identical','old_static_and_wrong_field_order_negative_controls','pending_byte_loss_negative_control','all_fixture_clean_video_byte_exact','mp2_modes_equal_and_original_audio_preserved','ac3_independent_decode_max_difference_two','ac3_and_dts_passthrough_byte_exact','existing_ceiling_generator_tests','persistent_backups_verified'],'scope':'No physical playback or deployment; no new FPGA build or timing claim. Main rebuilt, helper/RBF retained. Legacy and terminal cleanup are not hard realtime bounded.'}
(base/'qualification.json').write_text(json.dumps(qualification,indent=2)+'\n')
with zipfile.ZipFile(base/'MediaPlayer_140a5b7_regression_update.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for path in sorted(package.rglob('*')):
  if path.is_file():z.write(path,str(path.relative_to(package)))
zip_path=base/'MediaPlayer_140a5b7_regression_update.zip'
(base/'package.json').write_text(json.dumps({'archive':zip_path.name,'bytes':zip_path.stat().st_size,'sha256':hashlib.sha256(zip_path.read_bytes()).hexdigest(),'files':files},indent=2)+'\n')
export=base/'reports-export';export.mkdir(exist_ok=True)
names=['source.json','main-build.json','main-build.log','host-rtl.json','host-rtl.log','host-rtl-results.json','host-sanitized-results.json','media.json','media.log','official-results.json','negative-controls.json','extra.log','audio-video-checks.json','audio-checks.log','ac3-decode.json','ac3-passthrough.json','dts-passthrough.json','handoff-verification.json','qualification.json','package.json','suite/manifest.json']
evidence={}
for name in names:
 p=base/name;data=p.read_bytes();stored=gzip.compress(data,mtime=0) if name.endswith('.log') else data
 target='entry624_'+p.name+('.gz' if name.endswith('.log') else '')
 (export/target).write_bytes(stored);evidence[target]={'original_bytes':len(data),'original_sha256':hashlib.sha256(data).hexdigest(),'stored_sha256':hashlib.sha256(stored).hexdigest()}
(export/'entry624_evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
print(json.dumps({'main_sha256':main['sha256'],'zip_sha256':hashlib.sha256(zip_path.read_bytes()).hexdigest(),'zip_bytes':zip_path.stat().st_size,'files':len(files)},indent=2))
