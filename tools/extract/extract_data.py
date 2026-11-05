#!/usr/bin/env python3
"""원본 sjrpg(Flutter) 소스에서 Godot 이식에 쓰는 데이터를 뽑아 assets/data/*.json 으로 저장합니다.

    python3 tools/extract/extract_data.py /path/to/sjrpg            # 전부
    python3 tools/extract/extract_data.py /path/to/sjrpg --only skills,gear

생성물
  skills.json     스킬 카탈로그(전사·마법사), 트리 배치, 아이콘 경계   ← lib/src/models/*_catalog.dart, ui/skill_tree_layout.dart, rendering/*_icon_art.dart
  gear.json       장비 카탈로그                                            ← lib/src/models/rpg_model.dart (gearCatalog)
  village.json    제1장 마을 실측(스프라이트·바닥 접점·배치·성문·다리)     ← lib/src/rendering/forest_isometric_frames.dart
  landmarks.json  지형 랜드마크 윗면·절벽·구조물                           ← forestIsometricTerraces

원본이 바뀌면 이 스크립트를 다시 돌려 차이를 확인합니다. 예배당은 원본 원화가 ±30° 기준을 벗어나 새로 생성한
원화(assets/source/chapel-new.png)를 쓰므로 Dart가 아니라 chapel.py(측정값 chapel_measure.json)에서 village.json에 합칩니다
(docs/chapel-regeneration.md).
"""
import json
import math
import re
import sys
from pathlib import Path

import chapel
import gate


def balanced(text, start, open_c="(", close_c=")"):
    depth = 0
    for k in range(start, len(text)):
        if text[k] == open_c:
            depth += 1
        elif text[k] == close_c:
            depth -= 1
            if depth == 0:
                return text[start : k + 1], k + 1
    raise ValueError("unbalanced")


# ───────────────────────── skills ─────────────────────────
def skill_catalog(path):
    s = path.read_text()
    out = []
    for m in re.finditer(r"SkillDef\((.*?)\n  \),", s, re.S):
        body = m.group(1)
        q = r"(?:\"((?:[^\"\\]|\\.)*)\"|'((?:[^'\\]|\\.)*)')"
        strs = [a or b for a, b in re.findall(q, body)]
        rest = re.sub(q, "S", body)
        req = {}
        rm = re.search(r"requires:\s*\{(.*?)\}", body, re.S)
        if rm:
            for k, v in re.findall(r"[\"'](\w+)[\"']\s*:\s*(\d+)", rm.group(1)):
                req[k] = int(v)
            rest = re.sub(r"requires:\s*\{.*?\}", "", rest, flags=re.S)
        parts = [p.strip() for p in rest.split(",") if p.strip()]
        pos = [p for p in parts if ":" not in p]
        named = {p.split(":")[0].strip(): p.split(":")[1].strip() for p in parts if ":" in p}
        nums = [float(x) for x in pos if x != "S"]
        out.append(dict(id=strs[0], name=strs[1], branch=strs[2], desc=strs[3], level=int(nums[0]), cost=nums[1],
                        cooldown=nums[2], limit=int(named.get("rankLimit", 5)), passive=named.get("passive") == "true",
                        basic=named.get("basic") == "true", mobility=named.get("mobility") == "true", requires=req))
    return out


def tree_rows(src, name):
    s = (src / "lib/src/ui/skill_tree_layout.dart").read_text()
    block = re.search(r"const " + name + r" = <List<SkillTreeSlot>>\[(.*?)\n\];", s, re.S).group(1)
    return [[[i, int(float(c))] for i, c in re.findall(r"id: '(\w+)', column: ([\d.]+)", row)] for row in re.findall(r"\[(.*?)\]", block, re.S)]


def icon_bounds(path):
    s = path.read_text()
    ids = re.findall(r"'(\w+)',", re.search(r"static const ids = \[(.*?)\];", s, re.S).group(1))
    b = [[float(x) for x in r] for r in re.findall(r"Rect\.fromLTRB\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)", s)]
    return dict(zip(ids, b))


def extract_skills(src, out):
    m = src / "lib/src/models"
    r = src / "lib/src/rendering"
    data = {
        "warrior": {"skills": skill_catalog(m / "barbarian_catalog.dart"), "rows": tree_rows(src, "_warriorRows"),
                    "schools": ["함성", "전투 숙련", "전투 기술"], "icons": icon_bounds(r / "barbarian_icon_art.dart")},
        "mage": {"skills": skill_catalog(m / "sorceress_catalog.dart"), "rows": tree_rows(src, "_mageRows"),
                 "schools": ["냉기 주문", "번개 주문", "화염 주문"], "icons": icon_bounds(r / "sorceress_icon_art.dart")},
    }
    (out / "skills.json").write_text(json.dumps(data, ensure_ascii=False, indent=1))
    print("skills.json", {k: len(v["skills"]) for k, v in data.items()})


# ───────────────────────── gear ─────────────────────────
def extract_gear(src, out):
    s = (src / "lib/src/models/rpg_model.dart").read_text()
    i = s.index("const gearCatalog = <GearDef>[")
    block = s[i : s.index("\n];", i)]
    items, pos = [], 0
    while True:
        m = re.search(r"GearDef\(", block[pos:])
        if not m:
            break
        start = pos + m.end()
        depth, k = 1, start
        while depth:
            depth += (block[k] == "(") - (block[k] == ")")
            k += 1
        inner, pos = block[start : k - 1], k
        gid, name, slot, rest = re.match(r"\s*'([\w-]+)',\s*'([^']+)',\s*GearSlot\.(\w+)(.*)", inner, re.S).groups()
        d = dict(id=gid, name=name, slot=slot, cls=None, attack=0.0, armor=0.0, health=0.0, mana=0.0, haste=0.0,
                 range=115.0, tempo=0.34, style="sword", value=25)
        for kk, v in re.findall(r"(\w+):\s*([^,\n]+)", rest):
            v = v.strip()
            if kk == "heroClass":
                d["cls"] = v.split(".")[1]
            elif kk == "style":
                d["style"] = v.strip("'")
            elif kk == "value":
                d["value"] = int(v)
            elif kk in d:
                d[kk] = float(v)
        items.append(d)
    (out / "gear.json").write_text(json.dumps(items, ensure_ascii=False, indent=1))
    print("gear.json", len(items))


# ───────────────────────── village (stage 1 measured data) ─────────────────────────
def extract_village(src, out):
    text = (src / "lib/src/rendering/forest_isometric_frames.dart").read_text().replace("IsometricTileGrid.pavingStoneSide", "24")
    num = r"(-?[\d.]+(?:\s*\*\s*[\d.]+)?)"
    ev = lambda x: eval(x)  # noqa: S307 - only digits and '*' reach here

    def offs(t):
        return [[ev(a), ev(b)] for a, b in re.findall(r"Offset\(\s*" + num + r",\s*" + num + r"\)", t)]

    i = text.index("const forestIsometricSprites")
    j = text.index("\n};", i)
    sprites = {}
    for m in re.finditer(r"'([\w-]+)': IsometricSprite\((.*?)\n  \),", text[i:j], re.S):
        k, b = m.group(1), m.group(2)
        sheet = re.search(r"'([\w-]+)'", b).group(1)
        r = [ev(x) for x in re.search(r"Rect\.fromLTWH\(" + num + r",\s*" + num + r",\s*" + num + r",\s*" + num + r"\)", b).groups()]
        o = offs(b)
        rest = re.sub(r"Rect\.fromLTWH\([^)]*\)", "", b)
        rest = re.sub(r"Offset\([^)]*\)", "", rest)
        rest = re.sub(r"'[\w-]+'", "", rest)
        pos = [p.strip() for p in rest.split(",") if p.strip() and ":" not in p]
        named = {p.split(":")[0].strip(): p.split(":")[1].strip() for p in rest.split(",") if ":" in p}
        body = re.search(r"body:\s*Rect\.fromLTWH\(" + num + r",\s*" + num + r",\s*" + num + r",\s*" + num + r"\)", b)
        sprites[k] = dict(sheet=sheet, source=r, foot=o[0], height=ev(pos[0]), origin=o[1], packing=ev(pos[1]),
                          world_height=ev(named.get("worldHeight", "0")), body=[ev(x) for x in body.groups()] if body else None,
                          gvs=ev(named.get("groundVerticalScale", "1")), gvk=ev(named.get("groundVerticalSkew", "0")))
    i = text.index("const forestIsometricTownFrames")
    j = text.index("\n};", i)
    frames = {}
    for m in re.finditer(r"'([\w-]+)': \((.*?)\n  \),", text[i:j], re.S):
        g = re.search(r"ground: \[(.*?)\]", m.group(2), re.S)
        frames[m.group(1)] = {"ground": offs(g.group(1)), "height": ev(re.search(r"height: " + num, m.group(2)).group(1)), "foot": offs(m.group(2))[0]}

    def mapoff(name):
        a = text.index("const " + name)
        b = text.index("\n};", a)
        return {k: [ev(x), ev(y)] for k, x, y in re.findall(r"'([\w-]+)': Offset\(" + num + r",\s*" + num + r"\)", text[a:b])}

    a = text.index("const forestIsometricPlacements")
    b = text.index("\n};", a)
    place = {k: [[ev(x), ev(y)], ev(h)] for k, x, y, h in re.findall(r"'([\w-]+)': \(Offset\(" + num + r",\s*" + num + r"\),\s*" + num + r"\)", text[a:b])}
    a = text.index("const forestIsometricGateContacts")
    gc = [offs(x) for x in re.findall(r"\[(Offset[^\]]*)\]", text[a : text.index("\n];", a)])]
    data = dict(sprites=sprites, frames=frames, placements=place, approaches=mapoff("forestIsometricApproaches"),
                gate_contacts=gc, gate_centers=[[.5, .10], [.5, .90], [.04, .5], [.94, .5]],
                wall_runs=[[[.475, .10], [.04, .10], [.04, .475]], [[.04, .525], [.04, .90], [.475, .90]],
                           [[.525, .10], [.94, .10], [.94, .475]], [[.94, .525], [.94, .90], [.525, .90]]],
                extent=2400, spawn_uv=[.5, .525], chest_uv=[[.44, .62], [.36, .43], [.65, .43], [.47, .72], [.57, .25]])
    # 원본 chapel 항목은 ±30°를 벗어나 쓰지 않는다. 새 원화는 chapel.py가 합친다(시트 패킹: `python3 tools/extract/chapel.py`).
    for section in ("sprites", "frames", "placements", "approaches"):
        data[section].pop("chapel", None)
    chapel.merge(data)
    # 원본 성문(gate-*, gate_contacts)은 얇은 기둥 문이라 새 쌍탑 문루 원화로 바꾼다(`python3 tools/extract/gate.py`).
    gate.merge(data)
    import town_art
    town_art.merge(data)
    import tree_art
    tree_art.merge(data)
    import cave_art
    cave_art.merge(data)
    (out / "village.json").write_text(json.dumps(data, indent=1))
    print("village.json", len(sprites), "sprites (+ chapel, gates from chapel.py, gate.py)")


# ───────────────────────── landmarks ─────────────────────────
def extract_landmarks(src, out):
    text = (src / "lib/src/rendering/forest_isometric_frames.dart").read_text()
    i = text.index("const forestIsometricTerraces")
    b = text[i : text.index("const forestIsometricMaterials")]

    def offs(t):
        return [[float(a), float(c)] for a, c in re.findall(r"Offset\(\s*(-?[\d.]+),\s*(-?[\d.]+)\)", t)]

    def polys(t):
        res, pos = [], 1
        while True:
            m = t.find("[", pos)
            if m < 0:
                return res
            blk, pos = balanced(t, m, "[", "]")
            res.append(offs(blk))

    entries, pos = [], 0
    while True:
        m = re.search(r"LandmarkTerrace\(", b[pos:])
        if not m:
            break
        blk, pos2 = balanced(b, pos + m.end() - 1)
        entries.append(blk[1:-1])
        pos = pos2
    result = []
    for e in entries:
        ob, end = balanced(e, e.index("["), "[", "]")
        entrance = int(re.match(r"\s*,\s*(\d+)", e[end:]).group(1))

        def key(k):
            if k + ":" not in e:
                return []
            st = e.index("[", e.index(k + ":") + len(k) + 1)
            return polys(balanced(e, st, "[", "]")[0])

        result.append(dict(outline=offs(ob), entrance=entrance, faces=key("faces"), solids=key("solids"), water=key("water")))
    import landmark_art
    landmark_art.merge(result)
    (out / "landmarks.json").write_text(json.dumps(result))
    print("landmarks.json", len(result))


STEPS = {"skills": extract_skills, "gear": extract_gear, "village": extract_village, "landmarks": extract_landmarks}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    src = Path(args[0])
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = a.split("=", 1)[1].split(",")
    out = Path(__file__).resolve().parents[2] / "assets" / "data"
    for name, fn in STEPS.items():
        if only is None or name in only:
            fn(src, out)


if __name__ == "__main__":
    main()
