"""해골의 독립 FBX 클립을 같은 발 기준에 맞춘다. 런타임에는 포함하지 않는다."""

import bpy

_idle_floor = None


def pose_world(matrices, _source_rig, role, t):
    global _idle_floor
    if _idle_floor is None:
        # 공용 변환기는 idle부터 읽는다. 실제 런타임 스킨의 첫 자세에서
        # 기준을 한 번 측정해 attack/hit의 작은 수직 움직임은 보존한다.
        assert role == "idle" and t == 0
        body = bpy.data.objects["Body"]
        rig = body.modifiers["Skin"].object
        rest_inverse = {
            bone.name: bone.matrix_local.inverted() for bone in rig.data.bones
        }
        skin = {
            name: matrix @ rest_inverse[name] for name, matrix in matrices.items()
        }
        floors = []
        for vertex in body.data.vertices:
            weighted = [
                (skin[body.vertex_groups[g.group].name] @ vertex.co, g.weight)
                for g in vertex.groups
                if g.weight > 0 and body.vertex_groups[g.group].name in skin
            ]
            total = sum(weight for _, weight in weighted)
            assert total > 0
            floors.append(sum(point.z * weight for point, weight in weighted) / total)
        _idle_floor = min(floors)
        print("SKELETON_IDLE_FLOOR", _idle_floor, flush=True)
    # idle도 같은 좌표로 옮겨야 공격 시작/끝의 idle 블렌드가 다시 떠오르지 않는다.
    # idle/run/death의 기존 프레임별 접지는 이 상수 이동을 상쇄한다.
    for matrix in matrices.values():
        matrix.translation.z -= _idle_floor
    return matrices
