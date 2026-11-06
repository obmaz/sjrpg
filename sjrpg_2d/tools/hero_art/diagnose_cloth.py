"""Inspect the inherited robe defect on evaluated licensed geometry, without rendering."""
import json
import math
import os
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
from mathutils.bvhtree import BVHTree


renderer = Path(__file__).with_name("render_mage_pilot.py")
source = renderer.read_text().split("for jobIndex, (sheet, kind, d, phase, actionName, norm) in enumerate(jobs):")[0]
scope = {"__file__": str(renderer), "__name__": "constructed_mage_diagnostic"}
exec(compile(source, str(renderer), "exec"), scope)
scene, rig, yaw, camera = (scope[key] for key in ("scene", "rig", "yaw", "cam"))
visible = [obj for obj in scene.objects if obj.type == "MESH" and not obj.hide_render]
output = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg2-character-source")) / "cloth-diagnostic"
output.mkdir(exist_ok=True)


def evaluated(obj, graph):
    current = obj.evaluated_get(graph)
    mesh = current.to_mesh()
    mesh.calc_loop_triangles()
    vertices = [current.matrix_world @ vertex.co for vertex in mesh.vertices]
    triangles = [tuple(triangle.vertices) for triangle in mesh.loop_triangles]
    tree = BVHTree.FromPolygons(vertices, triangles, all_triangles=True)
    current.to_mesh_clear()
    return vertices, triangles, tree


def inspect(label, direction, action_name, fraction):
    yaw.rotation_euler.z = math.radians(-22.5 * direction)
    action = next(action for action in bpy.data.actions if action.name.startswith(action_name))
    rig.animation_data.action = action
    start, end = action.frame_range
    frame = start + (end - start) * fraction
    scene.frame_set(int(frame), subframe=frame - int(frame))
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    geometry = {obj.name: evaluated(obj, graph) for obj in visible if obj.type == "MESH"}
    cloth_names = [name for name in geometry if name.startswith("OriginalNavyRobe-")]
    result = {"pose": label, "clothingLegOverlaps": {}, "quadNormals": {}}
    for name in cloth_names:
        tree = geometry[name][2]
        for other in ("Male_Peasant_Legs", "Male_Peasant_Feet", "Male_Ranger_Body", "Male_Ranger_Arms"):
            if other in geometry:
                result["clothingLegOverlaps"][name + " / " + other] = len(tree.overlap(geometry[other][2]))
    result["leftRightPanelOverlap"] = len(geometry[cloth_names[0]][2].overlap(geometry[cloth_names[1]][2]))
    # Evaluate the skinned quads before thickness; compare their two rendered
    # triangle normals to identify a fold/inversion rather than infer from colour.
    for name in cloth_names:
        obj = bpy.data.objects[name]
        solid = next(modifier for modifier in obj.modifiers if modifier.type == "SOLIDIFY")
        solid.show_viewport = False
        bpy.context.view_layer.update()
        current = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = current.to_mesh()
        scores = []
        for polygon in mesh.polygons:
            points = [current.matrix_world @ mesh.vertices[index].co for index in polygon.vertices]
            if len(points) == 4:
                a = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
                b = (points[2] - points[0]).cross(points[3] - points[0]).normalized()
                scores.append(a.dot(b))
        result["quadNormals"][name] = scores
        current.to_mesh_clear()
        solid.show_viewport = True
        bpy.context.view_layer.update()
    if True:
        # Report which actual visible surface occupies rays through the robe's
        # projected region. These coordinates can be compared with the PNG.
        size = scene.render.resolution_x
        points = [world_to_camera_view(scene, camera, vertex) for name in cloth_names for vertex in geometry[name][0]]
        projected_bounds = [int(min(point.x for point in points) * size),
                            int((1.0 - max(point.y for point in points)) * size),
                            int(max(point.x for point in points) * size) + 1,
                            int((1.0 - min(point.y for point in points)) * size) + 1]
        # Identical native-pixel sampling for both candidates, even when the
        # fitted silhouette moves by a pixel. Do not compare shifted ray grids.
        left, top, right, bottom = 120, 130, 270, 290
        forward = camera.matrix_world.to_quaternion() @ Vector((0, 0, -1))
        hits = {}
        leg_front_samples = []
        for py in range(top, bottom, 2):
            for px in range(left, right, 2):
                origin = camera.matrix_world @ Vector((((px + .5) / size - .5) * camera.data.ortho_scale,
                                                       (.5 - (py + .5) / size) * camera.data.ortho_scale, 0))
                candidates = []
                for name, (_, _, tree) in geometry.items():
                    location, normal, triangle, distance = tree.ray_cast(origin, forward, 100)
                    if location is not None:
                        candidates.append((distance, name, normal.dot(-forward), triangle))
                if not candidates:
                    continue
                candidates.sort()
                winner = candidates[0]
                hits[winner[1]] = hits.get(winner[1], 0) + 1
                if winner[1] == "Male_Peasant_Legs" and any(candidate[1] in cloth_names for candidate in candidates):
                    leg_front_samples.append({"pixel": [px, py], "surfaces": [(hit[1], hit[0]) for hit in candidates]})
        result["clothProjectedBounds"] = projected_bounds
        result["raySamplingBounds"] = [left, top, right, bottom]
        result["visibleRayObjectCounts"] = hits
        result["legInFrontOfClothSamples"] = leg_front_samples
    return result


reports = [inspect("S idle", 0, "Idle_Loop_Armature", 0)]
for phase, fraction in ((2, .78), (3, .12), (4, .48), (5, .82)):
    action = "Spell_Simple_Enter_Armature" if phase == 2 else "Spell_Simple_Shoot_Armature"
    reports.append(inspect("W cast" + str(phase), 4, action, fraction))
for phase in (1, 5):
    reports.append(inspect("S run" + str(phase), 0, "Sprint_Loop_Armature", phase / 8.0))
(output / ("evaluated-cloth-" + scope["PILOT_MODE"] + ".json")).write_text(json.dumps(reports, indent=2) + "\n")
for report in reports:
    print(report["pose"], "leg overlaps", report["clothingLegOverlaps"], "panel overlap", report["leftRightPanelOverlap"],
          "minimum quad-normal agreement", min(min(values) for values in report["quadNormals"].values()), flush=True)
