#!/usr/bin/env node
// 실제 빌드·캡처·독립 검증 기록을 묶는다. 한 실행 폴더의 비교는 최대5회다.
import {createHash} from 'node:crypto';
import {existsSync, mkdirSync, readFileSync, readdirSync, renameSync, statSync, writeFileSync, openSync, closeSync} from 'node:fs';
import {dirname, resolve, relative, basename} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn, execFileSync} from 'node:child_process';

export const MAX_REVIEWS = 5;
export const REFERENCE_SHA = 'c81286d93319f3aa34c2e60ff16ad7347585be4e5a9d0e7a03866451dd4bf40a';
const project = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const repository = resolve(project, '..');
const reference = resolve(project, 'assets/source/style/approved-game-reference.jpg');
const defaultOutput = resolve(repository, 'build/village-art-review');
const hash = data => createHash('sha256').update(data).digest('hex');
const fileHash = path => hash(readFileSync(path));
const json = path => JSON.parse(readFileSync(path, 'utf8'));
const writeJSON = (path, value) => {
    mkdirSync(dirname(path), {recursive:true});
    writeFileSync(path+'.tmp', JSON.stringify(value,null,2)+'\n');
    renameSync(path+'.tmp',path);
};

export function assertRound(round) {
    if (!Number.isInteger(round) || round < 1 || round > MAX_REVIEWS) throw new Error('비교 회차는1..5만 허용합니다.');
}

export function sourceSnapshot(root) {
    const files = [];
    const walk = folder => {
        for (const entry of readdirSync(folder,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
            if (entry.isSymbolicLink() || entry.name === '.gdignore' || entry.name === 'source') continue;
            const path = resolve(folder,entry.name);
            if (entry.isDirectory()) walk(path);
            else if (!/\.(import|uid)$/.test(entry.name)) files.push({path:relative(root,path),sha256:fileHash(path),bytes:statSync(path).size});
        }
    };
    for (const name of ['scripts','scenes','assets','web']) if(existsSync(resolve(root,name))) walk(resolve(root,name));
    for (const name of ['project.godot','export_presets.cfg']) if(existsSync(resolve(root,name))) files.push({path:name,sha256:fileHash(resolve(root,name)),bytes:statSync(resolve(root,name)).size});
    return {sha256:hash(JSON.stringify(files)),files};
}

export function validateReview(review, manifest, acceptedCount) {
    assertRound(review.round);
    if (review.schemaVersion !== 1) throw new Error('검증 기록 형식은 schemaVersion:1입니다.');
    if (acceptedCount >= MAX_REVIEWS) throw new Error('독립 검증5회를 이미 사용했습니다.');
    if (review.round !== manifest.round || review.reviewer !== 'independent_verifier') throw new Error('독립 검증자/회차가 일치하지 않습니다.');
    if (!['pass','revise'].includes(review.verdict)) throw new Error('검증 판정이 필요합니다.');
    if (!Array.isArray(review.blockers) || !Array.isArray(review.nextChanges) || !Array.isArray(review.comparedImages) || !Array.isArray(review.limits)) throw new Error('비교 이미지·문제·후속 수정·검증 한계 기록이 필요합니다.');
    if (review.verdict === 'pass' && review.blockers.length) throw new Error('차단 문제가 남은 판정은 통과할 수 없습니다.');
    for (const key of ['layout','orientation','reference_mood','materials','vegetation','readability']) {
        const value=review.scores?.[key];
        if (!Number.isFinite(value) || value < 0 || value > 5) throw new Error('정성 척도0..5 범위가 필요합니다: '+key);
    }
    const viewed = new Set(review.comparedImages.map(path=>resolve(path)));
    for (const capture of manifest.captures) {
        if (!viewed.has(resolve(capture.path)) && !(capture.original && viewed.has(resolve(capture.original)))) throw new Error('검증자가 보지 않은 필수 캡처: '+capture.id);
        if (fileHash(capture.path) !== capture.sha256) throw new Error('검증 대상 이미지가 바뀌었습니다: '+capture.id);
        if (capture.original && viewed.has(resolve(capture.original)) && fileHash(capture.original) !== capture.sha256) throw new Error('검증자가 본 기존 이미지가 바뀌었습니다: '+capture.id);
    }
    if (!viewed.has(resolve(manifest.reference.path))) throw new Error('실제 사용자 레퍼런스와 비교해야 합니다.');
    if (fileHash(manifest.reference.path) !== REFERENCE_SHA) throw new Error('사용자 레퍼런스가 변경됐습니다.');
    if (manifest.status !== 'ready') throw new Error('완료된 캡처만 비교할 수 있습니다.');
}

export function validateCapture(state, packName, normalFollow = false) {
    if (state.errors?.length) throw new Error('브라우저 오류가 있는 캡처입니다.');
    if (state.loadingOverlayVisible !== false || state.entryLoading?.visible !== false || state.entryLoading?.result !== 'ready') throw new Error('로딩 패널 종료가 확인되지 않은 캡처입니다.');
    if (!state.probe?.native_active || !(state.probe.physics_ticks > 0)) throw new Error('운영3D 물리 준비 상태가 아닙니다.');
    if (!state.pckUrls?.some(url=>new URL(url).pathname.endsWith('/'+packName))) throw new Error('다른 빌드를 읽은 캡처입니다.');
    if (state.village?.schemaVersion !== 1 || !(state.village.buildings?.length >= 6)) throw new Error('실제 마을 공간 스냅샷이 필요합니다.');
    if (new URL(state.launchUrl).searchParams.get('inspection') !== '1') throw new Error('명시적 검수 진입 플래그가 필요합니다.');
    if (normalFollow && state.village.cameraMode !== 'follow') throw new Error('주택 가독성은 정상 인물 추적 카메라로 확인해야 합니다.');
}

function session(root) {
    const path=resolve(root,'session.json');
    if (existsSync(path)) return json(path);
    if (fileHash(reference)!==REFERENCE_SHA) throw new Error('기준 레퍼런스 해시가 다릅니다.');
    const value={schemaVersion:1,maxReviews:MAX_REVIEWS,reference:{path:reference,sha256:REFERENCE_SHA},rounds:[]};
    writeJSON(path,value);
    return value;
}

function reserve(root, round) {
    assertRound(round);
    const current=session(root);
    if (current.rounds.some(item=>item.round===round && item.reviewSha256)) throw new Error('검증한 회차는 덮어쓸 수 없습니다.');
    if (current.rounds.filter(item=>item.reviewSha256).length >= MAX_REVIEWS) throw new Error('독립 비교5회가 끝났습니다.');
    const previous=current.rounds.find(item=>item.round===round-1);
    if (round>1 && !previous?.reviewSha256) throw new Error('앞 회차의 검증을 먼저 기록해야 합니다.');
    return current;
}

function saveRound(root,current,manifest) {
    writeJSON(resolve(root,'round-'+manifest.round,'manifest.json'),manifest);
    const entry=current.rounds.find(item=>item.round===manifest.round);
    if (entry) entry.status=manifest.status;
    else current.rounds.push({round:manifest.round,status:manifest.status});
    writeJSON(resolve(root,'session.json'),current);
}

function baseline(root) {
    const current=reserve(root,1);
    const input=resolve(repository,'build/village-courtyards');
    const names=['plaza','house-ne','house-nw','house-sw','house-se','market-after','smithy-after'];
    const originals=names.map(name=>({id:name,path:resolve(input,name+'.png')}));
    originals.push({id:'chapel',path:resolve(repository,'build/feel-refinement/chapel-after.png')});
    const captures=originals.map(item=>{
        const path=resolve(root,'round-1',item.id+'.png');
        mkdirSync(dirname(path),{recursive:true});
        writeFileSync(path,readFileSync(item.path));
        return {id:item.id,path,original:item.path,sha256:fileHash(path)};
    });
    saveRound(root,current,{schemaVersion:1,round:1,status:'ready',kind:'verified_historical_baseline',reference:current.reference,gitCommit:json(resolve(input,'verification.json')).commit,captureConditions:'기존 실제 캡처; 일부0.75×. 새 후보는 지정한 기본1×와 배치 전용 넓은 시야를 구별한다.',captures});
}

function logged(command,args,path) {
    mkdirSync(dirname(path),{recursive:true});
    return new Promise((resolveRun,reject)=>{
        const fd=openSync(path,'w');
        const child=spawn(command,args,{cwd:repository,stdio:['ignore',fd,fd]});
        child.once('error',error=>{closeSync(fd);reject(error);});
        child.once('exit',(code,signal)=>{closeSync(fd);code===0?resolveRun():reject(new Error(`${command} 실패: ${code ?? signal}; ${path}`));});
    });
}

async function capture(root, round, url) {
    const current=reserve(root,round);
    const folder=resolve(root,'round-'+round);
    const before=sourceSnapshot(project);
    const manifest={schemaVersion:1,round,status:'building',reference:current.reference,gitCommit:execFileSync('git',['rev-parse','HEAD'],{cwd:repository,encoding:'utf8'}).trim(),source:before,captures:[]};
    saveRound(root,current,manifest);
    try {
        const response=await fetch(new URL('index.html',url),{signal:AbortSignal.timeout(5000)});
        if (!response.ok) throw new Error('검수 URL의 웹 서버를 먼저 실행해야 합니다.');
        console.log('BUILD_START round='+round);
        await logged(resolve(project,'tools/export_web.sh'),[],resolve(folder,'build.log'));
        if(sourceSnapshot(project).sha256!==before.sha256) throw new Error('빌드 도중 운영 소스가 변경됐습니다.');
        const web=resolve(project,'build/web');
        const html=readFileSync(resolve(web,'index.html'),'utf8');
        const packs=readdirSync(web).filter(name=>/^index-[0-9a-f]+\.pck$/.test(name) && html.includes(name));
        if(packs.length!==1) throw new Error('현재 웹 PCK를 특정할 수 없습니다.');
        manifest.pack={name:packs[0],sha256:fileHash(resolve(web,packs[0]))};
        manifest.status='capturing';
        saveRound(root,current,manifest);
        const cases=[
            {id:'chapel-default',scene:'chapel_reference',viewport:'390x700',zoom:'1',purpose:'reference_mood'},
            {id:'village-layout',scene:'town',at:'plaza_detail',viewport:'390x700',zoom:'0.35',purpose:'layout_only'},
            {id:'rotated-house',scene:'house_nw',viewport:'390x700',zoom:'1',purpose:'orientation_and_materials'},
            {id:'rotated-house-landscape',scene:'house_nw',viewport:'844x390',zoom:'1',purpose:'orientation_and_mobile_readability'},
            {id:'northern-lane',scene:'house_ne',viewport:'390x700',zoom:'1',purpose:'neighbor_overlap_and_door_readability'},
            {id:'southern-lane',scene:'house_se',viewport:'390x700',zoom:'1',purpose:'corner_house_and_shared_lane'},
        ];
        let cursor=0;
        const worker=async()=>{
            while(cursor<cases.length) {
                const item=cases[cursor++];
                const path=resolve(folder,item.id+'.png');
                const statePath=resolve(folder,item.id+'.json');
                const args=[resolve(project,'tools/screenshot.mjs'),'--scene',item.scene,'--class','mage','--device','phone','--viewport',item.viewport,'--zoom',item.zoom,'--village_review','1','--dpr','1','--capture-timeout','120000','--url',url,'--out',path,'--state-out',statePath,'--settle','1000'];
                if(item.at)args.push('--at',item.at);
                console.log('CAPTURE_START '+item.id);
                await logged(process.execPath,args,resolve(folder,item.id+'.log'));
                const state=json(statePath);
                validateCapture(state,manifest.pack.name,item.scene.startsWith('house_'));
                manifest.captures.push({...item,cameraMode:state.village.cameraMode,path,state:statePath,sha256:fileHash(path)});
                console.log('CAPTURE_PASS '+item.id);
            }
        };
        const results=await Promise.allSettled([worker(),worker()]);
        const failed=results.find(result=>result.status==='rejected');
        if(failed)throw failed.reason;
        if(sourceSnapshot(project).sha256!==before.sha256) throw new Error('촬영 도중 운영 소스가 변경됐습니다.');
        manifest.captures.sort((a,b)=>cases.findIndex(item=>item.id===a.id)-cases.findIndex(item=>item.id===b.id));
        manifest.status='ready';
        manifest.finishedAt=new Date().toISOString();
        saveRound(root,current,manifest);
        console.log('ROUND_CAPTURE_READY '+round);
    } catch(error) {
        manifest.status='failed';manifest.error=error.message;
        saveRound(root,current,manifest);
        throw error;
    }
}

function accept(root,round) {
    const current=reserve(root,round);
    const path=resolve(root,'round-'+round,'review.json');
    const review=json(path);
    const manifest=json(resolve(root,'round-'+round,'manifest.json'));
    validateReview(review,manifest,current.rounds.filter(item=>item.reviewSha256).length);
    if (round>1 && (!manifest.source || !manifest.pack)) throw new Error('후보 소스 지문과 빌드 기록이 필요합니다.');
    if (review.verdict==='pass' && manifest.source) {
        if (sourceSnapshot(project).sha256!==manifest.source.sha256) throw new Error('합격한 사진 이후 운영 소스가 바뀌었습니다.');
        const state=json(manifest.captures[0].state);
        const houses=state.village.buildings.filter(item=>item.id!=='chapel');
        if (houses.some(item=>!item.matchesPlan)) throw new Error('표시 루트와 공유 포즈가 일치하지 않습니다.');
        if (!houses.some(item=>item.forward[0]>.95 && item.frontScreenVector[0]>0 && item.frontScreenVector[1]>0)) throw new Error('우하단(+X)을 향하는 정면이 없습니다.');
        if (!houses.some(item=>item.forward[2]>.95)) throw new Error('서로 다른 문 방향이 필요합니다.');
    }
    const entry=current.rounds.find(item=>item.round===round);
    entry.reviewSha256=fileHash(path);entry.verdict=review.verdict;
    writeJSON(resolve(root,'session.json'),current);
    console.log('REVIEW_ACCEPTED '+round+' '+review.verdict);
}

function gallery(root) {
    const current=session(root);
    const escape=value=>String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
    const referencePath=relative(root,reference);
    const sections=current.rounds.map(item=>{
        const manifest=json(resolve(root,'round-'+item.round,'manifest.json'));
        const review=item.reviewSha256?json(resolve(root,'round-'+item.round,'review.json')):null;
        const pictures=manifest.captures.map(c=>`<figure><figcaption>${escape(c.id)} ${escape(c.purpose ?? 'baseline')}${c.zoom ? ` · ${escape(c.zoom)}×` : ''}${c.cameraMode ? ` · ${escape(c.cameraMode)}` : ''}</figcaption><a href="${escape(relative(root,c.path))}"><img loading="lazy" src="${escape(relative(root,c.path))}" alt="${escape(c.id)}"></a></figure>`).join('');
        const notes=review?[...review.blockers,...review.nextChanges].map(note=>`<li>${escape(note)}</li>`).join(''):'';
        const conditions=manifest.captureConditions ?? '기본1× 인물 추적 화면과 배치 전용0.35× 화면을 구별한다. 이미지를 누르면 원본 크기로 연다.';
        return `<section id="round-${item.round}"><h2>비교 ${item.round}/5 · ${escape(review?.verdict ?? manifest.status)}</h2><p>${escape(conditions)}</p><p>정성 척도0..5: ${escape(JSON.stringify(review?.scores ?? {}))}</p><ul>${notes}</ul><div class="pictures">${pictures}</div></section>`;
    }).join('');
    writeFileSync(resolve(root,'index.html'),`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>마을 구현·독립 검증 비교</title><style>body{background:#142019;color:#e7e4d5;font:16px/1.6 system-ui;margin:24px}main{max-width:1400px;margin:auto}.pictures{display:flex;flex-wrap:wrap;gap:20px}figure{margin:0;max-width:390px}img{width:100%;height:auto}section{border-top:1px solid #65715b;margin-top:32px}a{color:#d1dfbc}.reference{max-width:360px}li{max-width:1000px}</style><main><h1>마을 구현·독립 검증</h1><p>구현자와 검증자를 분리하고 실제 원본과 비교했습니다. 최대5회이며 정성 점수는 달성률이 아닙니다. 배치 전용 넓은 시야와 기본1× 재질·분위기 화면을 구별합니다.</p><nav>${current.rounds.map(r=>`<a href="#round-${r.round}">비교${r.round}</a>`).join(' · ')}</nav><figure class="reference"><figcaption>사용자 원본 레퍼런스</figcaption><img src="${escape(referencePath)}" alt="사용자 원본 레퍼런스"></figure>${sections}</main></html>`);
}

async function main() {
    const [command,...tokens]=process.argv.slice(2);
    const args=Object.fromEntries(tokens.reduce((pairs,value,index,array)=>value.startsWith('--')?[...pairs,[value.slice(2),array[index+1]]]:pairs,[]));
    const root=resolve(args.out ?? defaultOutput);
    const round=Number(args.round);
    if(command==='baseline')baseline(root);
    else if(command==='capture')await capture(root,round,args.url ?? 'http://127.0.0.1:8886/');
    else if(command==='accept-review')accept(root,round);
    else if(command!=='gallery')throw new Error('사용법: harness.mjs baseline|capture --round N|accept-review --round N|gallery [--out 폴더]');
    gallery(root);
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) main().catch(error=>{console.error(error.message);process.exitCode=1;});
