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


def build(record):
    image=cv2.imread(str(ROOT/record['png']),cv2.IMREAD_UNCHANGED)
    height,width=image.shape[:2]
    points=[]
    def add(p):
        q=np.asarray(p,float)
        for i,v in enumerate(points):
            if np.linalg.norm(q-v)<1:return i
        points.append(q)
        return len(points)-1
    for edge in record['segments']:
        a,b=np.array(edge['a']),np.array(edge['b'])
        for t in np.linspace(0,1,max(2,int(np.linalg.norm(b-a)/12))):add(a*(1-t)+b*t)
    for q in [[0,0],[width-1,0],[width-1,height-1],[0,height-1]]:add(q)
    source=np.array(points);count=len(source);subdivide=cv2.Subdiv2D((0,0,width,height))
    for q in source:subdivide.insert(tuple(map(float,q)))
    triangles=[]
    for raw in subdivide.getTriangleList().reshape(-1,3,2):
        ids=[int(np.argmin(np.linalg.norm(source-q,axis=1))) for q in raw]
        if max(np.linalg.norm(source[i]-q) for i,q in zip(ids,raw))<.1:triangles.append(ids)
    rows=[];rhs=[]
    for edge in record['segments']:
        a,b=np.array(edge['a']),np.array(edge['b']);axis=math.radians(edge['axis']);normal=np.array([-math.sin(axis),math.cos(axis)])
        direction=b-a;length=np.linalg.norm(direction);chain=[]
        for i,q in enumerate(source):
            t=np.dot(q-a,direction)/(length*length)
            if -.001<=t<=1.001 and abs(cross(direction,q-a))/length<.05:chain.append((t,i))
        chain.sort()
        for (_,i),(_,j) in zip(chain,chain[1:]):
            row=np.zeros(count*2);row[i*2:i*2+2]=-normal;row[j*2:j*2+2]=normal;rows.append(row);rhs.append(-normal@(source[j]-source[i]))
    for i in range(count-4,count):
        for axis in range(2):
            row=np.zeros(count*2);row[i*2+axis]=1;rows.append(row);rhs.append(0.)
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
        if cross(b-a,c-a)*cross(e-d,f-d)<=0:raise ValueError('projection folds a texture triangle')
    return dict(source=record['png'],source_sha256=hashlib.sha256((ROOT/record['png']).read_bytes()).hexdigest(),points=[[round(float(v),4) for v in np.r_[a,b]] for a,b in zip(source,target)],triangles=triangles,calibration=record['segments'])


if __name__=='__main__':
    catalog={key:build(record) for key,record in json.loads(MEASURE.read_text()).items()}
    (ROOT/'assets/data/art_warps.json').write_text(json.dumps(catalog,separators=(',',':'))+'\n')
    for key,mesh in catalog.items():print(key,len(mesh['points']),'vertices',len(mesh['triangles']),'triangles')
