from pathlib import Path
import hashlib,json,sys
root=Path('/run/media/vash/GIT/MiSTer-Media-Player')
sys.path.insert(0,str(root/'tools/streams'))
import generate_test_dvd_ceiling as dvd
import check_media_compatibility as compatibility
out=Path('/home/vash/mister-builds/entry602')
old=Path('/home/vash/mister-builds/entry593/official/bbb_480i_tff_15s_9800kbps.m2v').read_bytes()
assert hashlib.sha256(old).hexdigest()=='3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065'
result=dvd.verify_rate(old);result.pop('pictures')
smoke=Path('/run/media/vash/GIT/entry602-smoke.mpg').read_bytes()
video,_,_=compatibility.demux_program_stream(smoke)
try: dvd.verify_rate(video)
except ValueError as error:
 assert str(error)=='wrong bitrate header'
else:raise AssertionError('default ceiling gate accepted 9.6 Mbps header')
assert dvd.verify_rate(video,9600000)['frame_count']==120
report={'unchanged_default_9800_gate':result,'wrong_rate_header_rejected':True,'explicit_9600_gate_passed':True}
(out/'rate_regression.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
