"""보존한 외부 모델을 고정 미터·골격·클립의 독립 GLB로 변환한다."""

import argparse
import hashlib
import importlib.util
import json
import math
import subprocess
import sys
import zipfile
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

parser = argparse.ArgumentParser()
parser.add_argument(
    "--kind", choices=["boar", "skeleton", "golem", "cave_crawler"], required=True
)
parser.add_argument("--fbx2gltf", type=Path)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
ROOT = Path(__file__).resolve().parents[3]
source = ROOT / "assets/source/enemies" / args.kind
folder = ROOT / "assets/models/enemies" / args.kind
proof = json.loads((source / "provenance.json").read_text())
spec = json.loads((folder / "asset.json").read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert digest(source / proof["original"]) == proof["original_sha256"]
for entry in proof.get("additional_inputs", []):
    assert digest(source / entry["path"]) == entry["sha256"]
cache = ROOT / "build/enemy-source" / args.kind
cache.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
# 종별 모델 저작은 자기 소스 폴더에 두어 공용 변환기와 분리한다.
authoring = None
authoring_path = source / "authoring.py"
if authoring_path.exists():
    module_spec = importlib.util.spec_from_file_location(
        "enemy_authoring", authoring_path
    )
    authoring = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(authoring)


def load_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return set(bpy.data.objects) - before


def convert_fbx(path, label):
    assert args.fbx2gltf and digest(args.fbx2gltf) == proof["fbx2gltf_sha256"]
    output = cache / (label + ".glb")
    subprocess.run(
        [str(args.fbx2gltf), "-b", "-i", str(path), "-o", str(output)],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    return output


if args.kind == "skeleton":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with zipfile.ZipFile(source / proof["original"]) as archive:
        for name in archive.namelist():
            if name.endswith((".fbx", ".png")):
                path = cache / name
                assert path.resolve().is_relative_to(cache.resolve())
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(archive.read(name))
    original = cache / "SkeletonOutlaw/Source Model/SkeletonOutlaw.fbx"
    load_gltf(convert_fbx(original, "base"))
elif args.kind == "cave_crawler":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source / proof["original"]))
else:
    bpy.ops.wm.open_mainfile(
        filepath=str(source / proof["original"]), use_scripts=False
    )
scene = bpy.context.scene
excluded = (
    {"SkeletonHair", "MetalJaw", "Shoulder00", "Shoulder01", "Boots", "Icosphere"}
    if args.kind == "skeleton"
    else set()
)
source_meshes = [
    o
    for o in scene.objects
    if o.type == "MESH"
    and o.name not in excluded
    and any(m.type == "ARMATURE" for m in o.modifiers)
]
assert source_meshes
source_arm = next(m.object for m in source_meshes[0].modifiers if m.type == "ARMATURE")
source_objects = set(bpy.data.objects)
source_arm.animation_data_clear()
source_arm.data.pose_position = "REST"
if authoring and hasattr(authoring, "refine_meshes"):
    authoring.refine_meshes(source_meshes)
bpy.context.view_layer.update()
# 원본 Mirror/삼각화/분할까지 적용한 메시에서 전체 몸과 스킨 그룹을 보존한다.
meshes = {
    o: bpy.data.meshes.new_from_object(
        o.evaluated_get(bpy.context.evaluated_depsgraph_get()),
        preserve_all_data_layers=True,
        depsgraph=bpy.context.evaluated_depsgraph_get(),
    )
    for o in source_meshes
}
points = [o.matrix_world @ v.co for o, m in meshes.items() for v in m.vertices]
minimum = Vector([min(v[i] for v in points) for i in range(3)])
maximum = Vector([max(v[i] for v in points) for i in range(3)])
height = spec["height_m"]
ratio = height / (maximum.z - minimum.z)
turn = 0.0
if args.kind in ["boar", "golem"]:
    front, back = ("head", "Hips") if args.kind == "boar" else ("head", "chest")
    vector = source_arm.matrix_world.to_3x3() @ (
        source_arm.data.bones[front].head_local - source_arm.data.bones[back].head_local
    )
    if Vector((vector.x, vector.y)).length > 1e-5:
        turn = -math.pi / 2 - math.atan2(vector.y, vector.x)
center = (minimum + maximum) * 0.5
if authoring and hasattr(authoring, "foot_center"):
    center = authoring.foot_center(source_arm, center)
normalizer = (
    Matrix.Scale(ratio, 4)
    @ Matrix.Rotation(turn, 4, "Z")
    @ Matrix.Translation(Vector((-center.x, -center.y, -minimum.z)))
)


def unit_frame(matrix, divisor):
    result = matrix.copy()
    for i in range(3):
        for j in range(3):
            result[i][j] /= divisor
    if result.to_3x3().determinant() < 0:
        for i in range(3):
            result[i][0] *= -1
    return result


raw_rest = {
    b.name: normalizer @ source_arm.matrix_world @ b.matrix_local
    for b in source_arm.data.bones
}
divisors = {
    n: sum(m.to_3x3().col[i].length for i in range(3)) / 3 for n, m in raw_rest.items()
}
rest = {n: unit_frame(m, divisors[n]) for n, m in raw_rest.items()}
weighted = {
    o.vertex_groups[g.group].name
    for o, m in meshes.items()
    for v in m.vertices
    for g in v.groups
    if g.weight > 1e-6
}
arm_data = bpy.data.armatures.new("EnemySkeleton")
arm = bpy.data.objects.new("Rig", arm_data)
scene.collection.objects.link(arm)
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for bone in source_arm.data.bones:
    target = arm_data.edit_bones.new(bone.name)
    target.length = max(
        0.001,
        (
            normalizer.to_3x3()
            @ source_arm.matrix_world.to_3x3()
            @ (bone.tail_local - bone.head_local)
        ).length,
    )
    target.matrix = rest[bone.name]
    target.use_deform = bone.name in weighted
    if bone.parent:
        target.parent = arm_data.edit_bones[bone.parent.name]
bpy.ops.object.mode_set(mode="OBJECT")
rest_error = max(
    abs(b.matrix_local[i][j] - rest[b.name][i][j])
    for b in arm_data.bones
    for i in range(4)
    for j in range(4)
)
assert rest_error < 0.0001, rest_error
rest = {b.name: b.matrix_local.copy() for b in arm_data.bones}
for bone in arm.pose.bones:
    bone.rotation_mode = "QUATERNION"


def painted(name, image, tint=(1, 1, 1, 1)):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.94
    bsdf.inputs["Base Color"].default_value = tint
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    return material


if args.kind == "boar":
    body_material = painted("BoarHide", bpy.data.images["boar"])
elif args.kind == "golem":
    body_material = painted("WeatheredRock", bpy.data.images["GolemTex_v9.png"])
elif args.kind == "skeleton":
    body_material = painted(
        "AgedBone",
        bpy.data.images.load(
            str(cache / "SkeletonOutlaw/Textures/SkeletonOutlaw00.png")
        ),
    )
    weapon_material = painted(
        "WornAxe",
        bpy.data.images.load(str(cache / "SkeletonOutlaw/Textures/Axe00.png")),
    )
else:
    body_material = painted(
        "CaveHide", bpy.data.images.load(str(source / "albedo.png"))
    )
built = []
for original, mesh in meshes.items():
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
    # render-active 'projection-test'는 시험 UV이며 멧돼지의 원본 atlas는 UVMap이다.
    active = (
        mesh.uv_layers.get("UVMap")
        if args.kind == "boar"
        else next((u for u in mesh.uv_layers if u.active_render), mesh.uv_layers.active)
    )
    coords = [tuple(v.uv) for v in active.data]
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    uv = mesh.uv_layers.new(name="UVMap")
    for loop, point in zip(uv.data, coords):
        loop.uv = point
    uv.active_render = True
    for attr in list(mesh.color_attributes):
        mesh.color_attributes.remove(attr)
    mesh.materials.clear()
    mesh.materials.append(
        weapon_material
        if args.kind == "skeleton" and original.name == "Axe00"
        else body_material
    )
    for face in mesh.polygons:
        face.material_index = 0
        face.use_smooth = True
    skin = obj.modifiers.new("Skin", "ARMATURE")
    skin.object = arm
    obj.parent = arm
    built.append(obj)
if authoring and hasattr(authoring, "build_details"):
    built.extend(authoring.build_details(arm, rest))
bpy.ops.object.select_all(action="DESELECT")
for obj in built:
    obj.select_set(True)
bpy.context.view_layer.objects.active = built[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "Body"
valid = {b.name for b in arm.data.bones if b.use_deform}
influences = 8 if args.kind == "boar" else 4
max_discarded = 0.0
max_fit_error = 0.0
fit_samples = 0
fit_matrices = None
bone_names = list(rest)
if args.kind == "boar":
    import numpy as np

    sys.path.insert(0, str(Path(__file__).parent))
    from skin_weights import fit_influences

    source_arm.data.pose_position = "POSE"
    source_arm.animation_data_create()
    samples = []
    for action_name in ["walk", "attack"]:
        action = bpy.data.actions[action_name]
        source_arm.animation_data.action = action
        start, end = action.frame_range
        for index in range(17):
            time = start + (end - start) * index / 16
            scene.frame_set(math.floor(time), subframe=time % 1)
            bpy.context.view_layer.update()
            samples.append(
                [
                    np.asarray(
                        unit_frame(
                            normalizer
                            @ source_arm.matrix_world
                            @ source_arm.pose.bones[name].matrix,
                            divisors[name],
                        )
                        @ rest[name].inverted()
                    )
                    for name in bone_names
                ]
            )
    fit_matrices = np.asarray(samples)
    fit_samples = len(samples)
else:
    for vertex in body.data.vertices:
        weights = sorted(
            [
                g.weight
                for g in vertex.groups
                if body.vertex_groups[g.group].name in valid and g.weight > 0
            ],
            reverse=True,
        )
        if sum(weights[4:]) / max(sum(weights), 1e-12) > 0.02:
            influences = 8
for vertex in body.data.vertices:
    groups = sorted(
        [
            (g.group, g.weight)
            for g in vertex.groups
            if body.vertex_groups[g.group].name in valid and g.weight > 0
        ],
        key=lambda x: x[1],
        reverse=True,
    )
    assert groups, ("unweighted vertex", vertex.index)
    total = sum(w for _, w in groups)
    if fit_matrices is not None:
        mapped = [
            (bone_names.index(body.vertex_groups[index].name), weight)
            for index, weight in groups
        ]
        fitted, error = fit_influences(
            tuple(vertex.co), mapped, fit_matrices, influences
        )
        max_fit_error = max(max_fit_error, error)
        fitted = [
            (body.vertex_groups[bone_names[index]].index, weight)
            for index, weight in fitted
        ]
    else:
        max_discarded = max(
            max_discarded, sum(w for _, w in groups[influences:]) / total
        )
        kept = sum(w for _, w in groups[:influences])
        fitted = [(group, weight / kept) for group, weight in groups[:influences]]
    for group in [g.group for g in vertex.groups]:
        body.vertex_groups[group].remove([vertex.index])
    for group, weight in fitted:
        body.vertex_groups[group].add([vertex.index], weight, "REPLACE")
print("WEIGHT_SUMMARY", args.kind, influences, max_discarded, max_fit_error, flush=True)
assert max_discarded < 0.02 and max_fit_error < 0.02
source_arm.data.pose_position = "POSE"
source_arm.animation_data_create()
root_name = next(b.name for b in source_arm.data.bones if not b.parent)
fps = 30
source_fps = scene.render.fps / scene.render.fps_base
arm.animation_data_create()
records = {}
base_basis = None
sources = {
    "boar": {
        "idle": ("default", 1.6),
        "run": ("walk", None),
        "attack": ("attack", None),
        "hit": ("default", 0.35),
        "death": ("default", 0.8),
    },
    "golem": {
        "idle": ("Idle", None),
        "run": ("Run", None),
        "attack": ("Attack1", None),
        "hit": ("Hurt1", None),
        "death": ("Death", None),
    },
    "skeleton": {
        k: (v, None)
        for k, v in [
            ("idle", "Idle00"),
            ("run", "Run00"),
            ("attack", "Attack00"),
            ("hit", "Damage00"),
            ("death", "Dead00"),
        ]
    },
    "cave_crawler": {
        "idle": ("idle", 1.8),
        "run": ("run", None),
        "attack": ("idle", 1.0),
        "hit": ("idle", 0.35),
        "death": ("idle", 1.0),
    },
}[args.kind]
original_idle = None
if args.kind == "cave_crawler":
    original_idle = (
        next(a for a in bpy.data.actions if a == source_arm.animation_data.action)
        if source_arm.animation_data.action
        else next(
            a
            for a in bpy.data.actions
            if "Idle" in a.name and a.name.startswith("Armature.002")
        )
    )
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(source / "run.fbx"))
    added = set(bpy.data.objects) - before
    run_mesh = next(o for o in added if o.type == "MESH")
    run_arm = next(m.object for m in run_mesh.modifiers if m.type == "ARMATURE")
    run_action = run_arm.animation_data.action
    assert set(b.name for b in run_arm.data.bones) == set(rest)
    run_action.use_fake_user = True
    for obj in added:
        bpy.data.objects.remove(obj, do_unlink=True)


def synthetic(basis, role, t):
    if authoring and hasattr(authoring, "pose_basis"):
        return authoring.pose_basis(basis, role, t, root_name)
    return basis


for role, (source_name, custom_length) in sources.items():
    added = set()
    node_map = None
    if args.kind == "skeleton":
        path = (
            cache
            / "SkeletonOutlaw/Animations"
            / ("SkeletonOutlaw@" + source_name + ".fbx")
        )
        converted = convert_fbx(path, role)
        added = load_gltf(converted)
        node_map = {o.name: o for o in added if o.name in rest}
        assert set(node_map) == set(rest), (role, set(rest) - set(node_map))
        action = next(
            o.animation_data.action
            for o in node_map.values()
            if o.animation_data and o.animation_data.action
        )
    elif args.kind == "cave_crawler":
        action = run_action if source_name == "run" else original_idle
        source_arm.animation_data.action = action
    else:
        action = bpy.data.actions[source_name]
        source_arm.animation_data.action = action
    start, end = action.frame_range
    duration = custom_length or max((end - start) / source_fps, 1.0)
    samples = max(2, round(duration * fps))
    poses = []
    scores = []
    first_root = None
    for index in range(samples + 1):
        source_frame = start + (end - start) * (0 if custom_length else index / samples)
        scene.frame_set(math.floor(source_frame), subframe=source_frame % 1)
        bpy.context.view_layer.update()
        matrices = {
            name: unit_frame(
                normalizer
                @ (
                    node_map[name].matrix_world
                    if node_map
                    else source_arm.matrix_world @ source_arm.pose.bones[name].matrix
                ),
                divisors[name],
            )
            for name in rest
        }
        if authoring and hasattr(authoring, "pose_world"):
            matrices = authoring.pose_world(matrices, source_arm, role, index / samples)
        at = matrices[root_name].translation.copy()
        if first_root is None:
            first_root = at.copy()
        shift = Vector((at.x - first_root.x, at.y - first_root.y, 0))
        for m in matrices.values():
            m.translation -= shift
        basis = {
            b.name: (
                rest[b.name].inverted()
                @ rest[b.parent.name]
                @ matrices[b.parent.name].inverted()
                @ matrices[b.name]
                if b.parent
                else rest[b.name].inverted() @ matrices[b.name]
            )
            for b in arm.data.bones
        }
        basis = synthetic(basis, role, index / samples)
        poses.append(basis)
        marker = {
            "boar": "head",
            "golem": "arm.R",
            "skeleton": "ORG-hand_R",
            "cave_crawler": "Jaw",
        }[args.kind]
        scores.append(-matrices[marker].translation.y)
    if base_basis is None:
        base_basis = {k: v.copy() for k, v in poses[0].items()}
    for obj in added:
        bpy.data.objects.remove(obj, do_unlink=True)
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    baked = bpy.data.actions.new(role)
    arm.animation_data.action = baked
    for index, basis in enumerate(poses):
        t = index / samples
        for bone in arm.pose.bones:
            matrix = basis[bone.name]
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
    floors = []
    for index in range(samples + 1):
        scene.frame_set(index)
        bpy.context.view_layer.update()
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        points = [evaluated.matrix_world @ v.co for v in evaluated.data.vertices]
        bottom = min(v.z for v in points)
        lift = -bottom if role in ["idle", "run", "death"] else max(0, -bottom)
        delta = Vector((0, 0, lift))
        if role == "death":
            delta.x = -(min(v.x for v in points) + max(v.x for v in points)) * 0.5
            delta.y = -(min(v.y for v in points) + max(v.y for v in points)) * 0.5
        pivot = arm.pose.bones[root_name]
        matrix = pivot.matrix.copy()
        matrix.translation += delta
        pivot.matrix = matrix
        pivot.keyframe_insert(data_path="location", frame=index, group=root_name)
        floors.append(bottom + lift)
    for curve in baked.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"
    track = arm.animation_data.nla_tracks.new()
    track.name = role
    strip = track.strips.new(role, 0, baked)
    strip.action_frame_end = samples
    track.mute = True
    contact = (
        (
            0.6 * duration
            if args.kind == "cave_crawler"
            else max(
                range(max(1, int(samples * 0.15)), max(2, int(samples * 0.85))),
                key=lambda i: scores[i],
            )
            / fps
        )
        if role == "attack"
        else None
    )
    records[role] = dict(
        source_action=source_name,
        duration_seconds=samples / fps,
        contact_seconds=contact,
        samples=samples + 1,
        final_floor_m=floors[-1],
        runtime_floor_range_m=[min(floors), max(floors)],
        authored_auxiliary=bool(custom_length),
    )
    print("BAKED", args.kind, role, records[role], flush=True)
arm.animation_data.action = None
for b in arm.pose.bones:
    b.matrix_basis = Matrix.Identity(4)
scene.render.fps = fps
scene.render.fps_base = 1
scene.frame_set(0)
for obj in source_objects:
    if obj.name in bpy.data.objects:
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
for track in arm.animation_data.nla_tracks:
    track.mute = False
output = folder / "model.glb"
bpy.ops.export_scene.gltf(
    filepath=str(output),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,
    export_frame_range=False,
    export_skins=True,
    export_def_bones=True,
    export_influence_nb=influences,
    export_all_influences=False,
    export_morph=False,
    export_yup=True,
    export_apply=False,
)
report = dict(
    kind=args.kind,
    source=proof["original"],
    target_height_m=height,
    normalizer=[list(r) for r in normalizer],
    bones=len(arm.data.bones),
    deform_bones=len(valid),
    rest_error=rest_error,
    max_discarded_skin_weight=max_discarded,
    max_skin_fit_error_m=max_fit_error,
    skin_fit_samples=fit_samples,
    influences=influences,
    clips=records,
    tool="Blender " + bpy.app.version_string,
)
(source / "conversion.json").write_text(json.dumps(report, indent=2) + "\n")
spec["clips"] = {
    role: dict(
        name=role,
        length=clip["duration_seconds"],
        **({"contact_time": clip["contact_seconds"]} if role == "attack" else {})
    )
    for role, clip in records.items()
}
spec["death_floor_m"] = 0.0
(folder / "asset.json").write_text(
    json.dumps(spec, ensure_ascii=False, indent=2) + "\n"
)
proof["runtime_sha256"] = digest(output)
proof["converter_sha256"] = digest(Path(__file__))
proof["converter_dependencies"] = [
    {
        "path": "tools/assets/enemies/skin_weights.py",
        "sha256": digest(Path(__file__).with_name("skin_weights.py")),
    }
]
if authoring:
    proof["converter_dependencies"].append(
        {
            "path": str(authoring_path.relative_to(ROOT)),
            "sha256": digest(authoring_path),
        }
    )

(source / "provenance.json").write_text(
    json.dumps(proof, ensure_ascii=False, indent=2) + "\n"
)
print("ENEMY_EXPORT_PASS", args.kind, output, flush=True)
