"""Keep previous direct HTML bookmarks working after the edition split."""
import sys
from pathlib import Path

root=Path(sys.argv[1])
for edition in ('2d','3d'):
    target=f'./{edition}/'
    (root/f'{edition}.html').write_text('''<!doctype html><html lang="ko"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>자연의 수호자</title><script>
location.replace(TARGET + location.search + location.hash);
</script><a href="TARGET">게임 열기</a></html>'''.replace('TARGET',repr(target),1).replace('TARGET',target))
# A prior root-level game build must not be served alongside the chooser.
for pattern in ('index-*.pck','index.pck','index.wasm','index.js','index.audio.*','index.worklet.*'):
    for old in root.glob(pattern):
        if old.is_file(): old.unlink()
