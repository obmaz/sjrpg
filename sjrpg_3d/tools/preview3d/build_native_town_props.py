"""Reproducible native prop mesh authoring; default writes a geometry plan only.

Run with Blender to export the two shared native models:
  blender -b --python tools/build_native_town_props.py -- --export --out <asset-dir>

Authoring coordinates are metres, Y-up, front +Z. Blender conversion is explicit;
GLB materials are binding slots for shared runtime materials, with no image copies.
"""
from __future__ import annotations
import argparse
from dataclasses import dataclass, field
import itertools
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
TAU = math.tau


def add(a, b): return tuple(x+y for x,y in zip(a,b))
def sub(a, b): return tuple(x-y for x,y in zip(a,b))
def mul(a, s): return tuple(x*s for x in a)
def dot(a, b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return mul(a, 1/max(math.sqrt(dot(a,a)), 1e-9))


@dataclass
class Group:
    vertices: list = field(default_factory=list)
    triangles: list = field(default_factory=list)

    def face(self, points, outward=None):
        points = list(points)
        if outward is not None and dot(cross(sub(points[1],points[0]), sub(points[2],points[0])), outward) < 0:
            points.reverse()
        first=len(self.vertices)
        self.vertices.extend(points)
        self.triangles.extend((first, first+i, first+i+1) for i in range(1,len(points)-1))


@dataclass
class Model:
    role: str
    groups: dict = field(default_factory=dict)
    sockets: dict = field(default_factory=dict)

    def group(self, material): return self.groups.setdefault(material, Group())

    def bevel_box(self, at, size, bevel=.018, material='limestone'):
        """Actual 26-face chamfered box, 44 triangles; never a painted edge."""
        h=mul(size,.5); b=min(bevel,min(h)*.45)
        corners=list(itertools.product((-1,1), repeat=3))
        v={}
        for corner in corners:
            for axis in range(3):
                v[corner,axis]=add(at,tuple(corner[i]*(h[i] if i==axis else h[i]-b) for i in range(3)))
        g=self.group(material)
        for axis in range(3):
            other=[i for i in range(3) if i!=axis]
            for sign in (-1,1):
                quad=[]
                for a,z in [(-1,-1),(-1,1),(1,1),(1,-1)]:
                    c=[0,0,0];c[axis]=sign;c[other[0]]=a;c[other[1]]=z
                    quad.append(v[tuple(c),axis])
                n=[0,0,0];n[axis]=sign;g.face(quad,n)
        for a,z in itertools.combinations(range(3),2):
            free=3-a-z
            for sa,sz in itertools.product((-1,1),repeat=2):
                c=[0,0,0];c[a]=sa;c[z]=sz;c[free]=-1
                d=c.copy();d[free]=1
                n=[0,0,0];n[a]=sa;n[z]=sz
                g.face([v[tuple(c),a],v[tuple(c),z],v[tuple(d),z],v[tuple(d),a]],n)
        for c in corners: g.face([v[c,a] for a in range(3)], c)

    def sector(self, profile, angle_a, angle_b, steps=4, material='limestone'):
        """Closed revolved masonry wedge; profile is the real wall thickness."""
        g=self.group(material); n=len(profile)
        strips=[]
        for j in range(steps+1):
            a=angle_a+(angle_b-angle_a)*j/steps
            strips.append([(r*math.cos(a),y,r*math.sin(a)) for r,y in profile])
        for j in range(steps):
            for i in range(n):
                g.face([strips[j][i],strips[j][(i+1)%n],strips[j+1][(i+1)%n],strips[j+1][i]])
        # Convex bevel profiles make these cap fans valid, without crossing the basin void.
        g.face(reversed(strips[0]));g.face(strips[-1])

    def disc(self, radius, height, segments=48, material='water'):
        g=self.group(material)
        for i in range(segments):
            a,b=i*TAU/segments,(i+1)*TAU/segments
            g.face([(0,height,0),(radius*math.cos(a),height,radius*math.sin(a)),(radius*math.cos(b),height,radius*math.sin(b))],(0,1,0))

    def tube(self, points, radius, sides=10, material='bronze'):
        g=self.group(material); rings=[]
        for i,p in enumerate(points):
            tangent=unit(sub(points[min(i+1,len(points)-1)],points[max(i-1,0)]))
            side=unit(cross(tangent,(0,1,0) if abs(tangent[1])<.9 else (1,0,0)))
            up=cross(tangent,side)
            rings.append([add(p,add(mul(side,math.cos(j*TAU/sides)*radius),mul(up,math.sin(j*TAU/sides)*radius))) for j in range(sides)])
        for i in range(len(rings)-1):
            for j in range(sides): g.face([rings[i][j],rings[i][(j+1)%sides],rings[i+1][(j+1)%sides],rings[i+1][j]])
        g.face(reversed(rings[0]));g.face(rings[-1])

    def sphere(self, at, radius, longitude=24, latitude=12, material='limestone'):
        g=self.group(material)
        for j in range(latitude):
            aa,bb=math.pi*j/latitude,math.pi*(j+1)/latitude
            for i in range(longitude):
                a,b=TAU*i/longitude,TAU*(i+1)/longitude
                p=[add(at,(radius*math.sin(h)*math.cos(v),radius*math.cos(h),radius*math.sin(h)*math.sin(v))) for h,v in [(aa,a),(bb,a),(bb,b),(aa,b)]]
                if j==0: p=[p[0],p[1],p[2]]
                elif j==latitude-1: p=[p[0],p[1],p[3]]
                g.face(p,sub(tuple(sum(q[k] for q in p)/len(p) for k in range(3)),at))

    def arch_wedge(self, inner, outer, spring, depth, a, b, steps=3):
        g=self.group('limestone')
        def ring(r,z): return [(r*math.cos(t),spring+r*math.sin(t),z) for t in [a+(b-a)*i/steps for i in range(steps+1)]]
        fi,fo=ring(inner,depth*.5),ring(outer,depth*.5)
        bi,bo=ring(inner,-depth*.5),ring(outer,-depth*.5)
        for i in range(steps):
            g.face([fi[i],fo[i],fo[i+1],fi[i+1]],(0,0,1))
            g.face([bi[i],bi[i+1],bo[i+1],bo[i]],(0,0,-1))
            g.face([fo[i],bo[i],bo[i+1],fo[i+1]])
            g.face([fi[i+1],bi[i+1],bi[i],fi[i]])
        g.face([fi[0],bi[0],bo[0],fo[0]])
        g.face([fi[-1],fo[-1],bo[-1],bi[-1]])

    def plan(self):
        all_vertices=[p for g in self.groups.values() for p in g.vertices]
        return {'role':self.role,'triangles':sum(len(g.triangles) for g in self.groups.values()),
                'material_groups':{k:len(v.triangles) for k,v in self.groups.items()},
                'bounds_m':{'min':[min(p[i] for p in all_vertices) for i in range(3)],'max':[max(p[i] for p in all_vertices) for i in range(3)]},
                'sockets':self.sockets,'pivot':'base centre at Y0','up':'+Y','front':'+Z','baked_scale':[1,1,1]}


def fountain():
    m=Model('fountain')
    # Four individual base slabs, micro-bevels and real joints; within 2.615x2.646m footprint.
    for x,z in itertools.product((-.652,.652),repeat=2): m.bevel_box((x,.08,z),(1.296,.16,1.296),.018)
    m.disc(.985,.18,48,'limestone')
    profile=[(.945,.20),(.965,.18),(1.12,.18),(1.14,.20),(1.14,.53),(1.12,.55),(.965,.55),(.945,.53)]
    for i in range(16): m.sector(profile, i*TAU/16+.004,(i+1)*TAU/16-.004)
    m.bevel_box((0,.30,0),(.58,.24,.58),.024)
    # Carved square pier: inset field between proud corner fillets and upper/lower collars.
    m.bevel_box((0,.91,0),(.34,1.02,.34),.014)
    for x,z in itertools.product((-.183,.183),repeat=2): m.bevel_box((x,.91,z),(.065,1.02,.065),.012)
    m.bevel_box((0,.47,0),(.46,.10,.46),.016)
    m.bevel_box((0,1.40,0),(.52,.13,.52),.020)
    m.sphere((0,1.72,0),.22,24,14)
    # Small upper feed cup under the finial, and a lower basin: actual two water levels.
    cup=[(.13,1.465),(.145,1.45),(.225,1.45),(.24,1.465),(.24,1.525),(.225,1.54),(.145,1.54),(.13,1.525)]
    m.sector(cup,0,TAU,32)
    m.disc(.128,1.505,24)
    m.disc(.936,.345,64)
    for axis in (0,2):
        spout=[]
        for r,y in [(.19,1.245),(.27,1.245),(.33,1.215),(.36,1.18)]:
            p=[0,y,0];p[axis]=r;spout.append(tuple(p))
        m.tube(spout,.047,12)
        # Narrow real water tube follows a ballistic-looking curve, with small shader shimmer only.
        jet=[]
        for i in range(17):
            t=i/16;r=.36+.51*t;y=1.18+.15*t-.985*t*t
            p=[0,y,0];p[axis]=r;jet.append(tuple(p))
        m.tube(jet,.014,6,'water')
        m.sockets[f'spout_{axis}']={'start':spout[-1],'splash':jet[-1]}
    return m


def portal():
    m=Model('warp-gate')
    for x in (-1.165,-.39,.39,1.165): m.bevel_box((x,.09,0),(.768,.18,1.28),.018)
    for sign in (-1,1):
        x=sign*1.12
        m.bevel_box((x,.29,0),(.61,.22,.76),.018)
        # 32cm stone courses, with genuine recessed panels and 8mm joints.
        for i in range(8): m.bevel_box((x,.56+i*.32,0),(.46,.312,.56),.014)
        for edge in (-1,1): m.bevel_box((x+edge*.185,1.46,.315),(.075,1.88,.085),.012)
        m.bevel_box((x,2.88,0),(.68,.15,.78),.018)
        m.bevel_box((x,3.01,0),(.61,.11,.70),.018)
        # Thin dark oak rebate, largely behind the stone; restrained bronze anchor plates.
        m.bevel_box((sign*.82,1.07,-.18),(.055,1.66,.10),.008,'timber')
        m.bevel_box((x,.49,.392),(.14,.10,.018),.003,'bronze')
    inner,outer,spring=.81,1.035,1.72
    for i in range(11):
        m.arch_wedge(inner,outer,spring,.52,i*math.pi/11+.006,(i+1)*math.pi/11-.006)
    m.bevel_box((0,2.72,.035),(.29,.33,.64),.018)
    # An actual shaped vertical opening surface, not an illustrated gate on a billboard.
    boundary=[(-inner,.18,.035),(inner,.18,.035),(inner,spring,.035)]
    boundary += [(inner*math.cos(i*math.pi/32),spring+inner*math.sin(i*math.pi/32),.035) for i in range(1,33)]
    g=m.group('portal');c=(0,1.20,.035)
    for i in range(len(boundary)):g.face([c,boundary[i],boundary[(i+1)%len(boundary)]],(0,0,1))
    m.sockets['portal_opening']={'width':inner*2,'height':spring+inner-.18,'bottom':.18,'spring':spring,'plane_z':.035}
    return m


def export_blender(model, target):
    import bpy
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for name,g in model.groups.items():
        mesh=bpy.data.meshes.new(model.role+'_'+name)
        # Blender Z-up -> glTF/Godot Y-up, front +Z, without runtime scale corrections.
        mesh.from_pydata([(x,-z,y) for x,y,z in g.vertices],[],g.triangles);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        material=bpy.data.materials.get(name) or bpy.data.materials.new(name)
        material.diffuse_color={'limestone':(.58,.57,.52,1),'bronze':(.30,.23,.15,1),'timber':(.18,.12,.08,1),'water':(.06,.29,.31,.7),'portal':(.05,.35,.40,.65)}[name]
        obj.data.materials.append(material)
        # Planar metre UVs are a fallback; runtime stone uses shared world triplanar 2.56m.
        uv=mesh.uv_layers.new(name='MetreUV')
        for p in mesh.polygons:
            for li in p.loop_indices:
                co=mesh.vertices[mesh.loops[li].vertex_index].co
                if name=='portal': uv.data[li].uv=(co.x/1.62+.5,(co.z-.18)/2.35)
                elif name=='water': uv.data[li].uv=(co.x/2.56,-co.y/2.56)
                else: uv.data[li].uv=(co.x/2.56,co.z/2.56)
        obj['material_binding']=name
    target.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_yup=True,export_image_format='NONE',export_cameras=False,export_lights=False)


def main():
    argv=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]
    p=argparse.ArgumentParser();p.add_argument('--export',action='store_true');p.add_argument('--out',type=Path,default=ROOT/'assets/art/preview3d');args=p.parse_args(argv)
    models=[fountain(),portal()];plans=[m.plan() for m in models]
    for model,limit in zip(models,(8000,6000)):
        plan=model.plan();assert plan['triangles']<limit and len(model.groups)<=6,plan
    output=ROOT/'assets/source/preview3d/native-town-props/geometry-plan.json';output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps({'status':'authored mesh-buffer plan; actual export metrics recorded in provenance.json','models':plans},indent=2)+'\n')
    print(json.dumps(plans,indent=2))
    if args.export:
        for model,name in zip(models,('native-fountain.glb','native-warp-gate.glb')):export_blender(model,args.out/name)

if __name__=='__main__':main()
