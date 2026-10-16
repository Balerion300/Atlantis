import os,subprocess,time,json,sys,re,hashlib
from pathlib import Path
root=Path('diagnostic').resolve();out=root/'results';out.mkdir(exist_ok=True)
app=root/'release/Atlantis.app/Contents/MacOS/Atlantis'
if sys.argv[1]=='launch':
 env=dict(os.environ,ATLANTIS_DIAGNOSTIC_DIR=str(out),DYLD_INSERT_LIBRARIES=str(root/'RoomProbe.dylib'))
 with (out/'app.log').open('w') as log:p=subprocess.Popen([str(app)],stdout=log,stderr=log,env=env,start_new_session=True)
 (out/'process.json').write_text(json.dumps({'pid':p.pid}))
 deadline=time.monotonic()+40
 while time.monotonic()<deadline and not (out/'guest-ready.json').exists():
  if p.poll() is not None:raise RuntimeError('Room probe exited before guest was ready')
  time.sleep(.5)
 assert (out/'guest-ready.json').exists(),'Guest identity not received'
 print('Guest ready; identity only is uploaded for authorized relocation.')
else:
 deadline=time.monotonic()+100
 while time.monotonic()<deadline and not (out/'complete.json').exists():time.sleep(.5)
 assert (out/'complete.json').exists(),'Room probe did not finish'
 r=json.loads((out/'room-pueblo.json').read_text());text=r['output'];wire=r['wireText']
 tag_names=re.findall(r'</?([A-Za-z][A-Za-z0-9_]*)\b[^>]*>',text)
 end=re.findall(r'MAC_ROOM_END=(#[0-9]+) (#[0-9]+)',text)
 report={k:r[k] for k in ['case','connected','wireBytes','links','images']}
 report.update(release=os.environ['PROBE_RELEASE'],guest=json.loads((out/'guest-ready.json').read_text()),final_identity=end[-1] if end else None,output_characters=len(text),output_sha256=hashlib.sha256(text.encode()).hexdigest(),literal_tag_names=tag_names,tag_count=len(tag_names),wire_has_image_url=bool(re.search(r'<img[^>]+(?:src|fname)=',wire,re.I)),commands=[s['command'] for s in r['sent']])
 # Only metadata is uploaded. Room prose, player output and image URLs stay off artifacts.
 (out/'room-summary.json').write_text(json.dumps(report,indent=2))
 for p in out.iterdir():
  if p.name not in ('room-summary.json','guest-ready.json'):p.unlink()
 print(json.dumps(report,indent=2))
