#!/usr/bin/env python3
"""예배당 원화(assets/source/chapel-new.png)를 마을 시트에 패킹하고 village.json 항목을 도출합니다.

    python3 tools/extract/chapel.py          # town.webp 패킹 + assets/data/village.json 갱신
    python3 tools/extract/chapel.py --data   # village.json만 갱신 (측정값만 바뀌었을 때)

패킹은 시트 전체를 WebP로 다시 인코딩하므로 예배당이 없는 시트(git의 town.webp)에서 한 번만 실행합니다.

원본 Dart에는 이 원화가 없으므로 extract_data.py가 village.json을 다시 만들 때도 `merge()`로 같은 항목을 넣습니다.
입력은 chapel_measure.json(원화에서 잰 바닥 접점 F·R·L, 절벽 높이, 계단 위치)뿐이고 나머지는 모두 거기서 도출합니다.

좌표계: 윗면 평행사변형 P(s, t) = F_top + s·(R−F) + t·(L−F). F는 앞 모서리, R은 오른쪽(−30° 방향),
L은 왼쪽(+30° 방향)이며 보이지 않는 뒤 모서리 B = R + L − F 는 마주보는 변이 평행이라는 직교 투영 규칙으로 완성합니다.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MEASURE = json.loads((Path(__file__).with_name("chapel_measure.json")).read_text(encoding="utf-8"))
SHEET = ROOT / "assets/art/village/town.webp"


def _v(x):
    return np.array(x, dtype=float)


def _bbox(img):
    return img.getchannel("A").point(lambda a: 255 if a > 0 else 0).getbbox()  # (l, t, r, b)


def _bleed(rgba, iterations=6):
    """투명 가장자리 RGB를 이웃 불투명 색으로 채워 선형 보간 때 검은 테두리가 번지지 않게 한다."""
    a = rgba[..., 3] > 0
    rgb = rgba[..., :3].astype(float)
    known = a.copy()
    for _ in range(iterations):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(known.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sk = np.roll(known, (dy, dx), (0, 1))
            sr = np.roll(rgb, (dy, dx), (0, 1))
            acc += sr * sk[..., None]
            cnt += sk
        fill = (~known) & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill][:, None]
        known |= fill
    out = rgba.copy()
    out[..., :3] = rgb.astype(np.uint8)
    return out


def packed_rect():
    """시트 안에서 예배당이 차지하는 (x, y, w, h)와 원본 PNG에서 잘라 온 영역."""
    img = Image.open(ROOT / MEASURE["png"]).convert("RGBA")
    l, t, r, b = _bbox(img)
    p = MEASURE["atlas"]["packing"]
    x, y = MEASURE["atlas"]["xy"]
    return img, (l, t, r, b), (x, y, round((r - l) * p), round((b - t) * p))


def pack():
    img, (l, t, r, b), (x, y, w, h) = packed_rect()
    sheet = Image.open(SHEET).convert("RGBA")
    arr = np.array(sheet)
    arr[y : y + h + 8, x : x + w + 8] = 0
    sheet = Image.fromarray(arr)
    crop = img.crop((l, t, r, b)).convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")  # 곱한 알파로 줄여 번짐 방지
    sheet.paste(Image.fromarray(_bleed(np.array(crop))), (x, y))
    sheet.save(SHEET, "WEBP", quality=94, alpha_quality=100, method=6, exact=True)


def _intersect(p, d, q, e):
    """p + a·d 와 q + b·e 의 교점."""
    a, _b = np.linalg.solve(np.array([d, -e]).T, q - p)
    return p + a * d


def derive():
    img, (l, t, r, b), (x, y, w, h) = packed_rect()
    m = MEASURE
    F, R, L = _v(m["foot_F"]), _v(m["foot_R"]), _v(m["foot_L"])
    B = R + L - F
    up = np.array([0.0, -m["cliff_height"]])
    top = F + up

    def P(s, tt):
        return top + s * (R - F) + tt * (L - F)

    t1, t2 = m["stair_t"]
    travel = _v(m["stair_travel"])
    t_r, t_l = P(0.0, t1), P(0.0, t2)
    stair_a, stair_b = t_l + travel, t_r + travel
    k = m["yard_inset"]
    outline = [stair_a, stair_b, t_r, P(k, k), P(1 - k, k), P(1 - k, 1 - k), P(k, 1 - k), t_l]
    # 계단 양옆 절벽: 계단 옆선이 바닥선(F-L)과 만나는 점까지.
    x_r = _intersect(t_r, travel, F, L - F)
    x_l = _intersect(t_l, travel, F, L - F)
    faces = [
        [F + up, R + up, R, F],
        [L + up, t_l, x_l, L],
        [F + up, t_r, x_r, F],
    ]
    centre = (stair_a + stair_b) / 2.0
    top_in = (t_l + t_r) / 2.0
    steps = [centre + travel * 0.25, centre, centre * 0.66 + top_in * 0.34, centre * 0.33 + top_in * 0.67, top_in,
             top_in + (R - F) * 0.08]
    building = [P(m["building_s"][0], m["building_t"][0]), P(m["building_s"][1], m["building_t"][0]),
                P(m["building_s"][1], m["building_t"][1]), P(m["building_s"][0], m["building_t"][1])]

    p = m["atlas"]["packing"]

    def atlas(pt):
        return [round(float(x + (pt[0] - l) * p), 2), round(float(y + (pt[1] - t) * p), 2)]

    def native(pts):
        return [[round(float(c), 1) for c in q] for q in pts]

    foot = atlas(F)
    height = round(float((F[1] - t) * p), 2)
    sprite = dict(sheet=m["atlas"]["sheet"], source=[x, y, w, h], foot=foot, height=height, origin=[l, t], packing=p,
                  world_height=0, body=None, gvs=1, gvk=0)
    frame = dict(ground=[atlas(q) for q in (L, B, R, F)], height=height, foot=foot)
    yard = dict(outline=native(outline), entrance=0, faces=[native(f) for f in faces], steps=native(steps),
                building=native(building))
    return sprite, frame, [list(m["placement"][0]), m["placement"][1]], yard


def merge(data):
    sprite, frame, place, yard = derive()
    data["sprites"]["chapel"] = sprite
    data["frames"]["chapel"] = frame
    data["placements"]["chapel"] = place
    data["chapel"] = yard
    return data


def main():
    if "--data" not in sys.argv[1:]:
        pack()
    path = ROOT / "assets/data/village.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    path.write_text(json.dumps(merge(data), indent=1), encoding="utf-8")
    print(("chapel merged into " if "--data" in sys.argv[1:] else "chapel packed into %s and merged into " % SHEET.name) + path.name)


if __name__ == "__main__":
    main()
