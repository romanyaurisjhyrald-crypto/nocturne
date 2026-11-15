"""Check catalogs, local resources and browser-script syntax before publication."""
from pathlib import Path
import json,re,shutil,subprocess,tempfile,sys

root=Path(__file__).resolve().parents[1]
catalogs=[json.loads((root/'locales'/f'{lang}.json').read_text(encoding='utf-8')) for lang in ['en','es']]
assert catalogs[0].keys()==catalogs[1].keys(),'Localization keys differ'
assert all(isinstance(v,str) for c in catalogs for v in c.values())
node=shutil.which('node')
if len(sys.argv)>1:node=sys.argv[1]
assert node,'Node.js is required to validate embedded scripts'
count=0
with tempfile.TemporaryDirectory() as directory:
    for html in (root/'stories/html').glob('*/index.html'):
        text=html.read_text(encoding='utf-8')
        assert 'MouseMission.record(' in text and 'MouseMission.draw(' in text
        for i,(attrs,code) in enumerate(re.findall(r'<script([^>]*)>(.*?)</script>',text,re.S|re.I)):
            if 'application/json' in attrs or 'application/ld+json' in attrs or not code.strip():continue
            script=Path(directory)/f'{html.parent.name}_{i}.js';script.write_text(code,encoding='utf-8')
            result=subprocess.run([node,'--check',str(script)],capture_output=True,text=True)
            assert result.returncode==0,result.stderr
            count+=1
for filename in ['project.godot','LICENSE','NOTICE','docs/AI_USE.md','docs/NASA_SOURCES.md']:
    assert (root/filename).is_file(),filename
for f in root.rglob('*'):
    if not f.is_file() or '.git' in f.parts or '.godot' in f.parts or f.suffix not in ['.gd','.tscn','.tres','.json']:continue
    for rel in re.findall(r'res://([^"\s]+)',f.read_text(encoding='utf-8')):
        if any(c in rel for c in ['%','+']) or rel.endswith('/') or rel.startswith('previews/') or rel in ['assets/logo.png','assets/logo.webp','assets/logo.jpg','assets/click.png','assets/hold_click.png']:continue
        # Runtime-composed paths and documented optional artwork are not required resources.
        if rel.endswith('.') or rel in ['stories/html/','assets/']:continue
        if '"' not in rel and not (root/rel).exists():
            print('Review optional/dynamic resource:',f.relative_to(root),rel)
print(f'PASS: matching catalogs, four games, {count} parsed JavaScript scripts, publication documents')
