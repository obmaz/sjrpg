"""멧돼지만의 표면 보강·발 기준·어금니·보조 포즈. 런타임에 포함하지 않는다."""

import math
import bpy
from mathutils import Matrix, Vector


def refine_meshes(meshes):
    for obj in meshes:
        smooth = obj.modifiers.new("RuntimeSurfaceRefinement", "SUBSURF")
        smooth.levels = smooth.render_levels = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_move_to_index(modifier=smooth.name, index=1)


def foot_center(rig, default):
    # 긴 주둥이까지 포함한 AABB 대신 실제 네 발의 지지 중심을 원점으로 쓴다.
    feet = [
        rig.matrix_world @ rig.data.bones[name].head_local
        for name in ["body.001_L.002", "body.001_R.002", "body_L.002", "body_R.002"]
    ]
    center = default.copy()
    center.x = sum(point.x for point in feet) / len(feet)
    center.y = sum(point.y for point in feet) / len(feet)
    return center


def build_details(rig, rest):
    ivory = bpy.data.materials.new("WeatheredTusks")
    ivory.use_nodes = True
    surface = ivory.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = (0.57, 0.51, 0.38, 1)
    surface.inputs["Roughness"].default_value = 0.90
    points, faces = [], []
    head = rest["head"].translation
    rings, sides = 9, 6
    for side in [-1, 1]:
        start = len(points)
        centers = [
            head
            + Vector(
                (side * (0.14 + 0.20 * t), -0.22 - 0.10 * t, -0.14 + 0.30 * t**1.4)
            )
            for t in [i / (rings - 1) for i in range(rings)]
        ]
        for index, center in enumerate(centers):
            t = index / (rings - 1)
            tangent = (
                centers[min(index + 1, rings - 1)] - centers[max(0, index - 1)]
            ).normalized()
            u = tangent.cross(Vector((0, 1, 0))).normalized()
            v = tangent.cross(u).normalized()
            radius = 0.038 * (1 - t) ** 0.8 + 0.002
            points.extend(
                center
                + radius
                * (
                    u * math.cos(j * math.tau / sides)
                    + v * math.sin(j * math.tau / sides)
                )
                for j in range(sides)
            )
        faces.append(tuple(start + j for j in reversed(range(sides))))
        faces.append(tuple(start + (rings - 1) * sides + j for j in range(sides)))
        for ring in range(rings - 1):
            for j in range(sides):
                a = start + ring * sides + j
                b = start + ring * sides + (j + 1) % sides
                faces.append((a, b, b + sides, a + sides))
    mesh = bpy.data.meshes.new("CurvedTusks")
    mesh.from_pydata(points, [], faces)
    uv = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        uv.data[loop.index].uv = (
            (loop.vertex_index % sides) / sides,
            (loop.vertex_index // sides) % rings / (rings - 1),
        )
    mesh.materials.append(ivory)
    for face in mesh.polygons:
        face.use_smooth = True
    obj = bpy.data.objects.new("CurvedTusks", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.vertex_groups.new(name="head").add(list(range(len(points))), 1, "REPLACE")
    skin = obj.modifiers.new("Skin", "ARMATURE")
    skin.object = rig
    obj.parent = rig
    return [obj]


def pose_basis(basis, role, t, root_name):
    if role == "idle":
        basis["body"] = basis["body"] @ Matrix.Rotation(
            math.sin(t * math.tau) * 0.015, 4, "X"
        )
    elif role == "hit":
        basis["body.001"] = basis["body.001"] @ Matrix.Rotation(
            math.sin(t * math.pi) * 0.22, 4, "X"
        )
    return basis


def pose_world(matrices, rig, role, t):
    if role == "death":
        # 정규화된 Z-up 공간에서 몸의 긴 축을 따라 눕힌다. 루트 뼈의 local 축은 지면 축이 아니다.
        turn = Matrix.Rotation((t * t * (3 - 2 * t)) * math.pi * 0.5, 4, "Y")
        return {name: turn @ matrix for name, matrix in matrices.items()}
    return matrices
