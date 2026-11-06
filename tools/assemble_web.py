"""Assemble already-exported independent editions and the lightweight chooser."""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/web'
for edition in ('2d','3d'):
    source = ROOT / f'sjrpg_{edition}/build/web'
    if not (source / 'index.html').is_file() or not (source / 'index.wasm').is_file():
        raise SystemExit(f'Export sjrpg_{edition} before assembling')
OUT.mkdir(parents=True, exist_ok=True)
for edition in ('2d','3d'):
    source = ROOT / f'sjrpg_{edition}/build/web'
    target = OUT / edition
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(source, target)
shutil.copy2(ROOT/'web/index.html', OUT/'index.html')
shutil.copy2(ROOT/'sjrpg_2d/web/loading-bg.webp', OUT/'portal-bg.webp')
subprocess.run([sys.executable,str(ROOT/'tools/prepare_portal.py'),str(OUT)],check=True)
(OUT/'.nojekyll').touch()
print('Assembled chooser +2d +3d:',OUT)
