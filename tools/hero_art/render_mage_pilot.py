"""Twelve-frame non-shipping material pilot adapted from sjrpg render-mage.py.

Preserve its CC0 rig, source poses, camera, projected ground origin and body scale.
Cloth slots retain their source colour blocks; generated weave adds shallow detail.
The two original constant-colour robe panels also gain stable rest-space UVs.
Original source models remain outside the repository. No runtime installation occurs.
"""
import hashlib
import json
import math
import os
from pathlib import Path

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

ROOT = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-character-source"))
RENDER_CELL = int(os.environ.get("SJRPG_RENDER_CELL", "256"))
PILOT_MODE = os.environ.get("SJRPG_MATERIAL_PILOT_MODE", "candidate")
if PILOT_MODE not in ("baseline", "candidate", "ranger", "clean", "production", "collision", "clearance"):
    raise ValueError("Unknown material mode; expected baseline, candidate, ranger, clean or explicit production")
PROJECT = Path(__file__).resolve().parents[2]
MATERIAL_PATH = PROJECT / "assets/source/hero-materials/navy-cloth.png"
source_contract = json.loads(Path(__file__).with_name("source-provenance.json").read_text())["sourceFiles"]
for relative, record in source_contract.items():
    path = ROOT / relative
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
        raise RuntimeError("Missing or changed reviewed CC0 source: " + relative + "; run fetch_sources.py first")
MATERIAL_SHA = hashlib.sha256(MATERIAL_PATH.read_bytes()).hexdigest()
OUT = ROOT / "mage-material-pilot" / PILOT_MODE
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(
    filepath=str(ROOT / "adult-source/mage/Male_Peasant-matte.gltf")
)
rig = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
rig.name = "MageRig"
visible = set(
    o
    for o in bpy.data.objects
    if o.type == "MESH" and o.name.startswith("Male_Peasant")
)
# Same free CC0 Ranger hood, rest-bound once to the Peasant's male Head bone.
beforeHood = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "adult-source/Male_Ranger-matte.gltf"))
hoodRig = next(
    o for o in bpy.data.objects if o not in beforeHood and o.type == "ARMATURE"
)
hood = next(
    o
    for o in bpy.data.objects
    if o not in beforeHood and o.name.startswith("Male_Ranger_Head_Hood")
)
hoodMap = (
    rig.data.bones["Head"].matrix_local
    @ hoodRig.data.bones["Head"].matrix_local.inverted()
)
for v in hood.data.vertices:
    v.co = hoodMap @ (hood.matrix_world @ v.co)
for modifier in list(hood.modifiers):
    hood.modifiers.remove(modifier)
hood.parent = rig
hood.parent_type = "BONE"
hood.parent_bone = "Head"
hb = rig.data.bones["Head"]
hood.matrix_parent_inverse = (
    rig.matrix_world @ hb.matrix_local @ Matrix.Translation((0, hb.length, 0))
).inverted()
hood.matrix_basis = Matrix.Identity(4)
visible.add(hood)
if PILOT_MODE in ("ranger", "clean", "production", "collision", "clearance"):
    # The reviewed free Ranger's 65 joint inverse-bind matrices exactly match
    # Peasant's. Transfer its existing full-sleeve body/arms without new geometry,
    # reskinning, pose edits or changes to the male head/boots/legs.
    for name, target in rig.data.bones.items():
        if name in hoodRig.data.bones:
            original = hoodRig.data.bones[name]
            error = max(abs(target.matrix_local[row][column] - original.matrix_local[row][column])
                        for row in range(4) for column in range(4))
            if error > 1e-6:
                raise RuntimeError("Ranger rest binding differs: " + name)
    for obj in list(visible):
        if obj.name in ("Male_Peasant_Body", "Male_Peasant_Arms"):
            visible.remove(obj)
    for obj in bpy.data.objects:
        if obj.name not in ("Male_Ranger_Body", "Male_Ranger_Arms"):
            continue
        world = obj.matrix_world.copy()
        obj.parent = rig
        obj.matrix_world = world
        for modifier in obj.modifiers:
            if modifier.type == "ARMATURE":
                modifier.object = rig
        visible.add(obj)
# Outfit packs deliberately omit the face: attach the official male base head.
# Trim once in rest coordinates and rigidly bind to Head; no per-pose corrections.
beforeBase = set(bpy.data.objects)
bpy.ops.import_scene.gltf(
    filepath=str(ROOT / "adult-source/base/Superhero_Male-matte.gltf")
)
baseRig = next(
    o for o in bpy.data.objects if o not in beforeBase and o.type == "ARMATURE"
)
sourceHead = baseRig.data.bones["Head"]
targetHead = rig.data.bones["Head"]
headMap = targetHead.matrix_local @ sourceHead.matrix_local.inverted()
headCut = sourceHead.head_local.z - 0.08
headExtraction = []

for o in list(bpy.data.objects):
    if o in beforeBase or o.type != "MESH" or o.name.startswith("Icosphere"):
        continue
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    audit = {"sourceObject": o.name, "heightRetained": 0, "retainedHeadNeck": 0,
             "headNeckDominantBefore": 0, "headNeckDominantAfter": 0,
             "oldWrongShoulder": 0, "removedWrongShoulder": 0,
             "removedBodyFragments": 0, "maximumRemovedHeadNeckWeight": 0.0}
    anatomical = {group.index for group in o.vertex_groups if group.name in ("Head", "neck_01")}
    remove = []
    for vertex in bm.verts:
        original = o.data.vertices[vertex.index]
        at = o.matrix_world @ vertex.co
        if at.z < headCut:
            remove.append(vertex)
            continue
        influence = sum(group.weight for group in original.groups if group.group in anatomical)
        audit["heightRetained"] += 1
        audit["headNeckDominantBefore"] += int(influence >= 0.5)
        wrong_shoulder = abs(at.x) > 0.16
        audit["oldWrongShoulder"] += int(wrong_shoulder)
        # Verified source separation: all 34 wide shoulder vertices have <=.0393
        # Head+Neck influence. The 14 remaining collar scraps are clavicle .81+,
        # with Head+Neck <=.0906. A .10 influence gate keeps the actual neck/head
        # and all face meshes, rather than rigidly attaching chest scraps to Head.
        discard = PILOT_MODE in ("clean", "production", "collision", "clearance") and influence <= 0.10
        if discard:
            remove.append(vertex)
            audit["removedBodyFragments"] += 1
            audit["removedWrongShoulder"] += int(wrong_shoulder)
            audit["maximumRemovedHeadNeckWeight"] = max(audit["maximumRemovedHeadNeckWeight"], influence)
        else:
            audit["retainedHeadNeck"] += 1
            audit["headNeckDominantAfter"] += int(influence >= 0.5)
    if PILOT_MODE in ("clean", "production", "collision", "clearance"):
        assert audit["headNeckDominantBefore"] == audit["headNeckDominantAfter"], "Lost actual head/neck vertices"
        assert audit["oldWrongShoulder"] == audit["removedWrongShoulder"], "Retained a rigid shoulder fragment"
    headExtraction.append(audit)
    bmesh.ops.delete(bm, geom=remove, context="VERTS")
    if not bm.verts:
        bm.free()
        o.hide_render = True
        continue
    for v in bm.verts:
        v.co = headMap @ (o.matrix_world @ v.co)
    bm.to_mesh(o.data)
    bm.free()
    for modifier in list(o.modifiers):
        o.modifiers.remove(modifier)
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = "Head"
    o.matrix_parent_inverse = (
        rig.matrix_world
        @ targetHead.matrix_local
        @ Matrix.Translation((0, targetHead.length, 0))
    ).inverted()
    o.matrix_basis = Matrix.Identity(4)
    visible.add(o)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "adult-source/UAL1_Standard.glb"))
for o in bpy.data.objects:
    if o.type == "MESH":
        o.hide_render = o not in visible
    if o.animation_data:
        for t in o.animation_data.nla_tracks:
            t.mute = True
rig.animation_data_create()
yaw = bpy.data.objects.new("FacingYaw", None)
bpy.context.scene.collection.objects.link(yaw)
rig.parent = yaw
def cloth_detail(material, original_color):
    """Use source UV0 unchanged; scalar weave preserves source buckles/colour blocks."""
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    image = nodes.new("ShaderNodeTexImage")
    image.name = "Generated navy weave on original rest UV"
    image.image = bpy.data.images.load(str(MATERIAL_PATH), check_existing=True)
    image.interpolation = "Linear"
    image.extension = "REPEAT"
    grey = nodes.new("ShaderNodeRGBToBW")
    links.new(image.outputs["Color"], grey.inputs["Color"])
    normalized = nodes.new("ShaderNodeMath")
    normalized.operation = "MULTIPLY"
    normalized.inputs[1].default_value = 41.0
    links.new(grey.outputs[0], normalized.inputs[0])
    detail = nodes.new("ShaderNodeMixRGB")
    detail.blend_type = "MULTIPLY"
    detail.inputs[0].default_value = 0.30
    links.new(original_color, detail.inputs[1])
    links.new(normalized.outputs[0], detail.inputs[2])
    bsdf = nodes.get("Principled BSDF")
    links.new(detail.outputs[0], bsdf.inputs["Base Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.12
    bump.inputs["Distance"].default_value = 0.0015
    links.new(normalized.outputs[0], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


# One global material treatment, retained across every direction/frame.
# Keep source skin texture and leather detail; hood gets muted teal cloth tint.
for o in visible:
    for p in o.data.polygons:
        p.use_smooth = True
    if "Hood" in o.name or (o.name.startswith("Male_Peasant") and "Feet" not in o.name) or (PILOT_MODE in ("ranger", "clean", "production", "collision", "clearance") and o.name in ("Male_Ranger_Body", "Male_Ranger_Arms")):
        for slot in o.material_slots:
            if slot.material and (
                slot.material.name.startswith("MI_Ranger")
                or slot.material.name.startswith("MI_Peasant")
            ):
                material = slot.material.copy()
                slot.material = material
                bsdf = next(
                    n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"
                )
                tex = bsdf.inputs["Base Color"].links[0].from_socket
                color = material.node_tree.nodes.new("ShaderNodeMixRGB")
                color.blend_type = "COLOR"
                color.inputs[0].default_value = 0.94
                color.inputs[2].default_value = (0.025, 0.07, 0.16, 1)
                material.node_tree.links.new(tex, color.inputs[1])
                shade = material.node_tree.nodes.new("ShaderNodeHueSaturation")
                shade.inputs["Saturation"].default_value = 0.75
                if PILOT_MODE != "baseline":
                    shade.inputs["Value"].default_value = 0.62 if "Hood" in o.name else 0.50
                else:
                    shade.inputs["Value"].default_value = 0.48 if "Hood" in o.name else 0.28
                material.node_tree.links.new(color.outputs[0], shade.inputs["Color"])
                material.node_tree.links.new(
                    shade.outputs[0], bsdf.inputs["Base Color"]
                )
                if PILOT_MODE != "baseline":
                    cloth_detail(material, shade.outputs[0])


# Original simple low-poly sword geometry, no borrowed/runtime asset.
def mat(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = 0.9
    return m


wood = mat("Original mage wand wood", (0.12, 0.075, 0.045))
crystal = mat("Original quiet blue crystal", (0.12, 0.30, 0.40))
robeMat = mat("Original navy robe panels", (0.018, 0.044, 0.085))
# These two panels have no source colour atlas. Skin/face/boots never use this map.
if PILOT_MODE != "baseline":
    nodes = robeMat.node_tree.nodes
    cloth = nodes.new("ShaderNodeTexImage")
    cloth.name = "Reviewed generated navy cloth albedo"
    cloth.image = bpy.data.images.load(str(MATERIAL_PATH), check_existing=True)
    cloth.interpolation = "Linear"
    cloth.extension = "REPEAT"
    bsdf = nodes.get("Principled BSDF")
    exposure = nodes.new("ShaderNodeHueSaturation")
    exposure.inputs["Value"].default_value = 1.5
    robeMat.node_tree.links.new(cloth.outputs["Color"], exposure.inputs["Color"])
    robeMat.node_tree.links.new(exposure.outputs["Color"], bsdf.inputs["Base Color"])
    relief = nodes.new("ShaderNodeBump")
    relief.inputs["Strength"].default_value = 0.12
    relief.inputs["Distance"].default_value = 0.0015
    robeMat.node_tree.links.new(cloth.outputs["Color"], relief.inputs["Height"])
    robeMat.node_tree.links.new(relief.outputs["Normal"], bsdf.inputs["Normal"])
sword = bpy.data.objects.new("OriginalWandGrip", None)
bpy.context.scene.collection.objects.link(sword)
sword.parent = rig
sword.parent_type = "BONE"
sword.parent_bone = "hand_r"
sword.location = (0, -rig.data.bones["hand_r"].length, 0)
bpy.ops.mesh.primitive_cylinder_add(
    vertices=8, radius=0.015, depth=0.45, location=(0, 0, 0)
)
wand = bpy.context.object
wand.name = "OriginalMageWand"
wand.parent = sword
wand.location = (0, 0, 0.17)
wand.data.materials.append(wood)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.042, location=(0, 0, 0))
tip = bpy.context.object
tip.name = "OriginalSmallWandCrystal"
tip.parent = sword
tip.location = (0, 0, 0.415)
tip.scale = (0.75, 0.75, 1.5)
tip.data.materials.append(crystal)
# Two side panels form a split-front robe, skinned once to pelvis/thighs.
# Actual bone deformation articulates the cloth; no image/frame corrections.
for side, angles in [
    ("left", [-68, -35, 0, 35, 68]),
    ("right", [112, 145, 180, 215, 248]),
]:
    verts = []
    faces = []
    for ring, (z, rx, ry) in enumerate(
        [(0.94, 0.20, 0.135), (0.65, 0.245, 0.17), (0.32, 0.29, 0.205)]
    ):
        for deg in angles:
            a = math.radians(deg)
            point = Vector((rx * math.cos(a), ry * math.sin(a), z))
            if PILOT_MODE == "clearance":
                # A measured rest-fit margin only. Keep the original sparse
                # topology, UV registration and authored skin weights unchanged.
                point += Vector((point.x, point.y, 0)).normalized() * 0.018
            verts.append(tuple(point))
    for ring in range(2):
        for col in range(4):
            i = ring * 5 + col
            faces.append((i, i + 1, i + 6, i + 5))
    mesh = bpy.data.meshes.new("OriginalRobePanel-" + side)
    mesh.from_pydata(verts, [], faces)
    # Mechanical rest-space registration only: no image painting or geometry
    # changes. The armature deforms the same UVs in every direction and pose.
    uv = mesh.uv_layers.new(name="ClothRestUV")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            row, column = divmod(vertex_index, 5)
            uv.data[loop_index].uv = (column / 4.0 * 0.30, (1.0 - row / 2.0) * 0.45)
    o = bpy.data.objects.new("OriginalNavyRobe-" + side, mesh)
    bpy.context.scene.collection.objects.link(o)
    o.parent = rig
    o.data.materials.append(robeMat)
    pelvis = o.vertex_groups.new(name="pelvis")
    legName = (
        "thigh_l"
        if (side == "left") == (rig.data.bones["thigh_l"].head_local.x > 0)
        else "thigh_r"
    )
    leg = o.vertex_groups.new(name=legName)
    for i in range(15):
        weight = [0, 0.45, 0.8][i // 5]
        pelvis.add([i], 1 - weight, "REPLACE")
        leg.add([i], weight, "REPLACE")
    mod = o.modifiers.new("SameRigClothSkin", "ARMATURE")
    mod.object = rig
    solid = o.modifiers.new("ThinClothEdge", "SOLIDIFY")
    solid.thickness = 0.006
if PILOT_MODE == "collision":
    # Existing sparse quads allow source trouser surfaces to pass through their
    # interiors. Sample the same surface more densely, move ONLY inside samples
    # outside the evaluated Legs, then apply the existing thin cloth thickness.
    for cloth in [obj for obj in bpy.data.objects if obj.name.startswith("OriginalNavyRobe-")]:
        bpy.context.view_layer.objects.active = cloth
        sampling = cloth.modifiers.new("ExistingClothSurfaceSamples", "SUBSURF")
        sampling.subdivision_type = "SIMPLE"
        sampling.levels = sampling.render_levels = 2
        bpy.ops.object.modifier_move_up(modifier=sampling.name)
        collision = cloth.modifiers.new("OutsideOriginalLegsOnly", "SHRINKWRAP")
        collision.target = bpy.data.objects["Male_Peasant_Legs"]
        collision.wrap_method = "NEAREST_SURFACEPOINT"
        collision.wrap_mode = "OUTSIDE"
        collision.offset = 0.008
        bpy.ops.object.modifier_move_up(modifier=collision.name)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = False
scene.render.threads_mode = "FIXED"
scene.render.threads = 2
scene.render.resolution_x = RENDER_CELL
scene.render.resolution_y = RENDER_CELL
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.fps = 30
scene.render.use_persistent_data = True
scene.world = bpy.data.worlds.new("World")
scene.world.color = (0.22, 0.22, 0.22)
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
bpy.ops.object.camera_add(location=(0, -6, 5.1))
cam = bpy.context.object
cam.rotation_euler = (
    (Vector((0, 0, 0.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
)
cam.data.type = "ORTHO"
cam.data.ortho_scale = 3.6
scene.camera = cam
for name, pos, power, size in [
    ("Key", (-3, -4, 6), 360, 5),
    ("Fill", (4, -1, 4), 130, 4),
    ("Rim", (0, 4, 5), 120, 3),
]:
    bpy.ops.object.light_add(type="AREA", location=pos)
    o = bpy.context.object
    o.name = name
    o.data.energy = power
    o.data.shape = "DISK"
    o.data.size = size
    o.rotation_euler = (
        (Vector((0, 0, 1)) - o.location).to_track_quat("-Z", "Y").to_euler()
    )
origin = world_to_camera_view(scene, cam, Vector((0, 0, 0)))
m = {
    "source": "Quaternius CC0 Male_Peasant + Ranger hood + male base head + UAL1_Standard",
    "sourceType": "adult male navy-robed mage",
    "headSource": "official CC0 Superhero_Male, head-only rest trim; no per-pose changes",
    "headRestMap": [list(row) for row in headMap],
    "headRestCutoffZ": headCut,
    "headExtraction": {"method": "source Head+Neck influence >.10 after original rest-height cut" if PILOT_MODE in ("clean", "production", "collision", "clearance") else "original rest-height cut only", "objects": headExtraction},
    "cellSize": [RENDER_CELL, RENDER_CELL],
    "worldOriginAnchorPx": [origin.x * RENDER_CELL, (1 - origin.y) * RENDER_CELL],
    "orthoScale": cam.data.ortho_scale,
    "cameraLocation": list(cam.location),
    "target": [0, 0, 0.9],
    "cameraRotation": list(cam.rotation_euler),
    "fixedObjectScale": list(rig.scale),
    "directions": {"E": 90, "SE": 45},
    "actions": {},
    "frames": [],
    "globalMaterialTreatment": "source baseColor, constant roughness.95/metal0, headhood muted teal multiply.72; smooth source normals",
    "originalSword": "procedural .45m wooden wand/quietblue crystal; splitnavyrobe sidepanels skinnedto pelvis/thighs, no paidoutfit",
}
# A new pose/material contract must never reuse older two-pose PNGs.
bake_key = hashlib.sha256(Path(__file__).read_bytes() + json.dumps(source_contract, sort_keys=True).encode() + MATERIAL_SHA.encode() + PILOT_MODE.encode()).hexdigest()[:16]
FRAME_DIR = OUT / "frames" / bake_key
FRAME_DIR.mkdir(parents=True, exist_ok=True)
m["bakeContract"] = bake_key


labels = [
    "S",
    "SSW",
    "SW",
    "WSW",
    "W",
    "WNW",
    "NW",
    "NNW",
    "N",
    "NNE",
    "NE",
    "ENE",
    "E",
    "ESE",
    "SE",
    "SSE",
]
m["offlineBakePersistentData"] = True
m["samples"] = 32
m["renderThreads"] = 2
m["directions"] = {label: -22.5 * i for i, label in enumerate(labels)}
m["sourceImportFPS"] = 30
m["class"] = "mage"
m["actorReferenceHeightRaw256"] = 152 * 3.1 / 3.6
m["runtimeExportScale"] = 0.5
m["motion"] = {
    "directions": 16,
    "runFrames": 8,
    "idleOffset": 0,
    "runOffset": 16,
    "layout": "phase-major",
}
m["globalMaterialTreatment"] = (
    "FreePeasantcloth+Rangerhood navyCOLOR tint, sourceSkin/brownfeetunchanged, roughness.95; original splitnavyrobe follows actuallegbones"
)
jobs = []
for d in range(16):
    jobs.append(("mage", "idle", d, 0, "Idle_Loop_Armature", 0))
for p in range(8):
    for d in range(16):
        jobs.append(("mage", "run", d, p, "Sprint_Loop_Armature", p / 8))
samples = [("Spell_Simple_Enter_Armature", n) for n in [.05, .38, .78]] + [("Spell_Simple_Shoot_Armature", n) for n in [.12, .48, .82]] + [("Spell_Simple_Exit_Armature", n) for n in [.42, .88]]
for p, (action, norm) in enumerate(samples):
    for d in range(16):
        jobs.append(("mage-cast", "cast", d, p, action, norm))
for p in range(4):
    for d8 in range(8):
        jobs.append(("roll-mage", "roll", d8 * 2, p, "Roll_Armature", p / 4))
# The explicit production trial contains only Godot's idle/run/cast roles, never
# the unused roll/mount jobs. All default modes remain small non-shipping pilots.
if PILOT_MODE in ("collision", "clearance"):
    jobs = [job for job in jobs if (job[1] == "idle" and job[2] == 0) or
            (job[1] == "run" and job[2] == 0 and job[3] in (1, 5)) or
            (job[1] == "cast" and job[2] == 4 and job[3] in (2, 3, 4, 5))]
    assert len(jobs) == 7
elif PILOT_MODE == "production":
    jobs = [job for job in jobs if job[1] in ("idle", "run", "cast")]
    assert len(jobs) == 272
else:
    jobs = [job for job in jobs if (job[1] == "idle" and job[2] in (0, 4, 8, 12)) or (PILOT_MODE != "ranger" and job[1] == "run" and job[2] == 0)]
    assert len(jobs) == (4 if PILOT_MODE == "ranger" else 12)
m["pilot"] = {"mode": PILOT_MODE, "source": str(MATERIAL_PATH.relative_to(PROJECT)), "sha256": MATERIAL_SHA, "frameCount": len(jobs), "adoptedInRuntime": False,
              "sourceBody": "official Ranger body/arms, same joint bindings" if PILOT_MODE in ("ranger", "clean", "production", "collision", "clearance") else "original Peasant body/arms",
              "unchanged": ["male head", "skin materials", "Peasant boots/legs", "wand", "rig", "pose sampling", "camera", "projected origin"],
              "clothDetail": "source colour/UV preserved with generated luminance modulation + shallow bump; two original robe panels use generated albedo" if PILOT_MODE != "baseline" else "original source treatment"}
if PILOT_MODE in ("clean", "production", "collision", "clearance"):
    assert sum(part["oldWrongShoulder"] for part in headExtraction) > 0
    assert sum(part["removedWrongShoulder"] for part in headExtraction) == sum(part["oldWrongShoulder"] for part in headExtraction)
for jobIndex, (sheet, kind, d, phase, actionName, norm) in enumerate(jobs):
    direction = labels[d]
    angle = -22.5 * d
    yaw.rotation_euler.z = math.radians(angle)
    action = next(a for a in bpy.data.actions if a.name.startswith(actionName))
    rig.animation_data.action = action
    start, end = action.frame_range
    m["actions"][actionName] = {
        "actualActionName": action.name,
        "frameRange": [start, end],
        "sourceSeconds": (end - start) / 30,
    }
    frame = start + (end - start) * norm
    scene.frame_set(int(frame), subframe=frame - int(frame))
    bpy.context.view_layer.update()
    bones = {}
    for name in ["root", "pelvis", "Head", "foot_l", "foot_r", "hand_l", "hand_r"]:
        b = rig.pose.bones[name]
        w = rig.matrix_world @ b.head
        p = world_to_camera_view(scene, cam, w)
        bones[name] = {"world": list(w), "pixel": [p.x * RENDER_CELL, (1 - p.y) * RENDER_CELL]}
    head = rig.pose.bones["Head"]
    localGaze = rig.data.bones["Head"].matrix_local.to_3x3().inverted() @ Vector(
        (0, -1, 0)
    )
    worldGaze = rig.matrix_world.to_3x3() @ head.matrix.to_3x3() @ localGaze
    headWorld = rig.matrix_world @ head.head
    gazePoint = world_to_camera_view(scene, cam, headWorld + 0.25 * worldGaze)
    bones["projectedGaze"] = {
        "worldDirection": list(worldGaze),
        "pixelDelta": [
            (gazePoint.x * RENDER_CELL) - bones["Head"]["pixel"][0],
            ((1 - gazePoint.y) * RENDER_CELL) - bones["Head"]["pixel"][1],
        ],
    }
    # Optional native-pixel sockets for later muzzle/contact validation. These
    # come from evaluated pose bones and the same orthographic camera/origin,
    # never guessed body-height offsets or painted sprite landmarks.
    graph = bpy.context.evaluated_depsgraph_get()
    evaluated_rig = rig.evaluated_get(graph)
    sockets = {}
    for name in ("hand_l", "hand_r"):
        bone = evaluated_rig.pose.bones[name]
        sockets[name] = {}
        for endpoint, local in (("head", bone.head), ("tail", bone.tail)):
            world = evaluated_rig.matrix_world @ local
            projected = world_to_camera_view(scene, cam, world)
            pixel = [projected.x * RENDER_CELL, (1.0 - projected.y) * RENDER_CELL]
            sockets[name][endpoint] = {"world": list(world), "pixel": pixel,
                                       "fromProjectedOrigin": [pixel[axis] - m["worldOriginAnchorPx"][axis] for axis in (0, 1)]}
    grip = bpy.data.objects.get("OriginalWandGrip")
    if grip is not None:
        world = grip.evaluated_get(graph).matrix_world.translation
        projected = world_to_camera_view(scene, cam, world)
        pixel = [projected.x * RENDER_CELL, (1.0 - projected.y) * RENDER_CELL]
        sockets["wand_grip"] = {"world": list(world), "pixel": pixel,
                                 "fromProjectedOrigin": [pixel[axis] - m["worldOriginAnchorPx"][axis] for axis in (0, 1)]}
    path = FRAME_DIR / f"{sheet}-{kind}-d{d:02d}-p{phase}.png"
    scene.render.filepath = str(path)
    if not path.exists():
        bpy.ops.render.render(write_still=True)
    m["frames"].append(
        {
            "sheet": sheet,
            "kind": kind,
            "direction": direction,
            "directionIndex": d,
            "yawDegrees": angle,
            "phase": phase,
            "action": actionName,
            "normalizedActionTime": norm,
            "actionFrame": frame,
            "path": str(path),
            "bones": bones,
            "sockets": sockets,
        }
    )
    if jobIndex % 16 == 0 or jobIndex == len(jobs) - 1:
        (OUT / "render-metadata.json").write_text(json.dumps(m, indent=2))
        print(f"CHECKPOINT {jobIndex + 1}/{len(jobs)}", flush=True)
