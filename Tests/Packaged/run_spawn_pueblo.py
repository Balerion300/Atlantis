import os,subprocess,json
from pathlib import Path
root=Path('diagnostic').resolve();out=root/'results';out.mkdir(exist_ok=True)
env=dict(os.environ,ATLANTIS_SPAWN_DIR=str(out),DYLD_INSERT_LIBRARIES=str(root/'SpawnPuebloProbe.dylib'))
with (out/'app.log').open('w') as log:
    p=subprocess.Popen([str(root/'release/Atlantis.app/Contents/MacOS/Atlantis')],env=env,stdout=log,stderr=log)
    try:code=p.wait(timeout=30)
    except subprocess.TimeoutExpired:p.kill();p.wait();raise
if code:raise RuntimeError(f'Native probe exited {code}')
doc=json.loads((out/'spawn-pueblo.json').read_text())
for row in doc['results']:
    print(json.dumps(row))
assert len(doc['results'])==9
for row in doc['results'][:6]:
    before=''.join(row['before'].values());after=''.join(row['afterSpawnUpdate'].values())
    if row['enabled']:
        assert '<BR>' not in before and '&amp;' not in before,row
        assert 'Description & details.' in before and 'Test object' in before,row
        assert 'After spawn update & text.' in after and '<BR>' not in after,row
        assert 'Updated channel.' in row['afterSpawnUpdate'].get('Staff',''),row
    else:assert '<BR>' in before and '&amp;' in before,row
row=doc['results'][6]
assert '<BR>' not in ''.join(row['one'].values()),row
assert '<BR>' in ''.join(row['two'].values()),row
row=doc['results'][7]
assert '<BR>' not in ''.join(row['one'].values()),row
assert '<BR>' not in ''.join(row['two'].values()),row
assert 'One still & parsed' in ''.join(row['one'].values()),row
print('PASS: settings, spawn refresh and concurrent-character isolation checks')
