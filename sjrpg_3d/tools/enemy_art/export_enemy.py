"""검증한 외부 원본을 미터/Y-up/제자리 동작의 GLB로 오프라인 변환한다."""

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

parser = argparse.ArgumentParser()
parser.add_argument("--kind", choices=["goblin", "wolf"], required=True)
parser.add_argument("--source", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
project = Path(__file__).resolve().parents[2]
lock = json.loads(
    (project / "assets/source/enemies" / args.kind / "provenance.json").read_text()
)
assert (
    hashlib.sha256(args.source.read_bytes()).hexdigest() == lock["payload_sha256"]
), "원본이 바뀜: 출처와 라이선스를 먼저 검수하세요."

if args.source.suffix == ".fbx":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(args.source.resolve()))
else:
    bpy.ops.wm.open_mainfile(filepath=str(args.source.resolve()))
scene = bpy.context.scene
source_arm = next(o for o in scene.objects if o.type == "ARMATURE")
source_objects = list(scene.objects)
source_meshes = [
    o
    for o in source_objects
    if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)
    # 원본 Neck 장식은 공격 중 몸에서 떨어져 지면으로 내려간다. 몸·발은 보존한다.
    and not (args.kind == "goblin" and o.name == "Neck")
]
source_arm.animation_data_clear()
source_arm.data.pose_position = "REST"
bpy.context.view_layer.update()
points = [o.matrix_world @ v.co for o in source_meshes for v in o.data.vertices]
minimum = Vector([min(p[i] for p in points) for i in range(3)])
maximum = Vector([max(p[i] for p in points) for i in range(3)])
height = 1.69 if args.kind == "goblin" else 1.469
ratio = height / (maximum.z - minimum.z)
# Blender -Y 정면은 glTF +Z가 된다. 원본 머리와 흉곽으로 사족보행 방향을 측정한다.
turn = 0.0
if args.kind == "wolf":
    head = source_arm.matrix_world @ source_arm.data.bones["tete"].head_local
    hip = source_arm.matrix_world @ source_arm.data.bones["bassin"].head_local
    direction = head - hip
    turn = -math.pi / 2 - math.atan2(direction.y, direction.x)
center = (minimum + maximum) * 0.5
normalizer = (
    Matrix.Scale(ratio, 4)
    @ Matrix.Rotation(turn, 4, "Z")
    @ Matrix.Translation(Vector((-center.x, -center.y, -minimum.z)))
)


def frame(matrix, divisor):
    result = matrix.copy()
    for i in range(3):
        for j in range(3):
            result[i][j] /= divisor
    if result.to_3x3().determinant() < 0:
        for i in range(3):
            result[i][0] *= -1
    return result


rest_original = {
    b.name: normalizer @ source_arm.matrix_world @ b.matrix_local
    for b in source_arm.data.bones
}
divisors = {
    name: sum(m.to_3x3().col[i].length for i in range(3)) / 3
    for name, m in rest_original.items()
}
rest = {name: frame(m, divisors[name]) for name, m in rest_original.items()}
arm_data = bpy.data.armatures.new("EnemySkeleton")
arm = bpy.data.objects.new("Rig", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for source in source_arm.data.bones:
    b = arm_data.edit_bones.new(source.name)
    # 길이가 0인 새 EditBone에는 회전 행렬이 온전히 적용되지 않는다.
    b.length = (
        normalizer.to_3x3()
        @ source_arm.matrix_world.to_3x3()
        @ (source.tail_local - source.head_local)
    ).length
    b.matrix = rest[source.name]
    b.use_deform = source.use_deform
    if source.parent:
        b.parent = arm_data.edit_bones[source.parent.name]
bpy.ops.object.mode_set(mode="OBJECT")
# EditBone이 정규화한 기준을 사용해 FK와 inverse bind를 일치시킨다.
before_rest = rest
rest = {b.name: b.matrix_local.copy() for b in arm_data.bones}
rest_error = max(
    max(
        abs(rest[name][i][j] - before_rest[name][i][j])
        for i in range(4)
        for j in range(4)
    )
    for name in rest
)
assert rest_error < 0.0001, ("기준 골격이 변형됨", rest_error)
print("REST_VERIFY", rest_error, flush=True)
for b in arm.pose.bones:
    b.rotation_mode = "QUATERNION"

body_material = bpy.data.materials.new("PaintedHide")
body_material.use_nodes = True
bsdf = body_material.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.94
tex = body_material.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = (
    bpy.data.images["gobli-tex"]
    if args.kind == "goblin"
    else bpy.data.images["Diffuse Texture"]
)
uv_node = body_material.node_tree.nodes.new("ShaderNodeUVMap")
uv_node.uv_map = "UVMap"
body_material.node_tree.links.new(uv_node.outputs["UV"], tex.inputs["Vector"])
body_material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def flat_material(name, color, metal=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = 0.85
    p.inputs["Metallic"].default_value = metal
    return mat


gold = flat_material("OldBronze", (0.38, 0.25, 0.085), 0.3)
steel = flat_material("WornSteel", (0.21, 0.23, 0.22), 0.5)
built = []
for original in source_meshes:
    mesh = original.data.copy()
    transform = normalizer @ original.matrix_world
    mesh.transform(transform)
    if transform.to_3x3().determinant() < 0:
        import bmesh

        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
    obj = bpy.data.objects.new(original.name + "_Runtime", mesh)
    scene.collection.objects.link(obj)
    for group in original.vertex_groups:
        obj.vertex_groups.new(name=group.name)
    # 복사한 메시의 정점에는 기존 그룹 인덱스와 가중치가 남아 있다.
    mesh.materials.clear()
    # 원본의 최종 atlas는 'UV'에 대응한다. 삭제 후 RNA 참조를 재사용하지 않는다.
    active_uv = mesh.uv_layers.get("UV") or mesh.uv_layers.active
    coords = [tuple(loop.uv) for loop in active_uv.data] if active_uv else None
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    if coords:
        clean_uv = mesh.uv_layers.new(name="UVMap")
        for loop, point in zip(clean_uv.data, coords):
            loop.uv = point
        clean_uv.active_render = True
    # 원본 재질에서 사용하지 않는 오래된 페인트 마스크를 glTF COLOR_0로 내보내지 않는다.
    for attr in list(mesh.color_attributes):
        mesh.color_attributes.remove(attr)
    mesh.materials.append(gold if original.name == "Ear" else body_material)
    for polygon in mesh.polygons:
        polygon.material_index = 0
        polygon.use_smooth = True
    mod = obj.modifiers.new("Skin", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    built.append(obj)

# 고블린의 짧은 칼은 손 뼈에 스킨한다. 외부 공격 동작의 손을 그대로 따른다.
if args.kind == "goblin":
    hand = rest["hand_R"]
    grip = hand.translation + hand.to_3x3().col[1] * 0.055
    blade_points = [
        Vector((-0.045, 0, 0)),
        Vector((0.045, 0, 0)),
        Vector((0.055, -0.27, -0.18)),
        Vector((0.005, -0.38, -0.25)),
        Vector((-0.04, -0.26, -0.17)),
    ]
    vertices = [
        grip + p + Vector((0, 0, side * 0.009))
        for side in [-1, 1]
        for p in blade_points
    ]
    faces = [(0, 4, 3, 2, 1), (5, 6, 7, 8, 9)] + [
        (i, (i + 1) % 5, (i + 1) % 5 + 5, i + 5) for i in range(5)
    ]
    mesh = bpy.data.meshes.new("Cleaver")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(steel)
    obj = bpy.data.objects.new("Cleaver", mesh)
    scene.collection.objects.link(obj)
    group = obj.vertex_groups.new(name="hand_R")
    group.add(list(range(len(vertices))), 1, "REPLACE")
    mod = obj.modifiers.new("Skin", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    built.append(obj)

# 같은 재질의 부품을 통합하고 골격과 스킨은 유지한다.
bpy.ops.object.select_all(action="DESELECT")
for obj in built:
    obj.select_set(True)
bpy.context.view_layer.objects.active = built[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "Body"
max_discarded = 0.0
influence_limit = 8 if args.kind == "goblin" else 4
valid_groups = {b.name for b in arm.data.bones if b.use_deform}
for vertex in body.data.vertices:
    ignored = [
        g.group
        for g in vertex.groups
        if body.vertex_groups[g.group].name not in valid_groups
    ]
    for group in ignored:
        body.vertex_groups[group].remove([vertex.index])
    groups = sorted(
        [(g.group, g.weight) for g in vertex.groups if g.weight > 0],
        key=lambda p: p[1],
        reverse=True,
    )
    total = sum(w for _, w in groups)
    max_discarded = max(
        max_discarded, sum(w for _, w in groups[influence_limit:]) / max(total, 1e-12)
    )
    for group, _ in groups[influence_limit:]:
        body.vertex_groups[group].remove([vertex.index])
    kept = sum(w for _, w in groups[:influence_limit])
    for group, weight in groups[:influence_limit]:
        body.vertex_groups[group].add(
            [vertex.index], weight / max(kept, 1e-12), "REPLACE"
        )
body.data.validate(clean_customdata=False)

source_arm.data.pose_position = "POSE"
fps_source = scene.render.fps / scene.render.fps_base
fps = 30
clips = (
    {
        "idle": ("Idle.000", None),
        "run": ("Run", None),
        "attack": ("Attack.000", None),
        "death": ("Die", None),
    }
    if args.kind == "goblin"
    else {
        k: (f"Armature|{v}|Baked frames", None)
        for k, v in [
            ("idle", "idle"),
            ("run", "run"),
            ("attack", "ATK2"),
            ("hit", "hit"),
            ("death", "death"),
        ]
    }
)
clips["hit"] = clips.get("hit", ("Idle.000", 0.30))
arm.animation_data_create()
source_arm.animation_data_create()
root_name = next(b.name for b in source_arm.data.bones if not b.parent)
records = {}
base_basis = None
for role, (source_name, custom_length) in clips.items():
    action = bpy.data.actions[source_name]
    start, end = action.frame_range
    duration = custom_length or (end - start) / fps_source
    samples = max(2, round(duration * fps))
    source_arm.animation_data.action = action
    first_root = None
    poses = []
    scores = []
    bounds = []
    first_matrices = None
    for index in range(samples + 1):
        source_frame = start + (end - start) * (0 if custom_length else index / samples)
        scene.frame_set(math.floor(source_frame), subframe=source_frame % 1)
        bpy.context.view_layer.update()
        matrices = {
            name: frame(
                normalizer
                @ source_arm.matrix_world
                @ source_arm.pose.bones[name].matrix,
                divisors[name],
            )
            for name in rest
        }
        root_at = matrices[root_name].translation.copy()
        if first_root is None:
            first_root = root_at.copy()
        shift = Vector((root_at.x - first_root.x, root_at.y - first_root.y, 0))
        evaluated = []
        for source_obj in source_meshes:
            evaluated_obj = source_obj.evaluated_get(
                bpy.context.evaluated_depsgraph_get()
            )
            evaluated.extend(
                normalizer @ evaluated_obj.matrix_world @ v.co - shift
                for v in evaluated_obj.data.vertices
            )
        bottom = min(v.z for v in evaluated)
        lift = -bottom if role in ["idle", "run", "death"] else max(0, -bottom)
        for matrix in matrices.values():
            matrix.translation += Vector((0, 0, lift)) - shift
        if first_matrices is None:
            first_matrices = {k: v.copy() for k, v in matrices.items()}
        basis = {}
        for bone in arm_data.bones:
            basis[bone.name] = (
                (
                    rest[bone.name].inverted()
                    @ rest[bone.parent.name]
                    @ matrices[bone.parent.name].inverted()
                    @ matrices[bone.name]
                )
                if bone.parent
                else rest[bone.name].inverted() @ matrices[bone.name]
            )
        if custom_length:
            t = index / samples
            strength = math.sin(t * math.pi) * 0.24
            for name in ["spine2", "spine3"]:
                basis[name] = basis[name] @ Matrix.Rotation(-strength, 4, "X")
        poses.append(basis)
        marker = "hand_R" if args.kind == "goblin" else "museau"
        scores.append(-matrices[marker].translation.y)
        bounds.append(
            [min(v.z + lift for v in evaluated), max(v.z + lift for v in evaluated)]
        )
    if base_basis is None:
        base_basis = {k: v.copy() for k, v in poses[0].items()}
    baked = bpy.data.actions.new(role)
    arm.animation_data.action = baked
    for index, basis in enumerate(poses):
        t = index / samples
        for bone in arm.pose.bones:
            matrix = basis[bone.name]
            # 공격의 양 끝은 같은 idle 자세이며 게임 시계에서 복귀가 끊기지 않는다.
            blend = min(1, t / 0.10, (1 - t) / 0.15) if role == "attack" else 1
            if blend < 1:
                a, qa, sa = base_basis[bone.name].decompose()
                b, qb, sb = matrix.decompose()
                matrix = Matrix.LocRotScale(
                    a.lerp(b, blend), qa.slerp(qb, blend), sa.lerp(sb, blend)
                )
            bone.matrix_basis = matrix
            for channel in ["location", "rotation_quaternion", "scale"]:
                bone.keyframe_insert(data_path=channel, frame=index, group=bone.name)
    # 실제 런타임 LBS 결과로 접지를 보정한다. 원본의 IK/볼륨 보존 평가와
    # 정점당 4/8 가중치의 glTF 스킨 결과는 공격 자세에서 다를 수 있다.
    runtime_floor = []
    runtime_correction = []
    for index in range(samples + 1):
        scene.frame_set(index)
        bpy.context.view_layer.update()
        evaluated_body = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        points = [
            evaluated_body.matrix_world @ v.co for v in evaluated_body.data.vertices
        ]
        bottom = min(v.z for v in points)
        lift = -bottom if role in ["idle", "run", "death"] else max(0.0, -bottom)
        delta = Vector((0, 0, lift))
        # 시체의 중심이 실제 사망 위치에서 수 미터 밀리지 않게 한다.
        if role == "death":
            delta.x = -(min(v.x for v in points) + max(v.x for v in points)) * 0.5
            delta.y = -(min(v.y for v in points) + max(v.y for v in points)) * 0.5
        root_bone = arm.pose.bones[root_name]
        corrected = root_bone.matrix.copy()
        corrected.translation += delta
        root_bone.matrix = corrected
        root_bone.keyframe_insert(data_path="location", frame=index, group=root_name)
        runtime_floor.append(bottom + lift)
        runtime_correction.append(list(delta))
    for curve in baked.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    scene.frame_set(0)
    bpy.context.view_layer.update()
    differences = sorted(
        [
            (
                max(
                    abs(arm.pose.bones[name].matrix[i][j] - wanted[i][j])
                    for i in range(4)
                    for j in range(4)
                ),
                name,
            )
            for name, wanted in first_matrices.items()
        ],
        reverse=True,
    )
    print("BONE_VERIFY", args.kind, role, differences[:3], flush=True)
    track = arm.animation_data.nla_tracks.new()
    track.name = role
    strip = track.strips.new(role, 0, baked)
    strip.action_frame_end = samples
    peak = max(
        range(max(1, int(samples * 0.15)), max(2, int(samples * 0.85))),
        key=lambda i: scores[i],
    )
    arm.animation_data.action = baked
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    scene.frame_set(samples)
    bpy.context.view_layer.update()
    evaluated_body = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    final_floor = min(
        (evaluated_body.matrix_world @ v.co).z for v in evaluated_body.data.vertices
    )
    records[role] = {
        "source_action": source_name,
        "duration_seconds": samples / fps,
        "contact_seconds": peak / fps if role == "attack" else None,
        "samples": samples + 1,
        "final_floor_m": final_floor,
        "floor_range_m": [min(x[0] for x in bounds), max(x[0] for x in bounds)],
        "runtime_floor_range_m": [min(runtime_floor), max(runtime_floor)],
        "runtime_correction_m": runtime_correction,
    }
    print("BAKED", args.kind, role, records[role], flush=True)
arm.animation_data.action = None
for track in arm.animation_data.nla_tracks:
    track.mute = True
for bone in arm.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
scene.render.fps = fps
scene.render.fps_base = 1
scene.frame_set(0)
for obj in source_objects:
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
for track in arm.animation_data.nla_tracks:
    track.mute = False
args.output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(args.output.resolve()),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,
    export_frame_range=False,
    export_skins=True,
    export_def_bones=True,
    export_influence_nb=influence_limit,
    export_all_influences=False,
    export_morph=False,
    export_yup=True,
    export_apply=False,
)
report = {
    "kind": args.kind,
    "source": str(args.source),
    "target_height_m": height,
    "normalizer": [list(row) for row in normalizer],
    "bones": len(arm_data.bones),
    "rest_error": rest_error,
    "max_discarded_skin_weight": max_discarded,
    "influences": influence_limit,
    "clips": records,
    "tool": "Blender " + bpy.app.version_string,
}
args.output.with_suffix(".bake.json").write_text(json.dumps(report, indent=2) + "\n")
print("ENEMY_EXPORT_PASS", args.output, flush=True)
