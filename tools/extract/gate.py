#!/usr/bin/env python3
"""성문 원화 2종(쌍탑 문루)과 성벽 텍스처를 패킹하고 village.json 항목을 도출합니다.

    python3 tools/extract/gate.py          # gates.webp·walls.webp 생성 + assets/data/village.json 갱신
    python3 tools/extract/gate.py --data   # village.json만 갱신 (측정값만 바뀌었을 때)

입력은 gate_measure.json(원화에서 잰 바닥 모서리·탑 바닥·날개벽 높이)뿐이고 나머지는 모두 거기서 도출합니다.
원본 Dart에는 이 원화가 없으므로 extract_data.py가 village.json을 다시 만들 때도 `merge()`로 같은 항목을 넣습니다.

좌표계: 모든 지면 계산은 보정 평면(`gvs`/`gvk` 적용 후, 지면 축이 정확히 ±30°)에서 한다. 문루 길이 방향 단위벡터 a(좌→우),
뒤쪽(두께) 방향 b 로 p = o + α·a + β·b. 결과 좌표는 다시 원본 픽셀 → 아틀라스 픽셀로 되돌려 저장한다(IsoSprite.atlas_point가 보정을 적용).
성벽 높이·두께(`wall`)는 날개벽 흉벽 윗면까지의 높이에 맞춰 문루 배율(`world_height`)을 정하므로 성벽과 날개벽이 같은 높이로 이어진다.
"""
import json
import hashlib
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
import gate_projection

ROOT = Path(__file__).resolve().parents[2]
M = json.loads(Path(__file__).with_name("gate_measure.json").read_text(encoding="utf-8"))
SHEET = ROOT / "assets/art/village/gates.webp"
WALL_SHEET = ROOT / "assets/art/village/walls.webp"
COS, SIN = math.cos(math.radians(30)), 0.5
PAD = 4
WALL_SEGS = {}


def _bbox(img):
    return img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()


def _bleed(rgba, iterations=6):
    """투명 가장자리 RGB를 이웃 불투명 색으로 채워 선형 보간 때 번지는 테두리를 막는다."""
    a = rgba[..., 3] > 0
    rgb = rgba[..., :3].astype(float)
    known = a.copy()
    for _ in range(iterations):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(known.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sk = np.roll(known, (dy, dx), (0, 1))
            acc += np.roll(rgb, (dy, dx), (0, 1)) * sk[..., None]
            cnt += sk
        fill = (~known) & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill][:, None]
        known |= fill
    out = rgba.copy()
    out[..., :3] = rgb.astype(np.uint8)
    return out


def _layout():
    """게이트별 (원본 이미지, bbox, 시트 안 x·y·w·h)를 가로로 나란히 배치한다."""
    p = M["packing"]
    out = {}
    x = PAD
    for key, g in M["gates"].items():
        img = gate_projection.image(g["png"], g.get("baked_warp", ""))
        l, t, r, b = _bbox(img)
        w, h = round((r - l) * p), round((b - t) * p)
        out[key] = (img, (l, t, r, b), (x, PAD, w, h))
        x += w + PAD * 2
    return out


def pack():
    lay = _layout()
    width = max(x + w for _, _, (x, _, w, _) in lay.values()) + PAD
    height = max(h for _, _, (_, _, _, h) in lay.values()) + PAD * 2
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for img, (l, t, r, b), (x, y, w, h) in lay.values():
        crop = img.crop((l, t, r, b)).convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")
        sheet.paste(Image.fromarray(_bleed(np.array(crop))), (x, y))
    sheet.save(SHEET, "WEBP", quality=90, alpha_quality=100, method=6, exact=True)
    print("gates sheet", sheet.size)


def _stone_median(img, box):
    """Use only the reviewed front stone face, never wood, transparent background or an entire shaded silhouette."""
    arr = np.array(img.crop(tuple(box)).convert("RGBA"))
    return np.median(arr[..., :3][arr[..., 3] > 200], axis=0)


def _measure_seg(img):
    """성벽 구간 원화(RGBA)에서 앞면 바닥선(최소제곱)과 세로 폭 E를 잰다.
    E = 한 열에서 앞 바닥선 ~ 뒤 흉벽 꼭대기(= 높이 H + 두께 t, 120°에서 두께는 같은 열의 세로 간격 t·S 로 보인다)의 95백분위."""
    alpha = np.array(img.getchannel("A")) > 128
    h, w = alpha.shape
    xs = np.arange(4, w - 4)
    bottom = np.array([np.nonzero(alpha[:, x])[0].max() for x in xs], float)
    top = np.array([np.nonzero(alpha[:, x])[0].min() for x in xs], float)
    m, c = np.polyfit(xs, bottom, 1)
    return m, c, float(np.percentile(bottom - top, 95)), w, h


def _wall_image(sg, grade=False):
    img = gate_projection.image(sg["png"], sg.get("baked_warp", ""))
    if grade:
        raw = Image.open(ROOT / sg["png"]).convert("RGBA")
        reference_path, reference_box = sg["stone_reference"]
        reference = Image.open(ROOT / reference_path).convert("RGBA")
        gain = _stone_median(reference, reference_box) / _stone_median(raw, sg["stone_face"])
        arr = np.array(img)
        arr[..., :3] = np.clip(arr[..., :3].astype(float) * gain, 0, 255).astype(np.uint8)
        img = Image.fromarray(arr)
    if sg.get("mirror_x", False):
        img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return img


def wall_sheet():
    """성문과 같은 석재로 제작한 성벽을 석재 앞면 표본에 맞춰 walls.webp 로 패킹한다."""
    cfg = M["wall"]
    p = cfg["packing"]
    thick, height = cfg["thick"], cfg["height"]
    out = {}
    x = PAD
    tiles = []
    for key, sg in cfg["segs"].items():
        img = _wall_image(sg, True)
        m, c, e, w, h = _measure_seg(img)
        slope_deg = math.degrees(math.atan(abs(m)))
        if abs(slope_deg - 30.0) > 2.5:
            sys.exit("%s: 성벽 바닥선이 ±30°에서 2.5° 넘게 벗어납니다 (%.1f°)" % (key, slope_deg))
        sw, sh = round(w * p), round(h * p)
        tiles.append((key, img, x, sw, sh))
        # 시트 좌표(패킹 후): 앞 바닥선의 x=0, x=W 에서의 y, 시트 픽셀당 월드 픽셀(세로·가로 같은 배율).
        gvs = sg.get("gvs", 1)
        k = (height + thick) * 0.97 / (e * gvs) / p
        out[key] = dict(source=[x, PAD, sw, sh], y0=round(c * p + PAD, 2), y1=round((m * w + c) * p + PAD, 2),
                        k=round(float(k), 4), gvs=gvs, slope_deg=round(slope_deg, 2), extent=round(e, 1))
        out[key].update(baked_warp=sg.get("baked_warp", ""), mirror_x=sg.get("mirror_x", False))
        x += sw + PAD * 2
    sheet = Image.new("RGBA", (x, max(t[4] for t in tiles) + PAD * 2), (0, 0, 0, 0))
    for key, img, tx, sw, sh in tiles:
        crop = img.convert("RGBa").resize((sw, sh), Image.LANCZOS).convert("RGBA")
        sheet.paste(Image.fromarray(_bleed(np.array(crop))), (tx, PAD))
    sheet.save(WALL_SHEET, "WEBP", quality=88, alpha_quality=100, method=6, exact=True)
    print("walls sheet", sheet.size, out)
    return out


def wall_data():
    """walls.webp 를 다시 만들지 않고 데이터만 도출한다(측정은 같은 코드)."""
    cfg = M["wall"]
    p = cfg["packing"]
    out = {}
    x = PAD
    for key, sg in cfg["segs"].items():
        img = _wall_image(sg)
        m, c, e, w, h = _measure_seg(img)
        sw, sh = round(w * p), round(h * p)
        gvs = sg.get("gvs", 1)
        k = (cfg["height"] + cfg["thick"]) * 0.97 / (e * gvs) / p
        out[key] = dict(source=[x, PAD, sw, sh], y0=round(c * p + PAD, 2), y1=round((m * w + c) * p + PAD, 2),
                        k=round(float(k), 4), gvs=gvs, slope_deg=round(math.degrees(math.atan(abs(m))), 2), extent=round(e, 1))
        out[key].update(baked_warp=sg.get("baked_warp", ""), mirror_x=sg.get("mirror_x", False))
        x += sw + PAD * 2
    return out


def _unit(sign_y, sign_x=1.0):
    return np.array([sign_x * COS, sign_y * SIN])


def derive(key, g, lay):
    img, (l, t, r, b), (sx, sy, sw, sh) = lay[key]
    p = M["packing"]
    project = lambda point: gate_projection.point(g.get("baked_warp", ""), point)
    F = project(g["front_R"]) - project(g["front_L"])
    T = np.array(g["back"], float)
    a = _unit(1.0 if F[1] > 0 else -1.0)
    bv = _unit(-1.0, 1.0 if T[0] > 0 else -1.0)
    # gvs·F.y + gvk·F.x = F.x·tan(a),  gvs·T.y + gvk·T.x = T.x·tan(b)  → 두 변이 정확히 ±30°가 되는 보정
    if "gvs" in g:
        gvs, gvk = g["gvs"], g["gvk"]
    else:
        gvs, gvk = np.linalg.solve(np.array([[F[1], F[0]], [T[1], T[0]]]), [F[0] * a[1] / a[0], T[0] * bv[1] / bv[0]])

    def corr(pt):
        pt = project(pt)
        return np.array([pt[0], pt[1] * gvs + pt[0] * gvk])

    def uncorr(pt):
        return np.array([pt[0], (pt[1] - pt[0] * gvk) / gvs])

    o = corr(g["front_L"])
    basis = np.array([a, bv]).T

    def coords(pt):
        return np.linalg.solve(basis, np.asarray(pt, float) - o)

    def at(al, be):
        return o + al * a + be * bv

    back_at = np.array(g[g.get("back_at", "front_R")], float)
    Tc = corr(back_at + T) - corr(back_at)
    beta_t = float(coords(o + Tc)[1])
    alpha_r, beta_r = coords(corr(g["front_R"]))
    cl_beta, cr_beta = beta_t / 2.0, float(beta_r) + beta_t / 2.0
    towers = []
    for tw in g["towers"]:
        rad = tw["rx"] / (math.sqrt(2) * COS)
        bottom = corr([tw["cx"], tw["bottom"]])
        c = coords(bottom - np.array([0.0, math.sqrt(0.5) * rad]))
        towers.append((float(c[0]), float(c[1]), rad))
    alpha_f = (towers[0][0] + towers[1][0]) / 2.0
    beta_f = (cl_beta + cr_beta) / 2.0
    foot_n = uncorr(at(alpha_f, beta_f))  # 원본 픽셀

    def atlas_projected(pt_n):
        return [round(float(sx + (pt_n[0] - l) * p), 2), round(float(sy + (pt_n[1] - t) * p), 2)]

    def atlas(pt_n):
        return atlas_projected(project(pt_n))

    def A(al, be):  # (α, β) → 아틀라스 픽셀
        return atlas_projected(uncorr(at(al, be)))

    # 성벽 높이에 맞춘 배율: 날개벽 높이(보정 후 세로 픽셀)가 wall.height 가 되도록.
    if "wing_height_line" in g:
        top, base = (corr(point) for point in g["wing_height_line"])
        k_unit = M["wall"]["height"] / (base[1] - top[1])
    else:
        k_unit = M["wall"]["height"] / (g["wing_height_px"] * gvs)
    height = round(float((foot_n[1] - t) * p), 2)
    world_height = float(k_unit * (foot_n[1] - t))

    # 보정 후 날개벽 바닥선 각도 검사(실루엣에서 잰 점).
    wing_deg = []
    for p0, p1 in g["wing_in"]:
        d = corr(p1) - corr(p0)
        wing_deg.append(round(abs(math.degrees(math.atan2(d[1], d[0]))), 1))

    # 깊이 조각: 폭 slice_px 의 세로 띠마다 화면에서 가장 낮은 불투명 픽셀이 그 띠의 정렬 기준점이다.
    alpha = np.array(img.getchannel("A")) > 128
    slices = []
    step = M["slice_px"]
    x0 = l
    while x0 < r:
        x1 = min(x0 + step, r)
        cols = np.nonzero(alpha[:, x0:x1].any(0))[0]
        if len(cols):
            low = int(np.max([np.nonzero(alpha[:, x])[0].max() for x in range(x0, x1) if alpha[:, x].any()]))
            sx0, sx1 = round(sx + (x0 - l) * p), round(sx + (x1 - l) * p)
            slices.append([sx0, sx1, round(float((sx0 + sx1) / 2.0), 2), round(float(sy + (low - t) * p), 2)])
        x0 = x1

    # 충돌: 두 탑(원)과 탑 바깥 날개벽(상자). 통로는 비워 둔다.
    def ring(c, rad, n=12):
        return [A(c[0] + rad * math.cos(2 * math.pi * i / n), c[1] + rad * math.sin(2 * math.pi * i / n)) for i in range(n)]

    def box(a0, a1, bc):
        h = beta_t / 2.0
        return [A(a0, bc - h), A(a1, bc - h), A(a1, bc + h), A(a0, bc + h)]

    (al0, be0, r0), (al1, be1, r1) = towers
    solids = [ring((al0, be0), r0), ring((al1, be1), r1),
              box(0.0, al0, cl_beta), box(al1, float(alpha_r), cr_beta)]
    passage_r = max(r0, r1)
    passage = [A(al0 + r0, beta_f - passage_r), A(al1 - r1, beta_f - passage_r), A(al1 - r1, beta_f + passage_r), A(al0 + r0, beta_f + passage_r)]
    ends = [A(0.0, cl_beta), A(float(alpha_r), cr_beta)]

    sprite = dict(sheet=M["sheet"], source=[sx, sy, sw, sh], foot=atlas_projected(foot_n), height=height, origin=[l, t], packing=p,
                  world_height=round(world_height, 2), body=None, gvs=round(float(gvs), 5), gvk=round(float(gvk), 5), slices=slices)
    if g.get("baked_warp"):
        sprite["baked_warp"] = g["baked_warp"]
    ground = [atlas(g["front_L"]), atlas(g["front_R"]), atlas(np.array(g["front_R"]) + T), atlas(np.array(g["front_L"]) + T)]
    frame = dict(ground=ground, height=height, foot=sprite["foot"])
    info = dict(ends=ends, solids=solids, passage=passage)
    if "model_reference" in g:
        # The generated artwork changes; the existing world-space passages,
        # collision rings and wall attachment points remain authoritative.
        def model_point(point):
            corrected = np.array([foot_n[0], foot_n[1] * gvs + foot_n[0] * gvk])
            return atlas_projected(uncorr(corrected + np.asarray(point) / k_unit))
        model = g["model_reference"]
        info = dict(ends=[model_point(q) for q in model["ends"]],
                    solids=[[model_point(q) for q in polygon] for polygon in model["solids"]],
                    passage=[model_point(q) for q in model["passage"]])
        frame["ground"] = [model_point(q) for q in model["ground"]]
    report = dict(gvs=sprite["gvs"], gvk=sprite["gvk"], wing_deg=wing_deg, k_unit=round(float(k_unit), 3),
                  thick=round(beta_t * k_unit, 1), passage=round((al1 - r1 - al0 - r0) * k_unit, 1),
                  tower_r=round(r0 * k_unit, 1), span=round(float(alpha_r) * k_unit, 1), world_height=sprite["world_height"])
    return sprite, frame, info, report


def merge(data):
    global WALL_SEGS
    WALL_SEGS = wall_data()
    lay = _layout()
    for key in ("gate-0", "gate-1", "gate-2", "gate-3"):
        data["sprites"].pop(key, None)
    data.pop("gate_contacts", None)
    data["gates"] = {}
    data["gate_model_reference"] = {key: g["model_reference"] for key, g in M["gates"].items() if "model_reference" in g}
    data["wall"] = dict(height=M["wall"]["height"], thick=M["wall"]["thick"], slice_px=M["wall"]["slice_px"], segs=WALL_SEGS)
    for key, g in M["gates"].items():
        sprite, frame, info, report = derive(key, g, lay)
        data["sprites"][key] = sprite
        data["frames"][key] = frame
        data["gates"][key] = info
        print(key, report)
        if max(report["wing_deg"]) > 32.5 or min(report["wing_deg"]) < 27.5:
            sys.exit("%s: 날개벽 바닥선이 보정 후에도 ±30°에서 2.5° 넘게 벗어납니다: %s" % (key, report["wing_deg"]))
    return data


def family_manifest(data):
    """Lock the reviewed generated family and its actual packed derivatives."""
    def record(path):
        return dict(path=path, sha256=hashlib.sha256((ROOT / path).read_bytes()).hexdigest())
    sources = sorted({g["png"] for g in M["gates"].values()} | {s["png"] for s in M["wall"]["segs"].values()})
    result = dict(master_reference=record("assets/source/style/approved-game-reference.jpg"),
                  concept=record("assets/source/style/gate-wall-design.png"),
                  generation=record("tools/extract/gate_generation.json"),
                  sources=[record(path) for path in sources],
                  renders=[record("assets/art/village/gates.webp"), record("assets/art/village/walls.webp")],
                  wall_module=dict(source=M["wall"]["segs"]["a"]["png"],
                                   derived_direction="b reflects the same projected module horizontally",
                                   height=data["wall"]["height"], thickness=data["wall"]["thick"],
                                   scale_a=data["wall"]["segs"]["a"]["k"], scale_b=data["wall"]["segs"]["b"]["k"]))
    (ROOT / "assets/data/gate_family.json").write_text(json.dumps(result, indent=1) + "\n")


def main():
    if "--data" not in sys.argv[1:]:
        pack()
        wall_sheet()
    path = ROOT / "assets/data/village.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    data = merge(data)
    path.write_text(json.dumps(data, indent=1), encoding="utf-8")
    family_manifest(data)
    print("gates merged into", path.name)


if __name__ == "__main__":
    main()
