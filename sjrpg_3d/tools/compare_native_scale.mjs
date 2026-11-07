#!/usr/bin/env node
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import path from 'node:path';
const root=path.resolve(process.argv[2]||'build/native-scale-review');
const before=JSON.parse(await readFile(path.join(root,'before/proof.json'),'utf8'));
const after=JSON.parse(await readFile(path.join(root,'after/proof.json'),'utf8'));
const checks=[],measurements=[];
const near=(a,b,label,tolerance=.005)=>{assert(Math.abs(a-b)<=tolerance,label+' actual='+a+' expected='+b);checks.push(label);};
const by=(proof,name)=>{const item=proof.captures.find(c=>c.name===name);assert(item,'actual capture '+name);return item;};
let failure=null;
try{
 assert(before.passed&&after.passed,'both actual scene runs must pass');
 for(const name of['matched-town-zoom-0.5','matched-town-zoom-1','matched-town-zoom-1.5','matched-actors-face-0','matched-chest-closed','matched-chest-open']){
  const b=by(before,name),a=by(after,name);
  near(a.scale.native_camera_size,b.scale.native_camera_size,name+' identical actual orthographic camera');
  assert.deepEqual(a.ui.viewport,b.ui.viewport,name+' same logical viewport');
 }
 const bDefault=by(before,'default-town'),aDefault=by(after,'default-town');
 near(aDefault.scale.native_camera_size/bDefault.scale.native_camera_size,1/.75,'fresh UI1 now displays the intended wider .75 base');
 for(const name of['matched-chest-closed','matched-chest-open']){
  const b=by(before,name).scale.chests.find(c=>c.selected),a=by(after,name).scale.chests.find(c=>c.selected);
  for(let axis=0;axis<3;axis++)near(a.model.world_size_m[axis]/b.model.world_size_m[axis],1.25,name+' actual baked mesh axis '+axis,.015);
  near(a.collision.radius_m/b.collision.radius_m,1.25,name+' actual physics radius ratio',.001);
  measurements.push({name,before:b,after:a});
 }
 const bActors=by(before,'matched-actors-face-0').scale.actors,aActors=by(after,'matched-actors-face-0').scale.actors;
 for(const a of aActors){const b=bActors.find(b=>b.kind===a.kind);assert(b,'same actual Enemy.setup archetype '+a.kind);measurements.push({kind:a.kind,before_height_m:b.model.world_size_m[1],after_height_m:a.model.world_size_m[1],before_capsule:b.collision,after_capsule:a.collision,before_scale:b.model.scale,after_scale:a.model.scale});}
 console.log('NATIVE_SCALE_COMPARISON_PASS '+JSON.stringify({checks:checks.length,measurements}));
}catch(e){failure=String(e);console.error('NATIVE_SCALE_COMPARISON_FAIL '+failure);process.exitCode=1;}
await writeFile(path.join(root,'scale-comparison.json'),JSON.stringify({passed:!failure,failure,checks,measurements},null,2));
