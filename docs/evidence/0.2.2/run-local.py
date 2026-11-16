"""Reproduce executable workflow steps without installing over the pinned toolchain or deploying."""
import os, subprocess, json, pathlib
root = pathlib.Path(__file__).resolve().parents[3]
os.chdir(root)
os.environ['MOON_HOME']='/tmp/moon-new'
os.environ['PATH']='/tmp/moon-new/bin:'+os.environ['PATH']
commands=[
['moon','version','--all'], ['moon','update'], ['moon','fmt','--check'],
['moon','check','--deny-warn','--target','all'], ['moon','build','--target','native'],
*(['moon','test','--target',t] for t in ('native','wasm-gc','js','wasm')),
['python3','scripts/check-readme-version.py'],['python3','scripts/test-cli.py'],['moon','info'],
['moon','run','examples/api-demo'],['moon','run','cmd/main','--','feel','sum([1, 2, 3]) * 2'],
['moon','run','cmd/main','--','lint','examples/eligibility.dmn'],
['moon','run','cmd/main','--','eval','examples/eligibility.dmn','--decision','Eligible','--input','examples/input.json'],
['bash','scripts/build-web.sh'],['node','web/smoke.mjs'],['bash','scripts/fetch-tck.sh'],
*(['moon','run','cmd/main','--target','native','--','tck',f'.tck/TestCases/compliance-level-{n}','--now','2026-01-01T00:00:00Z','--json',f'evidence/tck-level-{n}.json'] for n in (2,3)),
]
rows=[]
for i,cmd in enumerate(commands):
 p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 path=pathlib.Path(f'docs/evidence/0.2.2/step-{i+1:02}.log');path.write_text(p.stdout)
 row={'command':cmd,'exit':p.returncode,'log':str(path)};rows.append(row);print(json.dumps(row),flush=True)
pathlib.Path('docs/evidence/0.2.2/workflow-results.json').write_text(json.dumps(rows,indent=2)+'\n')
assert all(r['exit']==0 for r in rows)
for n in (2,3):
 r=json.load(open(f'evidence/tck-level-{n}.json'));print(f"Level {n}: {r['passed']}/{r['total']} passed")
 assert r['skipped']==0 and (r['total'],r['passed'])==((116,116) if n==2 else (3291,3271))
