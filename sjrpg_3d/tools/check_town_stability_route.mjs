#!/usr/bin/env node
import assert from 'node:assert/strict';
import {insideTown,townDirections,chooseTownDirection} from './town_stability_route.mjs';
const polygon=[[-94.085,-1373.52],[2325.243,23.28],[174.729,1264.88],[-2244.599,-131.92]];
const centroid=polygon.reduce((p,q)=>[p[0]+q[0]/polygon.length,p[1]+q[1]/polygon.length],[0,0]);
const step=(p,d,amount)=>[p[0]+d[1]*amount,p[1]+d[2]*amount];
const distance=p=>Math.hypot(p[0]-centroid[0],p[1]-centroid[1]);
let checks=0;
for(const position of [[1766.553,1086.731],[5000,4000],[-5000,-4000]]){
 assert(!insideTown(position,polygon));
 for(let index=0;index<8;index++){
  const d=chooseTownDirection({town:false,town_polygon:polygon,player:position},index);
  assert(distance(step(position,d,150))<distance(position),'outside fallback must aim inward even when every predicted point is outside');
  checks++;
 }
}
for(const corner of polygon){
 const position=[centroid[0]+(corner[0]-centroid[0])*.98,centroid[1]+(corner[1]-centroid[1])*.98];
 assert(insideTown(position,polygon));
 for(let index=0;index<8;index++){
  const d=chooseTownDirection({town:true,town_polygon:polygon,player:position},index);
  assert(insideTown(step(position,d,300),polygon),'corner steering must stay in the actual safe polygon');
  checks++;
 }
}
const stuck={town:true,town_polygon:polygon,player:[400,0]};
const attempts=new Set(Array.from({length:16},(_,index)=>chooseTownDirection(stuck,index)[0]));
assert(attempts.size>=3,'stationary blocked position must try several input directions instead of repeatedly pressing one blocked key');
checks++;
let position=[0,0];
for(let index=0;index<1000;index++){
 const d=chooseTownDirection({town:insideTown(position,polygon),town_polygon:polygon,player:position},index);
 assert(townDirections.includes(d));
 position=step(position,d,300);
 assert(insideTown(position,polygon),'bounded real-input route must remain in town at segment '+index);
 checks++;
}
console.log('TOWN_STABILITY_ROUTE_PASS '+JSON.stringify({checks,outside_cases:24,corner_cases:32,stationary_blocked_positions:1,simulated_segments:1000,lookahead_world_units:900,maximum_simulated_segment_units:300}));
