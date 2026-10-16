import json, os, subprocess, sys
from pathlib import Path

app=Path(sys.argv[1]).resolve()
out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,ATLANTIS_SCROLL_DIR=str(out),DYLD_INSERT_LIBRARIES=str(Path('diagnostic/ScrollProbe.dylib').resolve()))
with (out/'app.log').open('w') as log:
    p=subprocess.Popen([str(app/'Contents/MacOS/Atlantis')],env=env,stdout=log,stderr=log)
    try: code=p.wait(timeout=25)
    except subprocess.TimeoutExpired: p.kill();p.wait();raise
if code: raise RuntimeError(f'Probe exited {code}')
rows=json.loads((out/'scroll.json').read_text());print(json.dumps(rows,indent=2))
assert len(rows)==3 and not any('exception' in r for r in rows),rows
assert rows[0]['initialGap'] <= 2, rows
if '--baseline' not in sys.argv:
    assert rows[0]['gap']<=2, 'Following output did not stay at bottom after image growth'
    assert rows[0]['following'], 'Following mode was lost'
    assert abs(rows[1]['afterY']-rows[1]['beforeY'])<=2, 'Image loading moved a scrollback reader'
    assert not rows[1]['following'], 'Image loading enabled auto-scroll for a scrollback reader'
    assert abs(rows[2]['afterY']-rows[2]['beforeY'])<=2, 'An absent attachment moved the pane'
