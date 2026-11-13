"""전사: 검증된 CC0 성인 체형/골격에 철갑·망토·검을 제작하고 GLB로 굽는다.

SJRPG_CHARACTER_SOURCE_DIR=<fetch_sources.py 출력> blender --background \
  --factory-startup --disable-autoexec --python tools/assets/heroes/export_warrior.py
기본 출력은 build/warrior-redesign/candidate이며 운영 자산을 직접 덮어쓰지 않는다.
"""
import hashlib
import json
import math
import os
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector
from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
SOURCE = Path(os.environ.get('SJRPG_CHARACTER_SOURCE_DIR', str(PROJECT.parent / 'build/warrior-redesign/source')))
OUT = Path(os.environ.get('SJRPG_WARRIOR_OUT', str(PROJECT.parent / 'build/warrior-redesign/candidate')))
OUT.mkdir(parents=True, exist_ok=True)
LOCK = json.loads((HERE / 'source-provenance.json').read_text())
for name, expected in LOCK['sourceFiles'].items():
    data = (SOURCE / name).read_bytes()
    assert len(data) == expected['bytes'] and hashlib.sha256(data).hexdigest() == expected['sha256'], name
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'adult-source/Male_Ranger-matte.gltf'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.name = 'WarriorRig'
rig.data.pose_position = 'REST'
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('Male_Ranger') and not any(k in o.name for k in ['Head_Hood', 'Acc_Pauldron', 'Arms_Bracer'])]
for obj in list(bpy.data.objects):
    if obj.type == 'MESH' and obj not in meshes:
        bpy.data.objects.remove(obj, do_unlink=True)
# 얼굴·목·눈썹·눈만 동일 패밀리의 성인 원본에서 추출한다. 숨긴 몸체는 납품하지 않는다.
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'adult-source/base/Superhero_Male-matte.gltf'))
head_rig = next(o for o in bpy.data.objects if o not in before and o.type == 'ARMATURE')
head_map = rig.data.bones['Head'].matrix_local @ head_rig.data.bones['Head'].matrix_local.inverted()
for obj in list(bpy.data.objects):
    if obj in before or obj.type != 'MESH':
        continue
    bm = bmesh.new(); bm.from_mesh(obj.data); bm.verts.ensure_lookup_table()
    anatomical = {g.index for g in obj.vertex_groups if g.name in ['Head', 'neck_01']}
    remove = [v for v in bm.verts if (obj.matrix_world @ v.co).z < head_rig.data.bones['Head'].head_local.z - .08 or sum(g.weight for g in obj.data.vertices[v.index].groups if g.group in anatomical) <= .1]
    bmesh.ops.delete(bm, geom=remove, context='VERTS')
    if not bm.verts:
        bm.free(); bpy.data.objects.remove(obj, do_unlink=True); continue
    for vertex in bm.verts:
        vertex.co = head_map @ (obj.matrix_world @ vertex.co)
    bm.to_mesh(obj.data); bm.free()
    obj.matrix_world = Matrix.Identity(4)
    obj.parent = rig
    obj.modifiers.clear()
    obj.vertex_groups.clear(); group = obj.vertex_groups.new(name='Head'); group.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    obj.modifiers.new('WarriorSkin', 'ARMATURE').object = rig
    meshes.append(obj)
bpy.data.objects.remove(head_rig, do_unlink=True)
# 의상만 오프라인 축약하고 얼굴과 손가락은 보존한다.
for obj in meshes:
    if obj.name.startswith('Male_Ranger') and obj.name != 'Male_Ranger_Arms':
        bpy.context.view_layer.objects.active = obj
        dec = obj.modifiers.new('ClothingBudget', 'DECIMATE'); dec.ratio = .55
        bpy.ops.object.modifier_apply(modifier=dec.name)
# 공유 재질은 한 번만 처리한다. 같은 재질을 쓰는 다른 부품에서 이미 변환한
# node.image를 다시 읽으면 source_source_ 이름과 재인코딩이 누적된다.
images = {}
source_image_names = set()
processed_materials = set()
for obj in meshes:
    for source_material in obj.data.materials:
        material_id = source_material.as_pointer()
        if material_id in processed_materials:
            continue
        processed_materials.add(material_id)
        for node in source_material.node_tree.nodes:
            if node.type != 'TEX_IMAGE' or node.image is None:
                continue
            original_image = node.image
            image_id = str(Path(bpy.path.abspath(original_image.filepath)).resolve())
            if image_id not in images:
                source_name = Path(bpy.path.abspath(original_image.filepath)).stem
                if not source_name:
                    raise RuntimeError('Source BaseColor image needs a preserved filename')
                source_image_names.add(source_name)
                copy = original_image.copy()
                if max(copy.size) > 1024:
                    factor = 1024 / max(copy.size)
                    copy.scale(round(copy.size[0] * factor), round(copy.size[1] * factor))
                texture_dir = OUT / 'textures'
                texture_dir.mkdir(exist_ok=True)
                file = texture_dir / (source_name + '.png')
                copy.filepath_raw = str(file)
                copy.file_format = 'PNG'
                copy.save()
                # 연결된 BaseColor 소켓의 기본값은 Blender/glTF에 적용되지 않는다.
                # 의상 전용 지도만 실제 색으로 굽고 얼굴·손·눈은 원본색을 보존한다.
                if source_name == 'T_Ranger_BaseColor':
                    with Image.open(file) as image:
                        red, green, blue, alpha = image.convert('RGBA').split()
                        tinted = Image.merge('RGBA', (
                            red.point(lambda value: round(value * .72)),
                            green.point(lambda value: round(value * .76)),
                            blue.point(lambda value: round(value * .63)),
                            alpha,
                        ))
                        tinted.save(file)
                original_image.name = "SourceOriginal_" + source_name
                resized = bpy.data.images.load(str(file), check_existing=False)
                resized.name = source_name
                resized.pack()
                images[image_id] = resized
            node.image = images[image_id]
        bsdf = next(node for node in source_material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Roughness'].default_value = .88
# 기존 생성형 재질을 재사용해 철·가죽·짙은 녹색 천의 반응을 구별한다.
atlas = Image.open(PROJECT / 'assets/materials/actors/surface_atlas.bin').convert('RGB')
def material(name, cell, tint, roughness, metallic=0):
    image_path = OUT / (name + '.png')
    x, y = cell; tile = atlas.crop((x*512, y*512, x*512+512, y*512+512)).convert('L')
    average = sum(tile.resize((16,16)).getdata()) / 256
    tile = tile.point(lambda p: min(255, round(p * 210 / max(average,1))))
    channels = [tile.point(lambda p, c=c: round(p*c)) for c in tint]
    Image.merge('RGB', channels).save(image_path)
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    texture = mat.node_tree.nodes.new('ShaderNodeTexImage'); texture.image = bpy.data.images.load(str(image_path)); texture.image.pack()
    mat.node_tree.links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = roughness; bsdf.inputs['Metallic'].default_value = metallic
    return mat
iron = material('ForgedSteel', (2,0), (.52,.57,.57), .52, .65)
edge = iron  # 같은 철 재질을 공유하고 실제 가장자리 기하로 반사를 구별한다.
leather = material('DarkLeather', (1,0), (.30,.20,.13), .88)
cloth = material('ForestCloak', (0,0), (.18,.25,.17), .97)
hair = material('DarkHair', (1,1), (.18,.12,.08), .94)
normal_audit = {}


def verify_outward_normals(name, obj, exterior_direction):
    """실제 제작 면의 법선을 의도한 외측과 비교한다. 양면 재질로 역면을 숨기지 않는다."""
    obj.data.update()
    dots = [face.normal.dot(exterior_direction(face).normalized()) for face in obj.data.polygons]
    if not dots or min(dots) <= .001:
        raise RuntimeError('Inverted authored surface: ' + name)
    normal_audit[name] = {'faces': len(dots), 'minimumOutwardDot': min(dots)}


# 부가 형상은 같은 스킨의 뼈에 결합하며 운영 중 기하를 생성하지 않는다.
def mesh(name, vertices, faces, mat, bone, weights=None):
    data = bpy.data.meshes.new(name); data.from_pydata(vertices, [], faces); data.materials.append(mat); data.update()
    obj = bpy.data.objects.new(name, data); scene.collection.objects.link(obj)
    obj.parent = rig; obj.modifiers.new('WarriorSkin', 'ARMATURE').object = rig
    if weights:
        for key, entries in weights.items():
            group = obj.vertex_groups.new(name=key)
            for index, value in entries: group.add([index], value, 'REPLACE')
    else:
        obj.vertex_groups.new(name=bone).add(list(range(len(vertices))),1,'REPLACE')
    # Local metric projection rather than an environment/light bake.
    uv = data.uv_layers.new(name='MaterialUV')
    for face in data.polygons:
        for loop in face.loop_indices:
            p = data.vertices[data.loops[loop].vertex_index].co
            axis = max(range(3), key=lambda i: abs(face.normal[i]))
            a,b = [(1,2),(0,2),(0,1)][axis]; uv.data[loop].uv = (p[a]/.4, p[b]/.4)
        face.use_smooth = True
    meshes.append(obj); return obj

def shell(name, rings, mat, bone, start=0, span=math.tau, sides=24):
    vertices=[]; faces=[]
    for z, rx, ry, cy in rings:
        for i in range(sides+1):
            a=start+span*i/sides; vertices.append((math.sin(a)*rx,cy-math.cos(a)*ry,z))
    for row in range(len(rings)-1):
        for i in range(sides):
            a=row*(sides+1)+i; faces.append((a,a+1,a+sides+2,a+sides+1))
    obj=mesh(name,vertices,faces,mat,bone)
    solid=obj.modifiers.new('PlateThickness','SOLIDIFY');solid.thickness=.008
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=solid.name)
    return obj

def ellipsoid(name, at, scale, mat, bone, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=at)
    obj=bpy.context.object;obj.name=name
    for v in obj.data.vertices:v.co=Vector(at)+Vector((v.co.x*scale[0],v.co.y*scale[1],v.co.z*scale[2]))
    obj.location=(0,0,0);obj.data.materials.append(mat)
    obj.parent=rig;obj.modifiers.new('WarriorSkin','ARMATURE').object=rig
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,'REPLACE')
    uv=obj.data.uv_layers.active
    if uv:
        for loop in uv.data:loop.uv*=2
    for face in obj.data.polygons:face.use_smooth=True
    meshes.append(obj);return obj

shell('Breastplate',[(1.04,.183,.143,0),(1.13,.213,.169,0),(1.30,.251,.185,0),(1.43,.204,.145,.015)],iron,'spine_02',-math.pi/2,math.pi)
shell('Backplate',[(1.05,.183,.139,.01),(1.27,.238,.17,.01),(1.40,.20,.14,.02)],iron,'spine_02',math.pi/2,math.pi)
for z,rx,ry in [(1.05,.186,.147),(1.105,.211,.163),(1.39,.211,.153)]:
    shell('PlateRim',[(z-.012,rx,ry,.005),(z+.012,rx,ry,.005)],edge,'spine_02')
# 허리 갑옷은 좌우 허벅지 뼈에 각각 결합한다.
for side,suffix in [(1,'l'),(-1,'r')]:
    for tier in range(3):
        z=.93-tier*.07
        obj=shell('Tasset',[(z-.065,.13,.15,0),(z,.12,.145,0)],iron,'thigh_'+suffix,-math.pi*.42,math.pi*.84,12)
        for v in obj.data.vertices:v.co.x+=side*.12
    for tier in range(3):
        vertices=[];faces=[]
        for row in range(3):
            x=side*(.205+tier*.057+row*.045)
            for y,z in [(-.155,-.04),(-.11,.045),(0,.085),(.11,.045),(.155,-.04)]:
                vertices.append((x,y,1.47-tier*.04+z))
        for row in range(2):
            for col in range(4):
                a=row*5+col;faces.append((a,a+1,a+6,a+5))
        # x가 반대 방향으로 진행하는 좌우 패치의 winding도 함께 반전한다.
        if side > 0:
            faces = [tuple(reversed(face)) for face in faces]
        obj=mesh('ForgedPauldron',vertices,faces,iron,'upperarm_'+suffix)
        verify_outward_normals('pauldron_'+suffix+'_'+str(tier), obj, lambda face: Vector((0,0,1)))
        solid=obj.modifiers.new('PlateThickness','SOLIDIFY');solid.thickness=.012
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=solid.name)
    # 팔꿈치는 위/아래 판금과 분리해 굽힐 수 있게 한다.
    elbow=rig.data.bones['lowerarm_'+suffix].head_local
    ellipsoid('Elbow',elbow,(.078,.088,.078),iron,'lowerarm_'+suffix)
    wrist=rig.data.bones['hand_'+suffix].head_local
    vertices=[];faces=[]
    for row,t in enumerate([.22,.32,.82,.94]):
        at=elbow.lerp(wrist,t);radius=.085 if row<2 else .068
        for i in range(12):
            a=math.tau*i/12;vertices.append((at.x,at.y+math.cos(a)*radius,at.z+math.sin(a)*radius))
    for row in range(3):
        for i in range(12):
            a=row*12+i;b=row*12+(i+1)%12;faces.append((a,b,b+12,a+12))
    if side < 0:
        faces = [tuple(reversed(face)) for face in faces]
    bracer = mesh('ForgedVambrace',vertices,faces,iron,'lowerarm_'+suffix)
    center = elbow.lerp(wrist, .55)
    verify_outward_normals('vambrace_'+suffix, bracer, lambda face: Vector((0,face.center.y-center.y,face.center.z-center.z)))
    knee=rig.data.bones['calf_'+suffix].head_local
    ellipsoid('Kneecap',knee+Vector((0,-.045,.01)),(.082,.07,.10),iron,'calf_'+suffix)
    shin=shell('Greave',[(.13,.066,.09,.06),(.30,.08,.107,.045),(.48,.08,.095,.035)],iron,'calf_'+suffix,-math.pi*.46,math.pi*.92,16)
    for v in shin.data.vertices:v.co.x+=side*.114
    # 어깨 고정쇠와 허리 장식은 화면에서 읽히는 크기로 제한한다.
    ellipsoid('CloakClasp',(side*.17,-.155,1.38),(.032,.016,.032),edge,'spine_03',12,6)
shell('Gorget',[(1.43,.107,.105,.02),(1.50,.095,.09,.02)],iron,'spine_03')
strap=[]
for x,z in [(.185,1.43),(-.145,1.06)]:
    strap.extend([(x-.027,-.197,z),(x+.027,-.197,z)])
mesh('DiagonalSwordStrap',strap,[(0,1,3,2)],leather,'spine_02')
shell('SwordBelt',[(.98,.207,.16,.01),(1.035,.21,.164,.01)],leather,'pelvis')
ellipsoid('BeltBuckle',(0,-.166,1.01),(.047,.015,.035),edge,'pelvis',12,6)
# 망토에는 두께와 접힌 윤곽을 주며 목과 발을 직선 판으로 잇지 않는다.
vertices=[];faces=[]
for row in range(7):
    t=row/6;z=1.43-.93*t
    for col in range(13):
        s=col/12; x=(s-.5)*(.44+.21*t);y=.17+.10*t+.025*math.sin(s*math.pi*8)*(t*.6+.4)
        vertices.append((x,y,z+.035*math.cos(s*math.pi*2)*t))
for row in range(6):
    for col in range(12):
        a=row*13+col;faces.append((a,a+13,a+14,a+1))
cloak=mesh('ForestCloak',vertices,faces,cloth,'spine_03')
solid=cloak.modifiers.new('ClothThickness','SOLIDIFY');solid.thickness=.006
bpy.context.view_layer.objects.active=cloak;bpy.ops.object.modifier_apply(modifier=solid.name)
# 얼굴을 가리지 않는 두피 캡과 비대칭 앞머리를 제작한다.
head=rig.data.bones['Head'].head_local
vertices=[];faces=[]
for row,(radius,z) in enumerate([(1.0,.045),(.99,.14),(.76,.22),(.25,.24)]):
    for i in range(24):
        angle=math.tau*i/24
        # 앞쪽의 헤어라인은 올리고 귀·뒤통수는 내려 성인 머리 윤곽을 따른다.
        front=max(0,-math.cos(angle));line=.045*front if row==0 else 0
        vertices.append(tuple(head+Vector((math.sin(angle)*.141*radius,math.cos(angle)*.14*radius,z+line))))
for row in range(3):
    for i in range(24):
        a=row*24+i;b=row*24+(i+1)%24;faces.append((a,a+24,b+24,b))
faces.append(tuple(reversed(range(72,96))))
hair_cap = mesh('SweptHairCap',vertices,faces,hair,'Head')
verify_outward_normals('hair_cap', hair_cap, lambda face: face.center-head-Vector((0,0,.10)))
for i in range(5):
    t=i/4
    ellipsoid('HairLock',head+Vector((-.085+.17*t,-.065+.02*t,.215-.02*t)),(.031,.066,.027),hair,'Head',10,5)
# 검의 손잡이·가드·칼날은 손 뼈의 로컬Z 축을 따라 같은 스킨에 결합한다.
hand=rig.data.bones['hand_r'].matrix_local
weapon_parts = []
blade_vertices=[];blade_faces=[]
for z,w,d in [(-.14,.022,.019),(.11,.022,.019),(.16,.057,.011),(.83,.039,.008),(1.0,.001,.001)]:
    for x,y in [(-w,0),(0,-d),(w,0),(0,d)]:blade_vertices.append(tuple(hand@Vector((x,y,z))))
for row in range(4):
    for i in range(4):
        a=row*4+i;b=row*4+(i+1)%4;blade_faces.append((a,b,b+4,a+4))
weapon_parts.append(mesh('Sword',blade_vertices,blade_faces,edge,'hand_r'))
# Guard and grip are joined with the sword, preserving separate material slots.
for at,size,mat in [((0,0,.125),(.135,.025,.025),iron),((0,0,-.015),(.025,.024,.11),leather),((0,0,-.15),(.033,.033,.03),iron)]:
    center=hand@Vector(at);obj=ellipsoid('SwordDetail',center,size,mat,'hand_r',12,6)
    weapon_parts.append(obj)
    # Ellipsoid is currently in world rest axes: keep the grip aligned with hand Z.
    for v in obj.data.vertices:v.co=center+hand.to_3x3()@(v.co-center)
# All rigid armor has real skin weights. Consolidate per-material instead of keeping one draw per rivet.
# 이름 접두사로 SwordBelt까지 무기로 합치지 않도록 실제 제작 객체만 추적한다.
sword_parts = weapon_parts
body_parts=[o for o in meshes if o not in sword_parts]
def join(parts,name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name
    slots=list(obj.data.materials);unique=[];mapping={}
    for i,mat in enumerate(slots):
        canonical=next((m for m in unique if m.name.split('.')[0]==mat.name.split('.')[0]),mat)
        if canonical not in unique:unique.append(canonical)
        mapping[i]=unique.index(canonical)
    indices=[mapping[p.material_index] for p in obj.data.polygons]
    obj.data.materials.clear()
    for mat in unique:obj.data.materials.append(mat)
    for p,i in zip(obj.data.polygons,indices):p.material_index=i
    return obj
body=join(body_parts,'WarriorBody');sword=join(sword_parts,'Sword')
meshes=[body,sword]
# GLB와 CPU 검수가 같은 정규화된4가중치를 사용하도록 축약 후 명시적으로 고정한다.
for obj in meshes:
    for vertex in obj.data.vertices:
        weights=sorted([(g.group,g.weight) for g in vertex.groups],key=lambda item:item[1],reverse=True)[:4]
        total=sum(weight for _,weight in weights)
        for group in obj.vertex_groups:group.remove([vertex.index])
        for group,weight in weights:obj.vertex_groups[group].add([vertex.index],weight/total,'REPLACE')
# Geometric normalisation, not runtime scale. Include actual boots/head, not sword extent.
points=[body.matrix_world@v.co for v in body.data.vertices]
low=min(v.z for v in points);high=max(v.z for v in points);scale=1.82/(high-low)
for obj in meshes:
    for v in obj.data.vertices:v.co=Vector((v.co.x*scale,v.co.y*scale,(v.co.z-low)*scale))
bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
for bone in rig.data.edit_bones:
    bone.head=Vector((bone.head.x*scale,bone.head.y*scale,(bone.head.z-low)*scale));bone.tail=Vector((bone.tail.x*scale,bone.tail.y*scale,(bone.tail.z-low)*scale))
bpy.ops.object.mode_set(mode='OBJECT')
# Rest-aware FK retarget preserves target limb lengths. Root planar translation is explicitly discarded.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE/'adult-source/UAL1_Standard.glb'))
source=next(o for o in bpy.data.objects if o not in before and o.type=='ARMATURE')
source_world=source.matrix_world.copy();source_rest={b.name:source_world@b.matrix_local for b in source.data.bones}
source_fps=scene.render.fps/scene.render.fps_base
hand_samples={}
ordered=sorted(rig.data.bones,key=lambda b:len(b.parent_recursive));clips={}
for key,prefix in [('idle','Idle_Loop_'),('run','Jog_Fwd_Loop_'),('cast','Sword_Attack_'),('death','Death01_')]:
    original=next(a for a in bpy.data.actions if a.name.startswith(prefix))
    source.animation_data_create();source.animation_data.action=original
    for track in source.animation_data.nla_tracks:track.mute=True
    source.data.pose_position='POSE';rig.data.pose_position='POSE';rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:track.mute=True
    action=bpy.data.actions.new(key);rig.animation_data.action=action
    first,last=original.frame_range;duration=(last-first)/source_fps;count=max(2,round(duration*30)+1)
    previous={}
    for sample in range(count):
        frame=first+(last-first)*sample/(count-1);scene.frame_set(math.floor(frame),subframe=frame%1);bpy.context.view_layer.update()
        poses={b.name:source_world@source.pose.bones[b.name].matrix for b in source.data.bones};desired={}
        for bone in ordered:
            name=bone.name;rest=bone.matrix_local;now=poses[name];bind=source_rest[name]
            rotation=(now.to_quaternion()@bind.to_quaternion().inverted())@rest.to_quaternion()
            if bone.parent:
                parent=bone.parent.name;offset=(bone.parent.matrix_local.inverted()@rest).translation
                if name=='pelvis':
                    delta=(poses[parent].inverted()@now).translation-(source_rest[parent].inverted()@bind).translation
                    offset+=(bone.parent.matrix_local.to_quaternion().inverted()@source_rest[parent].to_quaternion()@delta)*scale
                position=desired[parent]@offset
            else:position=rest.translation.copy()
            matrix=Matrix.Translation(position)@rotation.to_matrix().to_4x4();desired[name]=matrix;pose=rig.pose.bones[name];pose.rotation_mode='QUATERNION'
            kwargs={'parent_matrix':desired[bone.parent.name],'parent_matrix_local':bone.parent.matrix_local} if bone.parent else {}
            pose.matrix_basis=bone.convert_local_to_pose(matrix,rest,invert=True,**kwargs)
            q=pose.rotation_quaternion.copy()
            if name in previous and q.dot(previous[name])<0:q.negate();pose.rotation_quaternion=q
            if name.endswith('_r') and any(name.startswith(f) for f in ['index_','middle_','ring_','pinky_']) and 'leaf' not in name:
                pose.rotation_quaternion=pose.rotation_quaternion@Quaternion((1,0,0),.65)
            previous[name]=pose.rotation_quaternion.copy()
            pose.keyframe_insert('location',frame=sample+1,group=name);pose.keyframe_insert('rotation_quaternion',frame=sample+1,group=name)
        if (key=='idle' and sample==0) or (key=='cast' and sample==round((count-1)*.45)):
            hand_samples[key]=desired['hand_r'].copy()
    for curve in action.fcurves:
        for point in curve.keyframe_points:point.interpolation='LINEAR'
    clips[key]={'seconds':duration,'frames':count,'source':original.name}
# 같은 손 결합을 유지하면서 정지 시 칼끝은 아래, 실제 접촉 시 전방을 향하게 한다.
idle_hand=hand_samples['idle'].to_3x3();attack_hand=hand_samples['cast'].to_3x3()
direction=(idle_hand.inverted()@Vector((0,-.25,-.97))+attack_hand.inverted()@Vector((0,-1,0))).normalized()
local_rotation=Vector((0,0,1)).rotation_difference(direction).to_matrix()
rest_hand=rig.data.bones['hand_r'].matrix_local
rotation=rest_hand.to_3x3()@local_rotation@rest_hand.to_3x3().inverted()
for v in sword.data.vertices:v.co=rest_hand.translation+rotation@(v.co-rest_hand.translation)
# 실제 CPU 변형 정점을 여러 위상에서 검사한다. 휴지 AABB로 접지를 대체하지 않는다.
pose_bounds={}
foot_groups={g.index for g in body.vertex_groups if g.name.startswith(('foot_','ball_'))}
foot_vertices=[v.index for v in body.data.vertices if sum(g.weight for g in v.groups if g.group in foot_groups)>.25]
for key in clips:
    rig.animation_data.action=bpy.data.actions[key]
    first,last=rig.animation_data.action.frame_range;samples=[]
    for phase in [0,.25,.5,.75,1]:
        frame=first+(last-first)*phase;scene.frame_set(math.floor(frame),subframe=frame%1);bpy.context.view_layer.update()
        evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get());deformed=evaluated.to_mesh()
        points=[evaluated.matrix_world@v.co for v in deformed.vertices]
        samples.append({'phase':phase,'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)],'footMinZ':min(points[i].z for i in foot_vertices),'rootXY':list(rig.pose.bones['root'].matrix.translation[:2])})
        evaluated.to_mesh_clear()
    pose_bounds[key]=samples
assert min(s['footMinZ'] for s in pose_bounds['idle']) > -.035
assert max(s['footMinZ'] for s in pose_bounds['idle']) < .04
rig.animation_data.action=None
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for key in clips:
    action=bpy.data.actions[key];track=rig.animation_data.nla_tracks.new();track.name=key
    strip=track.strips.new(key,1,action);strip.action_frame_start,strip.action_frame_end=action.frame_range
for obj in list(bpy.data.objects):
    if obj not in [rig,*meshes]:bpy.data.objects.remove(obj,do_unlink=True)
scene.render.fps=30;scene.render.fps_base=1
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig,*meshes]:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
# Preserve an editable scene with its actual packed maps, skin and clips.
for action in list(bpy.data.actions):
    if action.name not in clips:bpy.data.actions.remove(action,do_unlink=True)
for collection in [bpy.data.meshes,bpy.data.armatures,bpy.data.materials,bpy.data.images]:
    for block in list(collection):
        if block.users==0:collection.remove(block)
bpy.ops.export_scene.gltf(filepath=str(OUT/'model.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_materials='EXPORT',export_animations=True,export_animation_mode='NLA_TRACKS',export_frame_range=False,export_force_sampling=True,export_skins=True,export_cameras=False,export_lights=False)
# GLB에는 네 독립 트랙을 모두 납품하고, 편집 원본은 정지 자세로 연다.
# 다른 트랙을 삭제하지 않고 음소거해 아티스트가 의도한 동작만 켤 수 있다.
for track in rig.animation_data.nla_tracks:
    track.mute = track.name != 'idle'
scene.frame_start = 1
scene.frame_end = clips['idle']['frames']
scene.frame_set(1)
bpy.context.view_layer.update()
source_pose = {
    'track': 'idle',
    'frame': 1,
    'availableTracks': sorted(track.name for track in rig.animation_data.nla_tracks),
    'unmutedTracks': [track.name for track in rig.animation_data.nla_tracks if not track.mute],
}
assert source_pose['unmutedTracks'] == ['idle']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'warrior.blend'),compress=True)
triangles=0
for obj in meshes:obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
proof={'units':'metres','forward':'+Z','height':1.82,'rootScale':[1,1,1],'triangles':triangles,'meshObjects':2,'surfaces':sum(len(o.data.materials) for o in meshes),'clips':clips,'posedGeometry':pose_bounds,'source':'Quaternius FREE Standard CC0 adult Ranger/base/UAL1; original armour, hair, cloak and sword','sourcePose':source_pose,'authoredNormalAudit':normal_audit,'sourceImageNames':sorted(source_image_names),'materialPolicy':'Original face/hands/eyes; Ranger RGB tint .72/.76/.63 baked once; source BaseColor <=1024px, authored surfaces 512px.','sourceLock':'tools/assets/heroes/source-provenance.json','sourceLockSha256':hashlib.sha256((HERE/'source-provenance.json').read_bytes()).hexdigest(),'modelSha256':hashlib.sha256((OUT/'model.glb').read_bytes()).hexdigest(),'sourceBlendSha256':hashlib.sha256((OUT/'warrior.blend').read_bytes()).hexdigest(),'actorAtlasSha256':hashlib.sha256((PROJECT/'assets/materials/actors/surface_atlas.bin').read_bytes()).hexdigest(),'designReference':'assets/source/entry-redesign/warrior.png','designReferenceSha256':hashlib.sha256((PROJECT/'assets/source/entry-redesign/warrior.png').read_bytes()).hexdigest(),'generatorSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'blender':bpy.app.version_string,'notes':'In-place planar root; target-rest FK; base face/hands protected. CPU and runtime pose/contact/visual review required.'}
(OUT/'asset.json').write_text(json.dumps(proof,indent=2)+'\n')
print('WARRIOR_EXPORT',json.dumps(proof))
