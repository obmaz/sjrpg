import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {assertRound,sourceSnapshot,validateReview,validateCapture,REFERENCE_SHA} from './harness.mjs';

const reference=resolve(dirname(fileURLToPath(import.meta.url)),'../../../assets/source/style/approved-game-reference.jpg');
const digest=value=>createHash('sha256').update(value).digest('hex');
function fixture() {
    const root=mkdtempSync(resolve(tmpdir(),'sjrpg-village-harness-'));
    const capture=resolve(root,'integrity-fixture.bin');
    writeFileSync(capture,'test-only capture integrity fixture');
    return {root,capture,manifest:{round:2,status:'ready',reference:{path:reference,sha256:REFERENCE_SHA},captures:[{id:'scene',path:capture,sha256:digest(readFileSync(capture))}]},review:{schemaVersion:1,round:2,reviewer:'independent_verifier',verdict:'pass',comparedImages:[reference,capture],scores:{layout:4,orientation:4,reference_mood:4,materials:4,vegetation:4,readability:4},blockers:[],nextChanges:[],limits:[]}};
}

test('comparison budget rejects zero, sixth and fractional rounds',()=>{
    for(const round of [0,6,-1,1.5,NaN])assert.throws(()=>assertRound(round));
    for(const round of [1,2,3,4,5])assert.doesNotThrow(()=>assertRound(round));
});
test('fifth completed review exhausts the comparison budget',()=>{
    const f=fixture();try{assert.throws(()=>validateReview(f.review,f.manifest,5),/5회/);}finally{rmSync(f.root,{recursive:true,force:true});}
});
test('a pass needs the independent role, every capture and no blockers',()=>{
    const f=fixture();try{
        assert.doesNotThrow(()=>validateReview(f.review,f.manifest,1));
        assert.throws(()=>validateReview({...f.review,reviewer:'implementer'},f.manifest,1),/독립/);
        assert.throws(()=>validateReview({...f.review,comparedImages:[reference]},f.manifest,1),/보지 않은/);
        assert.throws(()=>validateReview({...f.review,blockers:['door is hidden']},f.manifest,1),/차단/);
        assert.throws(()=>validateReview({...f.review,scores:{...f.review.scores,layout:101}},f.manifest,1),/정성/);
    }finally{rmSync(f.root,{recursive:true,force:true});}
});
test('changed capture data cannot inherit an earlier review',()=>{
    const f=fixture();try{writeFileSync(f.capture,'changed fixture');assert.throws(()=>validateReview(f.review,f.manifest,1),/바뀌/);}finally{rmSync(f.root,{recursive:true,force:true});}
});
test('a historical original viewed by the verifier must match the preserved capture',()=>{
    const f=fixture();try{
        const original=resolve(f.root,'historical-original.bin');
        writeFileSync(original,readFileSync(f.capture));
        f.manifest.captures[0].original=original;
        f.review.comparedImages=[reference,original];
        assert.doesNotThrow(()=>validateReview(f.review,f.manifest,1));
        writeFileSync(original,'changed original');
        assert.throws(()=>validateReview(f.review,f.manifest,1),/기존 이미지가 바뀌/);
    }finally{rmSync(f.root,{recursive:true,force:true});}
});
test('capture must come from the expected PCK and running native world',()=>{
    const state={launchUrl:'http://localhost/?inspection=1',errors:[],loadingOverlayVisible:false,entryLoading:{visible:false,result:'ready'},pckUrls:['http://localhost/index-a.pck'],probe:{native_active:true,physics_ticks:1},village:{schemaVersion:1,buildings:Array(6).fill({})}};
    assert.doesNotThrow(()=>validateCapture(state,'index-a.pck'));
    assert.throws(()=>validateCapture({...state,launchUrl:'http://localhost/'},'index-a.pck'),/검수 진입/);
    assert.throws(()=>validateCapture(state,'index-b.pck'),/다른 빌드/);
    assert.throws(()=>validateCapture({...state,probe:{native_active:false}},'index-a.pck'),/물리/);
    assert.throws(()=>validateCapture({...state,village:null},'index-a.pck'),/스냅샷/);
    assert.throws(()=>validateCapture({...state,loadingOverlayVisible:true},'index-a.pck'),/로딩 패널/);
    assert.throws(()=>validateCapture({...state,entryLoading:{visible:true}},'index-a.pck'),/로딩 패널/);
    assert.throws(()=>validateCapture({...state,entryLoading:undefined},'index-a.pck'),/로딩 패널/);
    assert.throws(()=>validateCapture(state,'index-a.pck',true),/정상 인물 추적/);
    assert.doesNotThrow(()=>validateCapture({...state,village:{...state.village,cameraMode:'follow'}},'index-a.pck',true));
});
test('source signature follows runtime changes and ignores authoring/archive outputs',()=>{
    const root=mkdtempSync(resolve(tmpdir(),'sjrpg-village-harness-'));
    try{
        mkdirSync(resolve(root,'scripts'),{recursive:true});mkdirSync(resolve(root,'assets/source'),{recursive:true});
        writeFileSync(resolve(root,'scripts/main.gd'),'extends Node\n');
        const first=sourceSnapshot(root).sha256;
        writeFileSync(resolve(root,'assets/source/notes.txt'),'authoring notes');
        writeFileSync(resolve(root,'scripts/main.gd.uid'),'generated uid');
        assert.equal(sourceSnapshot(root).sha256,first);
        writeFileSync(resolve(root,'scripts/main.gd'),'extends Node3D\n');
        assert.notEqual(sourceSnapshot(root).sha256,first);
    }finally{rmSync(root,{recursive:true,force:true});}
});
