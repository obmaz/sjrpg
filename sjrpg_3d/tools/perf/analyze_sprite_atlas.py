#!/usr/bin/env python3
"""Read source alpha to measure atlas alignment; never modifies image pixels."""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageFilter

root=Path(__file__).resolve().parents[2]
config=json.loads((root/"assets/data/cave_crawler_sprite.json").read_text())
audit={}
for name,columns,rows,prefix in [("cave_crawler",4,4,""),("cave_crawler_corpses",2,2,"corpse_")]:
    path=root/"assets/art/monsters"/(name+".png")
    image=Image.open(path)
    assert image.mode=="RGBA",(name,image.mode)
    assert image.getchannel("A").getextrema()==(0,255),(name,"real alpha required")
    w,h=image.size
    pivots=[];fractions=[];widths=[];boxes=[]
    for row in range(rows):
        for column in range(columns):
            left=round(column*w/columns);top=round(row*h/rows)
            right=round((column+1)*w/columns);bottom=round((row+1)*h/rows)
            cw,ch=right-left,bottom-top
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
    audit[name]={"size":[w,h],"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"grid":[columns,rows],"frames":boxes}
out=root/"build/gameplay-review";out.mkdir(parents=True,exist_ok=True)
(out/"atlas-audit.json").write_text(json.dumps(audit,indent=2)+"\n")
(out/"measured-sprite-metadata.json").write_text(json.dumps(config,indent=2)+"\n")
print("SPRITE_ATLAS_AUDIT "+json.dumps(audit,separators=(",",":")))
print("SPRITE_ATLAS_METADATA "+json.dumps(config,separators=(",",":")))
