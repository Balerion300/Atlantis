import json,re
from pathlib import Path
out=Path('diagnostic/results');summary=[]
for p in out.glob('*'):
    if not p.is_file():continue
    text=p.read_text(errors='replace')
    text=re.sub(r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])','[IP redacted]',text)
    p.write_text(text)
for name in ['telnet-plain','telnet-pueblo','tls-pueblo']:
    p=out/(name+'.json')
    if not p.exists():continue
    r=json.loads(p.read_text());text=r.get('output','');wire=r.get('wireText','')
    tags=re.findall(r'</?(?:a|img|pre|br|xch_mudtext|font|body|html|span|div)\b[^>]*>',text,re.I)
    summary.append({'case':name,'connected':r['connected'],'wire_bytes':r['wireBytes'],'rendered_characters':len(text),'links':r['links'],'images':r['images'],'literal_markup_count':len(tags),'literal_markup_examples':tags[:12],'wire_has_mode_tag':bool(re.search('xch_mode',wire,re.I)),'sent':r['sent']})
(out/'summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
