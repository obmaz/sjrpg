#!/usr/bin/env python3
"""Calibrate texture projection from visible structural segments, without altering illustration pixels.
Requires numpy and opencv-python-headless (authoring only). Runtime/CI reads the generated mesh.
The constrained smooth displacement preserves the transparent image boundary and rejects folded triangles.
"""
import hashlib
import json
import math
from pathlib import Path
import cv2
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
MEASURE=Path(__file__).with_name('art_warp_measure.json')


def cross(a,b):
    return a[0]*b[1]-a[1]*b[0]


def segment_chain(source,edge,tolerance,extent=.001):
    a,b=np.asarray(edge['a']),np.asarray(edge['b']);direction=b-a
    length=np.linalg.norm(direction);result=[]
    for i,q in enumerate(source):
        t=np.dot(q-a,direction)/(length*length)
        if -extent<=t<=1+extent and abs(cross(direction,q-a))/length<tolerance:
            result.append((t,i))
    return sorted(result)


def recover_segments(source,triangles,chains):
    """Recover painted line segments as mesh edges; an unconstrained Delaunay
    may cross between its sparse samples and bend the actual intervening pixels.
    Only convex adjacent quads are flipped, so the source mesh stays planar.
    """
    protected=set()
    def orient(ids):
        a,b,c=source[ids]
        return ids if cross(b-a,c-a)>0 else [ids[0],ids[2],ids[1]]
    triangles=[orient(ids) for ids in triangles]
    def adjacency():
        result={}
        for index,(a,b,c) in enumerate(triangles):
            for i,j in [(a,b),(b,c),(c,a)]:result.setdefault(tuple(sorted((i,j))),[]).append(index)
        return result
    def crosses(i,j,a,b):
        if len({i,j,a,b})<4:return False
        p,q,r,s=source[[i,j,a,b]]
        return cross(q-p,r-p)*cross(q-p,s-p)<-1e-10 and cross(s-r,p-r)*cross(s-r,q-r)<-1e-10
    for chain in chains:
        for (_,i),(_,j) in zip(chain,chain[1:]):
            wanted=tuple(sorted((i,j)));adj=adjacency()
            queue=[edge for edge in adj if crosses(i,j,*edge)]
            attempts=0
            while wanted not in adj:
                if not queue or attempts>len(source)*20:
                    raise ValueError('cannot recover a painted structural segment without crossing another')
                edge=queue.pop(0);attempts+=1
                if edge not in adj:continue
                owners=adj[edge]
                if edge in protected or len(owners)!=2:
                    raise ValueError('painted segments cross without a shared source vertex')
                a,b=edge;c=next(v for v in triangles[owners[0]] if v not in edge)
                d=next(v for v in triangles[owners[1]] if v not in edge)
                if not crosses(a,b,c,d):
                    queue.append(edge);continue
                triangles[owners[0]]=orient([c,d,a]);triangles[owners[1]]=orient([d,c,b])
                adj=adjacency()
                if crosses(i,j,c,d):queue.append(tuple(sorted((c,d))))
            protected.add(wanted)
    return triangles


def build(record):
    image=cv2.imread(str(ROOT/record['png']),cv2.IMREAD_UNCHANGED)
    height,width=image.shape[:2]
    points=[]
    merge_distance=record.get('point_merge_distance',1.0)
    def add(p):
        q=np.asarray(p,float)
        for i,v in enumerate(points):
            if np.linalg.norm(q-v)<merge_distance:return i
        points.append(q)
        return len(points)-1
    for edge in record['segments']:
        a,b=np.array(edge['a']),np.array(edge['b'])
        for t in np.linspace(0,1,max(2,int(np.linalg.norm(b-a)/12))):add(a*(1-t)+b*t)
    if record.get('constrain_segments',False):
        for index,first in enumerate(record['segments']):
            a,b=np.asarray(first['a']),np.asarray(first['b']);ab=b-a
            for second in record['segments'][index+1:]:
                c,d=np.asarray(second['a']),np.asarray(second['b']);cd=d-c;den=cross(ab,cd)
                if abs(den)<1e-9:continue
                t=cross(c-a,cd)/den;u=cross(c-a,ab)/den
                if 0<t<1 and 0<u<1:add(a+ab*t)
    targets=[(add(q['source']),np.asarray(q['target'],float)) for q in record.get('targets',[])]
    pins=[add(q) for q in record.get('pins',[])]
    # Optional free subdivision points let disjoint parallel painted features
    # keep an invertible interpolation across the space between their ends.
    for q in record.get('support_points',[]):add(q)
    boundary=[add(q) for q in [[0,0],[width-1,0],[width-1,height-1],[0,height-1]]]
    step=record.get('boundary_step',0)
    if step:
        for x in range(step,width-1,step):
            boundary.extend([add([x,0]),add([x,height-1])])
        for y in range(step,height-1,step):
            boundary.extend([add([0,y]),add([width-1,y])])
    source=np.array(points);count=len(source);subdivide=cv2.Subdiv2D((0,0,width,height))
    for q in source:subdivide.insert(tuple(map(float,q)))
    triangles=[]
    for raw in subdivide.getTriangleList().reshape(-1,3,2):
        ids=[int(np.argmin(np.linalg.norm(source-q,axis=1))) for q in raw]
        if max(np.linalg.norm(source[i]-q) for i,q in zip(ids,raw))<.1:triangles.append(ids)
    chains=[segment_chain(source,edge,record.get('line_membership_distance',.05),
                          .00001 if record.get('constrain_segments',False) else .001) for edge in record['segments']]
    if record.get('constrain_segments',False):triangles=recover_segments(source,triangles,chains)
    rows=[];rhs=[]
    for edge,chain in zip(record['segments'],chains):
        a,b=np.array(edge['a']),np.array(edge['b']);axis=math.radians(edge['axis']);normal=np.array([-math.sin(axis),math.cos(axis)])
        for (_,i),(_,j) in zip(chain,chain[1:]):
            row=np.zeros(count*2);row[i*2:i*2+2]=-normal;row[j*2:j*2+2]=normal;rows.append(row);rhs.append(-normal@(source[j]-source[i]))
    for i in boundary:
        for axis in range(2):
            if axis==1 and record.get('free_y_boundary',False):continue
            row=np.zeros(count*2);row[i*2+axis]=1;rows.append(row);rhs.append(0.)
    for i in pins:
        for axis in range(2):
            row=np.zeros(count*2);row[i*2+axis]=1;rows.append(row);rhs.append(0.)
    if record.get('vertical_only',False):
        for i in range(count):
            row=np.zeros(count*2);row[i*2]=1;rows.append(row);rhs.append(0.)
    for i,target in targets:
        for axis in range(2):
            row=np.zeros(count*2);row[i*2+axis]=1;rows.append(row);rhs.append(target[axis]-source[i,axis])
    energy=np.eye(count)*.0001;neighbors=set()
    for a,b,c in triangles:
        neighbors.update(tuple(sorted(pair)) for pair in [(a,b),(b,c),(c,a)])
    for i,j in neighbors:
        weight=1/max(1.,np.linalg.norm(source[i]-source[j]))**1.5
        energy[i,i]+=weight;energy[j,j]+=weight;energy[i,j]-=weight;energy[j,i]-=weight
    constraints=np.array(rows);projection=np.linalg.solve(np.kron(energy,np.eye(2)),constraints.T)
    shift=projection@np.linalg.pinv(constraints@projection,rcond=1e-9)@np.array(rhs)
    target=source+shift.reshape(-1,2)
    if np.max(np.abs(constraints@shift-np.array(rhs)))>.01:raise ValueError('inconsistent structural constraints')
    for ids in triangles:
        a,b,c=source[ids];d,e,f=target[ids]
        if cross(b-a,c-a)*cross(e-d,f-d)<=0:
            raise ValueError('projection folds a texture triangle: source=%s target=%s' % (source[ids].round(3).tolist(), target[ids].round(3).tolist()))
    pad_y=record.get('pad_y',0)
    target[:,1]+=pad_y
    return dict(source=record['png'],source_sha256=hashlib.sha256((ROOT/record['png']).read_bytes()).hexdigest(),points=[[round(float(v),4) for v in np.r_[a,b]] for a,b in zip(source,target)],triangles=triangles,calibration=record['segments'],canvas_size=[width,height+pad_y*2])


if __name__=='__main__':
    catalog={key:build(record) for key,record in json.loads(MEASURE.read_text()).items()}
    (ROOT/'assets/data/art_warps.json').write_text(json.dumps(catalog,separators=(',',':'))+'\n')
    for key,mesh in catalog.items():print(key,len(mesh['points']),'vertices',len(mesh['triangles']),'triangles')
