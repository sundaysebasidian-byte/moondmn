#!/usr/bin/env python3
"""MoonDMN r4: native CLI stack-overflow thresholds for unbounded left-assoc chains.
usage: moondmn-r4-depth.py <main.exe>   (rc -11 = SIGSEGV)"""
import subprocess,sys,json
checks=0
exe=sys.argv[1]
gens={'unary':lambda n:'-'*n+'1','sum':lambda n:'+'.join(['1']*n),'path':lambda n:'x'+'.a'*n,'minus-chain':lambda n:'-'.join(['1']*n),'and':lambda n:' and '.join(['true']*n),'concat':lambda n:'+'.join(['"a"']*n),'filter':lambda n:'[1]'+'[1]'*n,'call':lambda n:'abs('*n+'1'+')'*n}
for k,g in gens.items():
  res=[]
  for n in [1000,2000,3000,5000,7000,10000,20000,40000]:
    e=g(n)
    if len(e)>200000: break
    p=subprocess.run([exe,'feel',e],capture_output=True,timeout=10)
    checks+=1
    assert p.returncode == 1, (k,n,p.returncode,p.stderr.decode()[:300])
    assert json.loads(p.stdout)["error"] == "E_LIMIT", (k,n,p.stdout[:300])
    o=p.stdout.decode()[:40].strip()
    res.append(f"{n}:{p.returncode}{'('+o.split(',')[0][10:]+')' if p.returncode==1 else ''}")
  print(k,' '.join(res))

print(f"checks={checks} crashes=0 all=E_LIMIT")
