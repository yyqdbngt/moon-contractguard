"""Independent Python standard library oracles; deterministic synthetic data."""
import csv, datetime, hashlib, heapq, io, json, math, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261005)
def run(request):
    result = subprocess.run(['node',str(root/'_build/js/debug/build/cmd/main/main.js'),'-'],
        input=json.dumps(request),capture_output=True,text=True,encoding='utf-8',timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for i in range(40):
    lower,upper = sorted([random.randint(-20,20),random.randint(-20,20)])
    value = random.randint(-30,30)
    report = run({'operation':'schema','document':{},'schema':{'type':'integer','minimum':lower,'maximum':upper},'value':value})
    assert report['valid'] == (lower <= value <= upper)
print('Independent schema range oracle: 40 generated constraints passed')
