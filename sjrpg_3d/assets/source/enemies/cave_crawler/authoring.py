"""잠복자의 굽힌 상체·전방으로 늘어뜨린 팔·할퀴기/턱/피격/쓰러짐 클립 저작."""

import math
from mathutils import Matrix, Vector


def _transform_branch(matrices, rig, name, transform):
    for bone in rig.data.bones:
        if bone.name == name or any(
            parent.name == name for parent in bone.parent_recursive
        ):
            matrices[bone.name] = transform @ matrices[bone.name]


def _aim(matrices, rig, joint, end, direction):
    pivot = matrices[joint].translation
    current = matrices[end].translation - pivot
    rotation = (
        current.normalized()
        .rotation_difference(Vector(direction).normalized())
        .to_matrix()
        .to_4x4()
    )
    _transform_branch(
        matrices,
        rig,
        joint,
        Matrix.Translation(pivot) @ rotation @ Matrix.Translation(-pivot),
    )


def pose_world(matrices, rig, role, t):
    # 관절마다 다른 roll 대신 실제 미터 공간의 축과 팔다리 방향을 사용한다.
    pivot = matrices["joint2"].translation
    breath = 0.012 * math.sin(t * math.tau) if role == "idle" else 0
    bend = (
        Matrix.Translation(pivot)
        @ Matrix.Rotation(0.55 + breath, 4, "X")
        @ Matrix.Translation(-pivot)
    )
    _transform_branch(matrices, rig, "joint2", bend)
    if role != "run":
        for side, suffix in [(1, ""), (-1, ".001")]:
            upper, elbow, wrist = (
                "joint14" + suffix,
                "joint11" + suffix,
                "joint12" + suffix,
            )
            arm = (side * 0.18, -0.42, -0.86)
            forearm = (side * 0.04, -0.30, -0.76)
            if role == "attack":
                prepare = math.sin(min(t / 0.6, 1) * math.pi)
                reach = math.sin(max(0, (t - 0.3) / 0.7) * math.pi)
                arm = (
                    side * (0.18 + 0.45 * prepare),
                    -0.42 - 0.35 * reach,
                    -0.86 + 0.85 * prepare + 0.45 * reach,
                )
                forearm = (side * 0.04, -0.30 - 0.60 * reach, -0.76 + 0.90 * reach)
            _aim(matrices, rig, upper, elbow, arm)
            _aim(matrices, rig, elbow, wrist, forearm)
    return matrices


def pose_basis(basis, role, t, root_name):
    if role == "attack":
        basis["Jaw"] = basis["Jaw"] @ Matrix.Rotation(
            0.45 * math.sin(math.pi * min(t / 0.6, 1)), 4, "X"
        )
    elif role == "hit":
        basis["joint2"] = basis["joint2"] @ Matrix.Rotation(
            math.sin(t * math.pi) * -0.3, 4, "X"
        )
    elif role == "death":
        basis[root_name] = Matrix.Rotation(t * 1.5, 4, "X") @ basis[root_name]
    return basis
