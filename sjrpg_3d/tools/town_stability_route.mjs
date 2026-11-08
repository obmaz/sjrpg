export function insideTown(p,polygon){let yes=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])yes=!yes;}return yes;}
export const townDirections=[['w',0,-1],['w+d',.707,-.707],['d',1,0],['s+d',.707,.707],['s',0,1],['s+a',-.707,.707],['a',-1,0],['w+a',-.707,-.707]];
export function chooseTownDirection(r,index){
 const polygon=r.town_polygon,centroid=polygon.reduce((p,q)=>[p[0]+q[0]/polygon.length,p[1]+q[1]/polygon.length],[0,0]);
 const distanceToEdge=p=>{let best=Infinity;for(let i=0;i<polygon.length;i++){const a=polygon[i],b=polygon[(i+1)%polygon.length],dx=b[0]-a[0],dy=b[1]-a[1],t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)));best=Math.min(best,Math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy));}return best;};
 const all=townDirections.map((d,i)=>({d,i,p:[r.player[0]+d[1]*900,r.player[1]+d[2]*900]}));
 const safe=all.filter(c=>insideTown(c.p,polygon)&&distanceToEdge(c.p)>=150);
 // An outside point can be farther than the lookahead from every safe choice.
 // Rank ALL directions toward the center then, never a random fallback.
 if(!r.town||safe.length===0)return all.sort((a,b)=>Math.hypot(a.p[0]-centroid[0],a.p[1]-centroid[1])-Math.hypot(b.p[0]-centroid[0],b.p[1]-centroid[1]))[0].d;
 return safe.find(c=>c.i===index%8)?.d||safe[index%safe.length].d;
}