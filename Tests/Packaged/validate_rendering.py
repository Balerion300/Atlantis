"""Acceptance assertions for the packaged native app's live guest transcript."""
import json,re,sys
from pathlib import Path
root=Path(sys.argv[1] if len(sys.argv)>1 else 'diagnostic/results')
results=[]
for name in ['telnet-plain','telnet-pueblo','tls-pueblo']:
    paths=list(root.rglob(name+'.json'))
    assert len(paths)==1,(name,'missing or ambiguous report')
    data=json.loads(paths[0].read_text())
    text=data['output']
    assert data['connected'] and data['loginSent'] and data['lookSent'],name
    assert 'WELCOME TO BLOOD OF DRAGONS' in text,(name,'missing welcome')
    assert 'You are connected with a Guest account.' in text,(name,'missing room description')
    assert 'Obvious Exits:' in text,(name,'missing room contents/exits')
    assert not re.search(r'</?(?:xch_mudtext|img|samp|br|a|pre)\b[^>]*>',text,re.I),(name,'literal protocol markup')
    assert '[Image]' not in text,(name,'phantom graphics-control image')
    assert all(s['allowed'] for s in data['sent']),(name,'unexpected command attempted')
    if name!='telnet-plain':assert data['links']>0,(name,'missing links')
    results.append({'case':name,'output_characters':len(text),'links':data['links'],'accepted':True})
print(json.dumps(results,indent=2))
