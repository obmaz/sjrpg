#!/usr/bin/env python3
"""Pack revised town illustrations and derive placement/collision data from measured source coordinates.
Run python3 tools/extract/town_art.py; extract_data.py also applies merge() after original extraction.
The collision rectangles are geometric models, never evidence of the illustration's projection.
"""
import copy
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image
import chapel

ROOT = Path(__file__).resolve().parents[2]
M = json.loads(Path(__file__).with_name('town_art_measure.json').read_text())
WARPS = json.loads((ROOT/'assets/data/art_warps.json').read_text())
COS = math.sqrt(3)/2
LAYOUT = json.loads(Path(__file__).with_name('town_clearance.json').read_text())


def warp(key, point, inverse=False):
    if key not in WARPS:
        return np.asarray(point, float)
    mesh = WARPS[key]
    points = np.array(mesh['points'])
    src = points[:, 2:] if inverse else points[:, :2]
    dst = points[:, :2] if inverse else points[:, 2:]
    for ids in mesh['triangles']:
        a,b,c = src[ids]
        matrix = np.array([b-a,c-a]).T
        if abs(np.linalg.det(matrix)) < 1e-6:
            continue
        u,v = np.linalg.solve(matrix,np.asarray(point)-a)
        if u>=-.001 and v>=-.001 and u+v<=1.001:
            return dst[ids[0]]*(1-u-v)+dst[ids[1]]*u+dst[ids[2]]*v
    return np.asarray(point,float)


def correction(config, point, inverse=False):
    yscale,skew = config.get('gvs',1), config.get('gvk',0)
    if inverse:
        q=np.array([point[0],(point[1]-point[0]*skew)/yscale])
        return warp(config.get('warp',''),q,True)
    q=warp(config.get('warp',''),point)
    return np.array([q[0],q[1]*yscale+q[0]*skew])


def uv(world, data):
    x,y=np.asarray(world)/.97
    ground=np.array([(x/COS+y/.5)/2,(y/.5-x/COS)/2])
    return (ground/data['extent']+data['spawn_uv']).tolist()


def derive(key, config, data):
    im=Image.open(ROOT/config['png']);p=config['packing'];x,y=config['xy'];ref=M['reference'][key]
    F=correction(config,config['foot']);L,R,_=map(lambda q:correction(config,q),config['ground'])
    # A rectangular collision model calibrated to the visible footprint; the art audit uses separate samples.
    L=F+np.array([-COS,-.5])*np.linalg.norm(L-F)
    R=F+np.array([COS,-.5])*np.linalg.norm(R-F)
    polygon=np.array([L,L+R-F,R,F]);scale=ref['width']/np.ptp(polygon[:,0])
    centre_offset=(polygon.mean(0)-F)*scale
    placement=np.array(ref['center'])-centre_offset
    height=config['foot'][1]*p
    origin=np.array([x,y]);raw_foot=np.array(config['foot'])
    s=dict(sheet='forest-isometric-town',source=[x,y,round(im.width*p),round(im.height*p)],foot=(origin+raw_foot*p).tolist(),height=height,origin=[0,0],packing=p,world_height=scale*height/p/.97,body=None,gvs=config.get('gvs',1),gvk=config.get('gvk',0))
    if 'warp' in config:s['warp']=config['warp']
    frame=dict(ground=[(origin+correction(config,q,True)*p).tolist() for q in polygon],height=height,foot=s['foot'])
    data['sprites'][key]=s;data['frames'][key]=frame;data['placements'][key]=[uv(placement,data),s['world_height']/56.64]
    if config.get('approach_native'):
        # Anchor service NPCs to the new doorway, then leave clearance beyond
        # the measured solid base (a paved apron can project past the door).
        anchor=correction(config,config['approach_native'])
        normal=np.array([-.5,COS])
        clearance=float(config.get('approach_clearance',35.0))/scale
        # A doorway on the receding face can be outside the solid yet still
        # sort behind this one-piece building. Put the actual service resident
        # beyond its front-most painted foot, keeping world position and draw order together.
        sort_clearance=float(config.get('approach_sort_clearance',12.0))/scale
        offset=max(clearance,clearance-np.dot(anchor-F,normal),
                   (F[1]+sort_clearance-anchor[1])/normal[1])
        data['approaches'][key]=correction(config,anchor+normal*offset,True).tolist()
    elif ref['approach']:
        target=(np.array(ref['approach'])-placement)/scale+F
        data['approaches'][key]=correction(config,target,True).tolist()


def merge(data):
    # Keep source-measured building centres and physical scales while the outer
    # walls move away. Re-derive UV from those world positions at the new extent.
    data['extent'] = LAYOUT['extent']
    data['town_clearance'] = copy.deepcopy(LAYOUT)
    for key,config in M['buildings'].items():derive(key,config,data)
    # Fountain pixels and geometry are retained; only their atlas location changes.
    pool=json.loads(Path(__file__).with_name('pool_measure.json').read_text());s=copy.deepcopy(pool['sprite']);frame=copy.deepcopy(pool['frame']);old=np.array(s['source'][:2]);new=np.array([6,2054]);shift=new-old
    s['source'][:2]=new.tolist();s['foot']=(np.array(s['foot'])+shift).tolist();s['origin']=[0,0];s['packing']=1
    frame['ground']=[(np.array(q)+shift).tolist() for q in frame['ground']];frame['foot']=s['foot']
    data['sprites']['pool']=s;data['frames']['pool']=frame
    chapel.merge(data)
    # The measured authoring reference owns the centre and physical width. The
    # same native warp as drawing must also locate the low replacement yard.
    s=data['sprites']['chapel'];raw=np.array(data['frames']['chapel']['ground']);f=np.array(s['foot']);p=float(s['packing']);origin=np.array(s['origin']);src=np.array(s['source'][:2]);native=origin+(raw-src)/p;native_foot=origin+(f-src)/p
    config=dict(gvs=s['gvs'],gvk=s['gvk'],warp=s.get('warp',''));projected_foot=correction(config,native_foot)
    if chapel.MEASURE.get('ground_model') == 'main_body_rectangle':
        # The nave rectangle calibrates placement/scale. The projecting porch
        # has its own observed compound blocker and is never certified by this model.
        left=correction(config,chapel.MEASURE['foot_L'])
        right=correction(config,chapel.MEASURE['foot_R'])
        left=projected_foot+np.array([-COS,-.5])*np.linalg.norm(left-projected_foot)
        right=projected_foot+np.array([COS,-.5])*np.linalg.norm(right-projected_foot)
        projected=[left,left+right-projected_foot,right,projected_foot]
        native=np.array([correction(config,point,True) for point in projected])
        data['frames']['chapel']['ground']=[(src+(point-origin)*p).tolist() for point in native]
    q=np.array([correction(config,point)-projected_foot for point in native])*p
    ref=M['reference']['chapel'];scale=ref['width']/np.ptp(q[:,0]);s['world_height']=scale*s['height']/.97
    placement=np.array(ref['center'])-q.mean(0)*scale;data['placements']['chapel']=[uv(placement,data),s['world_height']/56.64]
    return data


def pack():
    sheet=Image.new('RGBA',(2048,2940),(0,0,0,0))
    for key,c in M['buildings'].items():
        im=Image.open(ROOT/c['png']).convert('RGBA');p=c['packing'];size=(round(im.width*p),round(im.height*p));image=im.convert('RGBa').resize(size,Image.Resampling.LANCZOS).convert('RGBA');image=Image.fromarray(chapel._bleed(np.array(image)));sheet.paste(image,tuple(c['xy']))
    pool=Image.open(ROOT/'assets/source/environment/fountain/town-pool.png');sheet.paste(pool,(6,2054));target=ROOT/'assets/sprites/village/town.webp';temporary=target.with_suffix('.tmp')
    sheet.save(temporary,'WEBP',quality=94,alpha_quality=100,method=6,exact=True);temporary.replace(target)
    chapel.pack()


if __name__=='__main__':
    import sys
    if '--data' not in sys.argv:pack()
    path=ROOT/'assets/data/village.json';data=json.loads(path.read_text());path.write_text(json.dumps(merge(data),indent=1)+'\n')
    print('revised town art packed/merged')
