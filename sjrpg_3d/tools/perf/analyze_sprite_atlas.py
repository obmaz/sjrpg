#!/usr/bin/env python3
"""Read source alpha to measure atlas alignment; never modifies image pixels."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image,ImageFilter

root=Path(__file__).resolve().parents[2]
config=json.loads((root/"assets/data/cave_crawler_sprite.json").read_text())
parser=argparse.ArgumentParser()
parser.add_argument("--source",action="store_true",help="Audit newly generated source before runtime adoption")
parser.add_argument("--columns",type=int)
args=parser.parse_args()
if args.columns:
    config["columns"]=args.columns
    config["walk_columns"]=list(range(args.columns))
    config["attack_column"]=args.columns-1
audit={}
for name,columns,rows,prefix in [("cave_crawler",config["columns"],config["rows"],""),("cave_crawler_corpses",config["corpse_columns"],config["corpse_rows"],"corpse_")]:
    path=(root/"assets/source/cave-crawler"/("generated-atlas.png" if not prefix else "generated-corpses.png")) if args.source else root/"assets/art/monsters"/(name+".png")
    image=Image.open(path)
    assert image.mode=="RGBA",(name,image.mode)
    assert image.getchannel("A").getextrema()==(0,255),(name,"real alpha required")
    w,h=image.size
    pivots=[];fractions=[];widths=[];boxes=[];hashes=[]
    for row in range(rows):
        for column in range(columns):
            left=round(column*w/columns);top=round(row*h/rows)
            right=round((column+1)*w/columns);bottom=round((row+1)*h/rows)
            cw,ch=right-left,bottom-top
            hashes.append(hashlib.sha256(image.crop((left,top,right,bottom)).tobytes()).hexdigest())
            alpha=image.getchannel("A").crop((left,top,right,bottom))
            # A read-only eroded mask excludes isolated generation speckles.
            mask=alpha.point(lambda v:255 if v>=96 else 0).filter(ImageFilter.MinFilter(3))
            box=mask.getbbox()
            assert box is not None,(name,row,column,"empty frame")
            x0,y0,x1,y1=box
            assert x0>1 and y0>1 and x1<cw-1 and y1<ch-1,(name,row,column,"cell clipped",box)
            occupied=sum(1 for value in mask.getdata() if value)
            assert 0.025<occupied/(cw*ch)<0.80,(name,row,column,"invalid alpha occupancy")
            support_top=max(y0,y1-max(8,round((y1-y0)*0.20)))
            support=mask.crop((0,support_top,cw,ch)).getbbox()
            px=(support[0]+support[2])/2 if support else (x0+x1)/2
            if prefix:
                px=(x0+x1)/2
            pivots.append([round(px/cw,6),round(min(ch,y1+1)/ch,6)])
            fractions.append(round((y1-y0+2)/ch,6))
            widths.append(round((x1-x0+2)/cw,6))
            boxes.append({"row":row,"column":column,"rect":[left,top,cw,ch],"alpha_bounds":list(box),"occupied":occupied})
    config[prefix+"frame_pivots"]=pivots
    config[prefix+"frame_body_fractions"]=fractions
    if prefix:
        config["corpse_frame_width_fractions"]=widths
    else:
        config["body_fraction"]=max(fractions)
    assert len(set(hashes))==columns*rows,(name,"duplicated artwork frames")
    opaque=[pixel for pixel in image.getdata() if pixel[3]>=224]
    luminance=sum(.2126*p[0]+.7152*p[1]+.0722*p[2] for p in opaque)/max(1,len(opaque))
    audit[name]={"mean_opaque_luminance":round(luminance,3),"rgba8_mip_bytes_estimate":round(w*h*4*4/3),"size":[w,h],"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"grid":[columns,rows],"frames":boxes}
out=root/"build/gameplay-review";out.mkdir(parents=True,exist_ok=True)
(out/"atlas-audit.json").write_text(json.dumps(audit,indent=2)+"\n")
(out/"measured-sprite-metadata.json").write_text(json.dumps(config,indent=2)+"\n")
print("SPRITE_ATLAS_AUDIT "+json.dumps(audit,separators=(",",":")))
print("SPRITE_ATLAS_METADATA "+json.dumps(config,separators=(",",":")))
