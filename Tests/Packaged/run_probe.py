import os,subprocess,time,json
from pathlib import Path
root=Path('diagnostic').resolve();out=root/'results';out.mkdir(exist_ok=True)
app=root/'release/Atlantis.app/Contents/MacOS/Atlantis'
# Dedicated fresh GitHub runner account; no user Address Book or saved credentials.
with (out/'app.log').open('w') as log:
    p=subprocess.Popen([str(app)],stdout=log,stderr=log)
    time.sleep(4)
    alive=p.poll() is None
    (out/'plain-startup.json').write_text(json.dumps({'alive_after_four_seconds':alive,'exit_code':p.poll()}))
    if alive:p.terminate();p.wait(timeout=10)
    if not alive:raise RuntimeError('Released executable failed startup')
    env=dict(os.environ,ATLANTIS_DIAGNOSTIC_DIR=str(out),DYLD_INSERT_LIBRARIES=str(root/'LiveProbe.dylib'))
    p=subprocess.Popen([str(app)],stdout=log,stderr=log,env=env)
    try:code=p.wait(timeout=105)
    except subprocess.TimeoutExpired:p.kill();p.wait();raise RuntimeError('Live probe timed out')
    (out/'probe-process.json').write_text(json.dumps({'exit_code':code,'complete_file':(out/'complete.json').exists()}))
    if code or not (out/'complete.json').exists():raise RuntimeError('Native released-app probe did not complete')
