import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {sourceSnapshot as villageSourceSnapshot} from '../village/harness.mjs';
import {MAX_REVIEWS, REFERENCE_SHA, SCORE_KEYS, assertRound, sourceSnapshot, captureCases, validateCapture, validateReview, reserveRound, validateBuildRecord} from './harness.mjs';

const reference=resolve(dirname(fileURLToPath(import.meta.url)),'../../../assets/source/style/approved-game-reference.jpg');
const digest=value=>createHash('sha256').update(value).digest('hex');
function stateFor(item) {
    const url=new URL('http://localhost/index.html?inspection=1&zoom=1');
    if (item.at) url.searchParams.set('at',item.at);
    if (item.scene.startsWith('cave_')) url.searchParams.set('dungeon_preview',item.scene.slice(5));
    return {errors:[],loadingOverlayVisible:false,entryLoading:{visible:false,result:'ready'},launchUrl:url.href,pckUrls:['http://localhost/index-a.pck'],probe:{native_active:true,physics_ticks:1,simulation:'3d',scope:item.scope,dungeon_traps:[{kind:'spike',phase:1}]}};
}
function fixture() {
    const root=mkdtempSync(resolve(tmpdir(),'sjrpg-cave-harness-'));
    const captures=captureCases().map(item=>{
        const path=resolve(root,item.id+'.bin');
        const state=resolve(root,item.id+'.json');
        writeFileSync(path,'test-only integrity fixture '+item.id);
        writeFileSync(state,JSON.stringify(stateFor(item)));
        return {...item,path,state,sha256:digest(readFileSync(path)),stateSha256:digest(readFileSync(state))};
    });
    return {root,manifest:{schemaVersion:1,round:2,status:'ready',kind:'candidate',pack:{name:'index-a.pck',sha256:'a'.repeat(64)},source:{sha256:'b'.repeat(64)},reference:{path:reference,sha256:REFERENCE_SHA},captures},review:{schemaVersion:1,round:2,reviewer:'independent_supervisor',verdict:'pass',comparedImages:[reference,...captures.map(c=>c.path)],scores:Object.fromEntries(SCORE_KEYS.map(key=>[key,4])),blockers:[],nextChanges:[],limits:[]}};
}
function withFixture(fn) {
    const f=fixture();try{fn(f);}finally{rmSync(f.root,{recursive:true,force:true});}
}

test('baseline and candidates share a maximum of five actual reviews',()=>{
    assert.equal(MAX_REVIEWS,5);
    for (const n of [0,-1,1.5,NaN,Number.MAX_SAFE_INTEGER+1]) assert.throws(()=>assertRound(n));
    for (const n of [1,2,3,4,5,6]) assert.doesNotThrow(()=>assertRound(n));
    withFixture(f=>assert.throws(()=>validateReview(f.review,f.manifest,5),/5회/));
});
test('capture profile includes entrance orientations, interior, relief and actual warning',()=>{
    const cases=captureCases();
    assert.equal(cases.length,6);
    assert.equal(new Set(cases.map(c=>c.id)).size,6);
    assert.equal(cases.filter(c=>c.scope==='forest').length,2);
    assert(cases.some(c=>c.scene==='cave_upper'));
    assert(cases.some(c=>c.scene==='cave_spikes_warn'&&c.trapWarning==='spike'));
    assert(cases.some(c=>c.device==='phone-landscape'&&c.viewport==='1280x720'));
    assert(captureCases('cave_exterior').slice(0,2).every(c=>c.at==='cave_exterior'));
    assert.throws(()=>captureCases('town'));
});
test('only an independent supervisor who viewed every immutable image can pass',()=>withFixture(f=>{
    assert.doesNotThrow(()=>validateReview(f.review,f.manifest,1));
    assert.throws(()=>validateReview({...f.review,reviewer:'implementer'},f.manifest,1),/독립/);
    assert.throws(()=>validateReview({...f.review,comparedImages:[reference]},f.manifest,1),/보지 않은/);
    assert.throws(()=>validateReview({...f.review,blockers:['entrance floats']},f.manifest,1),/차단/);
    assert.throws(()=>validateReview({...f.review,scores:{...f.review.scores,materials:6}},f.manifest,1),/정성/);
    assert.throws(()=>validateReview(f.review,{...f.manifest,status:'failed'},1),/완료/);
}));
test('changed PNG or runtime-state bytes invalidate a review',()=>withFixture(f=>{
    const first=f.manifest.captures[0];
    writeFileSync(first.path,'replacement image');
    assert.throws(()=>validateReview(f.review,f.manifest,1),/바뀌/);
    first.sha256=digest(readFileSync(first.path));
    writeFileSync(first.state,'replacement state');
    assert.throws(()=>validateReview(f.review,f.manifest,1),/바뀌/);
}));
test('runtime capture requires matching PCK, scope, real warning and loading completion',()=>{
    for (const item of captureCases()) assert.doesNotThrow(()=>validateCapture(stateFor(item),'index-a.pck',item));
    const item=captureCases().at(-1),state=stateFor(item);
    assert.throws(()=>validateCapture(state,'index-b.pck',item),/다른 빌드/);
    assert.throws(()=>validateCapture({...state,loadingOverlayVisible:true},'index-a.pck',item),/로딩/);
    assert.throws(()=>validateCapture({...state,probe:{...state.probe,scope:'forest'}},'index-a.pck',item),/지역/);
    assert.throws(()=>validateCapture({...state,probe:{...state.probe,physics_ticks:0}},'index-a.pck',item),/물리/);
    assert.throws(()=>validateCapture({...state,probe:{...state.probe,dungeon_traps:[{kind:'spike',phase:2}]}},'index-a.pck',item),/예고/);
    assert.throws(()=>validateCapture({...state,launchUrl:state.launchUrl.replace('zoom=1','zoom=0.5')},'index-a.pck',item),/1×/);
});
test('accepted, ready and in-progress rounds cannot be recaptured; failed technical attempts can',()=>{
    assert.doesNotThrow(()=>reserveRound({rounds:[]},1));
    assert.throws(()=>reserveRound({rounds:[]},2),/앞 회차/);
    assert.doesNotThrow(()=>reserveRound({rounds:[{round:1,status:'failed'}]},2));
    const first={round:1,status:'ready',reviewSha256:'a'};
    assert.doesNotThrow(()=>reserveRound({rounds:[first]},2));
    for (const status of ['ready','building','capturing']) assert.throws(()=>reserveRound({rounds:[first,{round:2,status}]},2),/재촬영/);
    assert.doesNotThrow(()=>reserveRound({rounds:[first,{round:2,status:'failed',attempt:1}]},2));
    assert.throws(()=>reserveRound({rounds:[first,{round:2,status:'ready',reviewSha256:'b'}]},2),/덮어쓸/);
});
test('frozen baseline must identify actual compiled PCK and source revision',()=>{
    const pack={name:'index-a.pck',sha256:'a'.repeat(64)};
    const record={schemaVersion:1,source:{sha256:digest('[]'),files:[]},gitCommit:'c'.repeat(40),pack};
    assert.doesNotThrow(()=>validateBuildRecord(record,pack));
    assert.throws(()=>validateBuildRecord({...record,source:{}},pack),/소스/);
    assert.throws(()=>validateBuildRecord({...record,source:{...record.source,files:[{path:'changed'}]}},pack),/목록/);
    assert.throws(()=>validateBuildRecord(record,{...pack,sha256:'d'.repeat(64)}),/실제 PCK/);
});
test('runtime signature excludes archives and imports but follows actual gameplay changes',()=>{
    const root=mkdtempSync(resolve(tmpdir(),'sjrpg-cave-harness-'));
    try {
        mkdirSync(resolve(root,'scripts'),{recursive:true});mkdirSync(resolve(root,'assets/source'),{recursive:true});
        writeFileSync(resolve(root,'scripts/main.gd'),'extends Node\n');
        const first=sourceSnapshot(root).sha256;
        assert.deepEqual(sourceSnapshot(root),villageSourceSnapshot(root));
        writeFileSync(resolve(root,'assets/source/concept.txt'),'authoring notes');
        writeFileSync(resolve(root,'scripts/main.gd.uid'),'engine uid');
        assert.equal(sourceSnapshot(root).sha256,first);
        writeFileSync(resolve(root,'scripts/main.gd'),'extends Node3D\n');
        assert.notEqual(sourceSnapshot(root).sha256,first);
    } finally {rmSync(root,{recursive:true,force:true});}
});

test('technical failures preserve files but cannot become a fake supervisor review',()=>withFixture(f=>{
    const partial={...f.manifest,captures:f.manifest.captures.slice(0,2)};
    assert.throws(()=>validateReview(f.review,partial,1),/필수6장/);
    assert.throws(()=>validateReview({...f.review,verdict:'revise'},{...partial,status:'failed'},1),/완료/);
    const sixth={...f.review,round:6};
    assert.doesNotThrow(()=>validateReview(sixth,{...f.manifest,round:6},4));
    assert.throws(()=>validateReview(sixth,{...f.manifest,round:6},5),/5회/);
}));

test('captures require an explicit inspection launch',()=>{
    const item=captureCases()[0];
    const state=stateFor(item);
    assert.throws(()=>validateCapture({...state,launchUrl:state.launchUrl.replace('inspection=1&','')},'index-a.pck',item),/검수 진입/);
});
