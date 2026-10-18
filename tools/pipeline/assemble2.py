# usage: assemble2.py OUTDIR since_ms  -> writes img{i}.png from I{i}C{n}: chunks
import json,glob,re,sys,base64,os
d='/root/.claude/projects/-home-claude/6a0c7b53-723c-597b-8660-8f872140e9c7/tool-results/'
out,since=sys.argv[1],int(sys.argv[2])
parts={}
for f in glob.glob(d+'mcp-remote-devices-Claude_Browser__javascript_tool-*.txt')+glob.glob(d+'toolu_*.json'):
    m0=re.search(r'-(\d+)\.txt$',f)
    ts=int(m0.group(1)) if m0 else int(os.path.getmtime(f)*1000)
    if ts<since: continue
    t=json.load(open(f))[0]['text']
    m=re.match(r'"?I(\d+)C(\d+):([A-Za-z0-9+/=]*)',t)
    if not m: continue
    parts.setdefault(int(m.group(1)),{})[int(m.group(2))]=m.group(3)
for i,ch in sorted(parts.items()):
    keys=sorted(ch); b=''.join(ch[k] for k in keys)
    p=os.path.join(out,'img%d.png'%i); open(p,'wb').write(base64.b64decode(b))
    from PIL import Image; im=Image.open(p); im.load(); print(i,keys,len(b),im.size)
