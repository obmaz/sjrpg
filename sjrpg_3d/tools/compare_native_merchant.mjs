#!/usr/bin/env node
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import path from 'node:path';
const root=path.resolve(process.argv[2]||'build/native-merchant-review');
const before=JSON.parse(await readFile(path.join(root,'before/proof.json'),'utf8'));
const after=JSON.parse(await readFile(path.join(root,'after/proof.json'),'utf8'));
const checks=[],measurements=[];let failure=null;
const by=(proof,name)=>{const shot=proof.captures.find(x=>x.name===name);assert(shot,'actual capture '+name);return shot;};
const near=(a,b,label,tol=.0001)=>assert(Math.abs(a-b)<=tol,label+' actual='+a+' expected='+b);
try{
 assert(before.passed&&after.passed,'both actual merchant runs must pass');
 for(const label of['portrait','landscape','retina']){
  const b=by(before,'merchant-'+label+'-town'),a=by(after,'merchant-'+label+'-town');
  near(a.ui.native_camera_size,b.ui.native_camera_size,label+' same actual camera');
  assert.deepEqual(a.ui.merchant.source_position,b.ui.merchant.source_position,label+' unchanged authoritative NPC foot');
  assert.deepEqual(a.ui.merchant.circle,b.ui.merchant.circle,label+' unchanged physical interaction circle');
  assert.deepEqual(a.ui.merchant.model_scale,[1,1,1],label+' imported root remains unit scale');a.ui.merchant.model_position.forEach((v,i)=>near(v,b.ui.merchant.model_position[i],label+' unchanged native NPC root position',.01));
  for(const key of['bar_bag','bar_skills','bar_quests','bar_gear','potion_hp','potion_mp','slot0','slot1','slot2','slot3','slot4','roll'])assert.deepEqual(a.ui.buttons[key],b.ui.buttons[key],label+' unchanged HUD target '+key);
  for(const key of['avatar','hp','mp','level_badge'])assert.deepEqual(a.ui[key],b.ui[key],label+' unchanged status layout '+key);
  assert.equal(a.ui.merchant.source,'cc0_import');
  assert.equal(a.ui.merchant.asset,'res://assets/art/native_residents/merchant.glb');
  assert(a.ui.merchant.bone_count>=20&&a.ui.merchant.skinned_meshes>0);
  const npc=a.ui.coverage.actor_proportions.residents.find(r=>r.identity==='merchant');
  assert(npc?.valid&&npc.skinned_meshes.length>0,'actual imported proportion audit');
  near(npc.height_m,1.78,label+' actual imported rest height',.035);
  assert.deepEqual(a.ui.merchant.quests,b.ui.merchant.quests,label+' quest state preserved across asset replacement');
  measurements.push({label,before_source:b.ui.merchant.source,after_source:a.ui.merchant.source,after_height:npc.height_m,bones:a.ui.merchant.bone_count,meshes:a.ui.merchant.meshes,physical_circle:a.ui.merchant.circle});
  checks.push(label+' same actual camera/physics/HUD and real imported body');
 }
 assert.equal(after.merchantIdleSamples.length,3,'three real idle/pause observations');
 for(const sample of after.merchantIdleSamples){assert(sample.live_pose_delta>1e-6,'actual sampled bones advance '+sample.label);assert.equal(sample.paused_pose_delta,0,'actual sampled bones freeze '+sample.label);assert.equal(sample.paused_after_source,sample.paused_source);assert.equal(sample.paused_after_sample,sample.paused_sample);}
 for(let face=0;face<4;face++){const a=by(after,'merchant-gallery-face-'+face);const m=a.ui.gallery.models[0];assert(m.skeletons>0&&m.skinned_meshes>0&&m.scene_paths.some(p=>p.includes('merchant.glb')),'actual imported factory all-face '+face);checks.push('actual imported factory face '+face);}
 console.log('NATIVE_MERCHANT_COMPARISON_PASS '+JSON.stringify({checks:checks.length,measurements,idle:after.merchantIdleSamples,baselineKnownGeometryIssues:before.baselineViolations}));
}catch(error){failure=String(error);console.error('NATIVE_MERCHANT_COMPARISON_FAIL '+failure);process.exitCode=1;}
await writeFile(path.join(root,'merchant-comparison.json'),JSON.stringify({passed:!failure,failure,checks,measurements},null,2));
