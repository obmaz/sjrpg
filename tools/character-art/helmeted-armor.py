"""Original bone-bound armor geometry, guided by the generated warrior reference.

Coordinates are rest-space meters on the reviewed CC0 adult male skeleton.
No frame-dependent corrections, sprite paintovers, or foreign game assets.
"""

import math

from mathutils import Matrix, Vector


def equip_armor(bpy, rig, visible, material):
    steel = material("Original dark forged armor", (.12, .16, .18))
    edge = material("Original worn steel edges", (.32, .38, .40))
    cloth = material("Original muted teal short cloth", (.025, .105, .105))
    under = material("Original charcoal underarmor", (.055, .065, .07))
    beard = material("Original adult male dark beard", (.11, .065, .045))
    strap = material("Original dark leather armor strap", (.10, .055, .028))
    brass = material("Original small dull brass fasteners", (.32, .25, .13))
    for mat in (steel, edge):
        node = mat.node_tree.nodes.get('Principled BSDF')
        node.inputs['Metallic'].default_value = .65
        node.inputs['Roughness'].default_value = .48
        noise = mat.node_tree.nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 65
        bump = mat.node_tree.nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .14
        bump.inputs['Distance'].default_value = .012
        mat.node_tree.links.new(noise.outputs['Fac'], bump.inputs['Height'])
        mat.node_tree.links.new(bump.outputs['Normal'], node.inputs['Normal'])

    for obj in list(visible):
        if not obj.name.startswith('Male_Ranger'):
            continue
        if 'Hood' in obj.name or 'Pauldron' in obj.name:
            obj.hide_render = True
            visible.remove(obj)
        else:
            obj.data.materials.clear()
            obj.data.materials.append(under)
            for polygon in obj.data.polygons:
                polygon.material_index = 0

    def bind(obj, bone, mat):
        obj.data.materials.append(mat)
        # Vertices are authored in rest world coordinates. This maps them to
        # the animated bone once while preserving their exact rest placement.
        obj.parent = rig
        obj.parent_type = 'BONE'
        obj.parent_bone = bone
        target = rig.data.bones[bone]
        obj.matrix_parent_inverse = (
            rig.matrix_world @ target.matrix_local @
            Matrix.Translation((0, target.length, 0))).inverted()
        obj.matrix_basis = Matrix.Identity(4)
        visible.add(obj)
        return obj

    def mesh(name, vertices, faces, bone, mat):
        data = bpy.data.meshes.new(name)
        data.from_pydata(vertices, [], faces)
        data.update()
        obj = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(obj)
        bind(obj, bone, mat)
        return obj

    def ellipsoid(name, center, radii, bone, mat, cut=None):
        vertices, faces = [], []
        rings, sides = (6, 10) if "pauldron" in name.lower() else (10, 20)
        for j in range(rings + 1):
            phi = math.pi * j / rings
            for i in range(sides):
                theta = math.tau * i / sides
                vertices.append((center[0] + radii[0] * math.sin(phi) * math.cos(theta),
                                 center[1] + radii[1] * math.sin(phi) * math.sin(theta),
                                 center[2] + radii[2] * math.cos(phi)))
        for j in range(rings):
            for i in range(sides):
                face = (j*sides+i, j*sides+(i+1)%sides,
                        (j+1)*sides+(i+1)%sides, (j+1)*sides+i)
                if cut and cut([vertices[k] for k in face]):
                    continue
                faces.append(face)
        obj = mesh(name, vertices, faces, bone, mat)
        for polygon in obj.data.polygons:
            polygon.use_smooth = "pauldron" not in name.lower()
        return obj

    def plate(name, center, scale, bone, mat=steel):
        if any(token in name for token in ['arm plate', 'elbow', 'vambrace', 'gauntlet', 'thigh', 'greave', 'boot', 'cheek']):
            return ellipsoid(name, center, scale, bone, mat)
        # Beveled planar faces preserve plate highlights at small sprite sizes.
        bpy.ops.mesh.primitive_cube_add(size=2)
        obj = bpy.context.object
        obj.name = name
        for v in obj.data.vertices:
            v.co = Vector(center) + Vector((v.co.x*scale[0], v.co.y*scale[1], v.co.z*scale[2]))
        bevel = obj.modifiers.new('Forged softened edges', 'BEVEL')
        bevel.width = .012
        bevel.segments = 2
        return bind(obj, bone, mat)

    # Continuous steel crown/occiput: all scalp is covered in every direction.
    # Only the lower front is open, leaving the actual adult male face visible.
    ellipsoid('Original open faced steel helmet', (0, .005, 1.716),
              (.151, .172, .177), 'Head', steel,
              cut=lambda points: sum(p[1] for p in points)/4 < -.045 and
              sum(p[2] for p in points)/4 < 1.81)
    for side in [-1, 1]:
        plate('Helmet cheek guard', (side*.128, -.013, 1.655),
              (.025, .07, .075), 'Head')
    plate('Helmet brow', (0, -.127, 1.802), (.117, .018, .018), 'Head', edge)
    plate('Helmet crown ridge', (0, .018, 1.869), (.012, .128, .017), 'Head', edge)

    ellipsoid('Adult male short beard', (0, -.064, 1.609),
              (.068, .058, .048), 'Head', beard)
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=6,
        location=(0, .023, 1.522), major_radius=.113, minor_radius=.018)
    collar = bpy.context.object
    # Bake primitive transform before the common rest-space bone binding.
    for vertex in collar.data.vertices:
        vertex.co += collar.location
    collar.location = (0,0,0)
    bind(collar, 'neck_01', edge)

    # Ridged breast/back plate, broad shoulder caps and a separate waist lame.
    vertices = [(-.22,-.112,1.47), (0,-.176,1.49), (.22,-.112,1.47),
                (-.235,-.143,1.32), (0,-.205,1.32), (.235,-.143,1.32),
                (-.163,-.112,1.15), (0,-.153,1.13), (.163,-.112,1.15),
                (-.20,.15,1.46), (.20,.15,1.46), (-.16,.13,1.15), (.16,.13,1.15)]
    mesh('Original ridged steel breastplate', vertices,
         [(3,4,1,0),(4,5,2,1),(6,7,4,3),(7,8,5,4),
          (0,9,11,6,3),(2,5,8,12,10),(9,10,12,11),(0,2,10,9)], 'spine_03', steel)
    mesh('Raised central breastplate ridge',
         [(-.009,-.181,1.48),(.009,-.181,1.48),(.009,-.213,1.32),
          (-.009,-.213,1.32),(.008,-.160,1.15),(-.008,-.160,1.15)],
         [(0,1,2,3),(3,2,4,5)], 'spine_03', edge)
    mesh('Dark leather diagonal armor strap',
         [(-.20,-.148,1.47),(-.17,-.15,1.49),(.018,-.226,1.33),
          (-.012,-.226,1.31),(.18,-.163,1.17),(.15,-.163,1.15)],
         [(0,1,2,3),(3,2,4,5)], 'spine_03', strap)
    plate('Lower articulated armor lame', (0,-.005,1.115), (.17,.14,.04), 'spine_02')
    for side, suffix in [(-1, 'r'), (1, 'l')]:
        shoulder = rig.data.bones['upperarm_'+suffix].head_local
        ellipsoid('Layered steel pauldron', (side*.225,.045,1.49),
                  (.135,.15,.1), 'upperarm_'+suffix, steel,
                  cut=lambda points: sum(p[2] for p in points)/4 < 1.464)
        ellipsoid('Pauldron lower rim', (side*.25,.045,1.442),
                  (.126,.141,.036), 'upperarm_'+suffix, edge)
        # Arm plates follow the same bones as the unmodified CC0 action clips.
        plate('Upper arm plate', (side*.33,.052,1.455), (.095,.095,.09), 'upperarm_'+suffix)
        plate('Steel elbow cap', (side*.445,.054,1.455), (.05,.103,.1), 'lowerarm_'+suffix)
        plate('Steel vambrace', (side*.57,.056,1.455), (.1,.092,.082), 'lowerarm_'+suffix)
        plate('Steel gauntlet', (side*.716,.054,1.455), (.067,.085,.074), 'hand_'+suffix)
        plate('Articulated thigh plate', (side*.095,-.022,.77), (.085,.095,.14), 'thigh_'+suffix)
        x = side * .095
        mesh('Angular pointed steel knee plate',
             [(x-.073,-.09,.59),(x+.073,-.09,.59),(x+.064,-.11,.51),
              (x,-.12,.477),(x-.064,-.11,.51),(x,-.155,.55)],
             [(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5)], 'calf_'+suffix, steel)
        plate('Steel shin greave', (side*.095,-.018,.31), (.072,.092,.18), 'calf_'+suffix)
        plate('Steel armored boot', (side*.095,-.05,.075), (.08,.145,.048), 'foot_'+suffix)
        # Short waist cloth over charcoal leg joints; no long obscuring robe.
        mesh('Short teal waist panel',
             [(side*.04,-.15,1.09),(side*.16,-.14,1.09),
              (side*.20,-.14,.83),(side*.07,-.16,.80)],
             [(0,1,2,3)], 'pelvis', cloth)
        ellipsoid('Dull pauldron rivet', (side*.185,-.093,1.466),
                  (.021,.012,.021), 'upperarm_'+suffix, brass)
    # A small rear shoulder cloth, not a full-length cape or hood.
    mesh('Short muted teal shoulder cloth',
         [(-.17,.165,1.48),(0,.184,1.48),(.17,.165,1.48),(.17,.19,1.28),(0,.215,1.16),(-.17,.19,1.24)],
         [(0,1,4,5),(1,2,3,4)], 'spine_03', cloth)
