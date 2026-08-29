#!/usr/bin/env python3
import ftplib, hashlib, io, json, os, time, datetime

HOST="10.10.0.30"; USER="root"; PW="1"
TS=datetime.datetime.now().astimezone().strftime("%Y%m%dT%H%M%S")
STAMP=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
OUT="/run/media/vash/GIT/MiSTer-Media-Player/../capture690" 
OUT=os.path.abspath("/tmp/claude-1000/-run-media-vash-GIT-MiSTer-Media-Player/cfb5135d-a79e-4aa3-90a2-f9c98f316b3d/scratchpad/entry690")
os.makedirs(OUT, exist_ok=True)

rec={"captured":STAMP,"host":HOST,"files":{},"operations":[],"errors":[]}

f=ftplib.FTP(); f.connect(HOST,21,20); f.login(USER,PW); f.set_pasv(True)

def retr(remote, localname):
    buf=io.BytesIO()
    f.retrbinary("RETR "+remote, buf.write)
    data=buf.getvalue()
    lp=os.path.join(OUT,localname)
    open(lp,"wb").write(data)
    h=hashlib.sha256(data).hexdigest()
    rec["files"][remote]={"local":lp,"bytes":len(data),"sha256":h}
    rec["operations"].append("RETR "+remote)
    return data

def cmd(text):
    f.storbinary("STOR /dev/MiSTer_cmd", io.BytesIO((text+"\n").encode()))
    rec["operations"].append("STOR MiSTer_cmd: "+text)

log_before=retr("/tmp/MediaPlayer_ARM.log","arm_helper.log")
rec["files"]["/tmp/MediaPlayer_ARM.log"]["role"]="helper_log_before"

shots=[]
for i in (1,2):
    name="entry690_playback_%s_%d.png"%(TS,i)
    try:
        cmd("screenshot "+name)
        time.sleep(2.5)
        d=retr("/media/fat/screenshots/"+name,"screen_%d.png"%i)
        ok = d[:8]==b"\x89PNG\r\n\x1a\n" and d[-8:]==b"IEND\xaeB`\x82"
        rec["files"]["/media/fat/screenshots/"+name]["complete_png_verified"]=bool(ok)
        shots.append(name)
    except Exception as e:
        rec["errors"].append("screenshot %d: %r"%(i,e))

for p,n in [("/media/fat/MiSTer","MiSTer"),
            ("/media/fat/linux/MediaPlayer_Helper","MediaPlayer_Helper"),
            ("/media/fat/MediaPlayer.rbf","MediaPlayer.rbf"),
            ("/media/fat/MediaPlayer_20260828.rbf","MediaPlayer_20260828.rbf"),
            ("/media/fat/MediaPlayer_OLD.rbf","MediaPlayer_OLD.rbf"),
            ("/media/fat/games/MediaPlayer/dvd_opening_original.mpg","dvd_opening_original.mpg")]:
    try: retr(p,n)
    except Exception as e: rec["errors"].append("%s: %r"%(p,e))

log_after=retr("/tmp/MediaPlayer_ARM.log","arm_helper_after.log")
rec["helper_log_unchanged_during_capture"]= hashlib.sha256(log_before).hexdigest()==hashlib.sha256(log_after).hexdigest()
rec["screenshots"]=shots
rec["reloaded"]=False; rec["playback_started"]=False; rec["mode_changed"]=False
rec["finished"]=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
f.quit()
json.dump(rec, open(os.path.join(OUT,"entry690_capture.json"),"w"), indent=2)
print(json.dumps({k:rec[k] for k in ("captured","operations","errors","helper_log_unchanged_during_capture","screenshots","finished")}, indent=2))
for k,v in rec["files"].items():
    print(k, v["bytes"], v["sha256"][:16], v.get("complete_png_verified",""))
