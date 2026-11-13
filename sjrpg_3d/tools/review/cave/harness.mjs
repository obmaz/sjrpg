#!/usr/bin/env node
// 동굴의 실제 빌드·불변 캡처·독립 감독 판정을 최대5회 묶는다.
import {createHash} from 'node:crypto';
import {existsSync, mkdirSync, readFileSync, readdirSync, renameSync, statSync, writeFileSync, openSync, closeSync} from 'node:fs';
import {dirname, resolve, relative} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn, execFileSync} from 'node:child_process';

export const MAX_REVIEWS = 5;
export const REFERENCE_SHA = 'c81286d93319f3aa34c2e60ff16ad7347585be4e5a9d0e7a03866451dd4bf40a';
export const SCORE_KEYS = ['entrance_shape', 'ground_connection', 'interior_form', 'materials', 'readability', 'hazards'];
const project = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const repository = resolve(project, '..');
const reference = resolve(project, 'assets/source/style/approved-game-reference.jpg');
const defaultOutput = resolve(repository, 'build/cave-art-review');
const digest = data => createHash('sha256').update(data).digest('hex');
const fileHash = path => digest(readFileSync(path));
const json = path => JSON.parse(readFileSync(path, 'utf8'));
const writeJSON = (path, value) => {
    mkdirSync(dirname(path), {recursive:true});
    writeFileSync(path+'.tmp', JSON.stringify(value, null, 2)+'\n');
    renameSync(path+'.tmp', path);
};

export function assertRound(round) {
    if (!Number.isSafeInteger(round) || round < 1) throw new Error('후보 회차는 양의 정수여야 합니다.');
}

// 운영 지문은 기존 마을 하네스와 같은 범위다. 출처 원본·엔진 생성 UID/임포트는 별도 자산 검사가 맡는다.
export function sourceSnapshot(root) {
    const files = [];
    const walk = folder => {
        for (const entry of readdirSync(folder, {withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
            if (entry.isSymbolicLink() || entry.name === '.gdignore' || entry.name === 'source') continue;
            const path = resolve(folder, entry.name);
            if (entry.isDirectory()) walk(path);
            else if (!/\.(import|uid)$/.test(entry.name)) files.push({path:relative(root,path), sha256:fileHash(path), bytes:statSync(path).size});
        }
    };
    for (const name of ['scripts','scenes','assets','web']) if (existsSync(resolve(root,name))) walk(resolve(root,name));
    for (const name of ['project.godot','export_presets.cfg']) if (existsSync(resolve(root,name))) files.push({path:name, sha256:fileHash(resolve(root,name)), bytes:statSync(resolve(root,name)).size});
    return {sha256:digest(JSON.stringify(files)), files};
}

export function captureCases(entranceAt='cave_descent') {
    if (!['cave_descent','cave_exterior'].includes(entranceAt)) throw new Error('입구 장면은 cave_descent 또는 cave_exterior입니다.');
    return [
        {id:'entrance-phone', scene:'town', at:entranceAt, viewport:'720x1280', device:'phone', scope:'forest', purpose:'마지막 흙길·하강·암반 발치·전체 개구부'},
        {id:'entrance-landscape', scene:'town', at:entranceAt, viewport:'1280x720', device:'phone-landscape', scope:'forest', purpose:'가로 화면의 구릉/입구 접합과 길 안내'},
        {id:'entry-phone', scene:'cave_entry', viewport:'720x1280', device:'phone', scope:'cave', purpose:'동굴 진입·귀환문·자연 암반과 깊이'},
        {id:'room-landscape', scene:'cave_room', viewport:'1280x720', device:'phone-landscape', scope:'cave', purpose:'방의 윤곽·재질 반복·인물과 전투 가독성'},
        {id:'upper-phone', scene:'cave_upper', viewport:'720x1280', device:'phone', scope:'cave', purpose:'상하 분기·경사·바닥/벽 접합'},
        {id:'spikes-warning-phone', scene:'cave_spikes_warn', viewport:'720x1280', device:'phone', scope:'cave', trapWarning:'spike', purpose:'실제 가시 예고와 회피 경로 가독성'},
    ];
}

export function validateCapture(state, packName, item) {
    if (state.errors?.length) throw new Error('브라우저 오류가 있는 캡처입니다.');
    if (state.loadingOverlayVisible !== false || state.entryLoading?.visible !== false || state.entryLoading?.result !== 'ready') throw new Error('로딩 패널 종료가 확인되지 않았습니다.');
    if (!state.probe?.native_active || !(state.probe.physics_ticks > 0) || state.probe.simulation !== '3d') throw new Error('실제3D 물리 준비 상태가 아닙니다.');
    if (state.probe.scope !== item.scope) throw new Error('촬영한 실제 지역이 다릅니다: '+item.id);
    if (!state.pckUrls?.some(url=>new URL(url).pathname.endsWith('/'+packName))) throw new Error('다른 빌드를 읽은 캡처입니다.');
    const launch = new URL(state.launchUrl);
    if (launch.searchParams.get('inspection') !== '1') throw new Error('명시적 검수 진입 플래그가 필요합니다.');
    if (launch.searchParams.get('zoom') !== '1') throw new Error('기본1× 시야가 아닙니다.');
    if (item.at && launch.searchParams.get('at') !== item.at) throw new Error('입구 검수 위치가 다릅니다.');
    if (item.scene.startsWith('cave_') && launch.searchParams.get('dungeon_preview') !== item.scene.slice(5)) throw new Error('동굴 검수 장면이 다릅니다.');
    if (item.trapWarning && !state.probe.dungeon_traps?.some(trap=>trap.kind===item.trapWarning && trap.phase===1)) throw new Error('실제 함정의 예고 단계가 아닙니다.');
}

export function validateReview(review, manifest, acceptedCount) {
    assertRound(review.round);
    if (acceptedCount >= MAX_REVIEWS) throw new Error('독립 감독5회를 이미 사용했습니다.');
    if (review.schemaVersion !== 1 || review.round !== manifest.round || review.reviewer !== 'independent_supervisor') throw new Error('독립 감독의 형식/회차가 다릅니다.');
    if (!['pass','revise'].includes(review.verdict)) throw new Error('감독 판정이 필요합니다.');
    for (const key of ['comparedImages','blockers','nextChanges','limits']) if (!Array.isArray(review[key])) throw new Error('필수 감독 기록이 없습니다: '+key);
    if (review.verdict === 'pass' && review.blockers.length) throw new Error('차단 문제가 남은 후보를 통과시킬 수 없습니다.');
    for (const key of SCORE_KEYS) if (!Number.isFinite(review.scores?.[key]) || review.scores[key]<0 || review.scores[key]>5) throw new Error('정성 척도0..5가 필요합니다: '+key);
    if (manifest.status!=='ready') throw new Error('완료된 캡처만 감독이 비교할 수 있습니다.');
    const required=new Set(captureCases().map(item=>item.id));
    const ids=new Set(manifest.captures.map(item=>item.id));
    if (ids.size!==manifest.captures.length || [...ids].some(id=>!required.has(id))) throw new Error('필수 캡처 ID가 중복되거나 다릅니다.');
    if (manifest.status==='ready' && ids.size!==required.size) throw new Error('필수6장 캡처가 모두 필요합니다.');
    const viewed = new Set(review.comparedImages.map(path=>resolve(path)));
    for (const capture of manifest.captures) {
        if (!viewed.has(resolve(capture.path))) throw new Error('감독이 보지 않은 필수 캡처: '+capture.id);
        if (fileHash(capture.path) !== capture.sha256 || fileHash(capture.state) !== capture.stateSha256) throw new Error('이미지 또는 실제 상태 기록이 바뀌었습니다: '+capture.id);
    }
    if (manifest.reference.sha256!==REFERENCE_SHA || !viewed.has(resolve(manifest.reference.path)) || fileHash(manifest.reference.path)!==REFERENCE_SHA) throw new Error('실제 사용자 레퍼런스 비교가 필요합니다.');
}

function session(root) {
    const path = resolve(root,'session.json');
    if (existsSync(path)) return json(path);
    if (fileHash(reference)!==REFERENCE_SHA) throw new Error('사용자 레퍼런스 해시가 다릅니다.');
    const current = {schemaVersion:1, maxReviews:MAX_REVIEWS, reference:{path:reference,sha256:REFERENCE_SHA}, rounds:[]};
    writeJSON(path,current);
    return current;
}

export function reserveRound(current, round) {
    assertRound(round);
    if (current.rounds.some(item=>item.round===round && item.reviewSha256)) throw new Error('감독이 판정한 회차를 덮어쓸 수 없습니다.');
    if (current.rounds.filter(item=>item.reviewSha256).length>=MAX_REVIEWS) throw new Error('독립 감독5회가 끝났습니다.');
    const previous=current.rounds.find(item=>item.round===round-1);
    if (round>1 && !previous?.reviewSha256 && previous?.status!=='failed') throw new Error('앞 회차 감독 판정 또는 기술 실패 기록이 먼저 필요합니다.');
    const existing = current.rounds.find(item=>item.round===round);
    if (existing && existing.status!=='failed') throw new Error('진행 중이거나 완료된 캡처는 재촬영할 수 없습니다.');
}

function saveRound(root, current, manifest) {
    writeJSON(resolve(root,'round-'+manifest.round,'manifest.json'),manifest);
    const entry = current.rounds.find(item=>item.round===manifest.round);
    if (entry) Object.assign(entry,{status:manifest.status, attempt:manifest.attempt});
    else current.rounds.push({round:manifest.round,status:manifest.status,attempt:manifest.attempt});
    writeJSON(resolve(root,'session.json'),current);
}

function logged(command, args, path) {
    mkdirSync(dirname(path),{recursive:true});
    return new Promise((resolveRun,reject)=>{
        const fd=openSync(path,'wx');
        const child=spawn(command,args,{cwd:repository,stdio:['ignore',fd,fd]});
        child.once('error',error=>{closeSync(fd);reject(error);});
        child.once('exit',(code,signal)=>{closeSync(fd);code===0?resolveRun():reject(new Error(`${command} 실패: ${code ?? signal}; ${path}`));});
    });
}

function packAt(web) {
    const html=readFileSync(resolve(web,'index.html'),'utf8');
    const names=readdirSync(web).filter(name=>/^index-[0-9a-f]+\.pck$/.test(name) && html.includes(name));
    if (names.length!==1) throw new Error('사용하는 Web PCK를 특정할 수 없습니다.');
    return {name:names[0],sha256:fileHash(resolve(web,names[0]))};
}

function webSnapshot(web) {
    const files=[];
    for (const name of readdirSync(web).sort()) {
        const path=resolve(web,name);
        if (statSync(path).isFile()) files.push({name,sha256:fileHash(path),bytes:statSync(path).size});
    }
    return digest(JSON.stringify(files));
}

export function validateBuildRecord(record, pack) {
    if (record.schemaVersion!==1 || !/^[0-9a-f]{64}$/.test(record.source?.sha256 ?? '') || !/^[0-9a-f]{40}$/.test(record.gitCommit ?? '')) throw new Error('freeze 빌드의 소스/커밋 기록이 필요합니다.');
    if (!Array.isArray(record.source.files) || digest(JSON.stringify(record.source.files))!==record.source.sha256) throw new Error('freeze 소스 파일 목록과 지문이 다릅니다.');
    if (record.pack?.name!==pack.name || record.pack?.sha256!==pack.sha256) throw new Error('freeze 빌드 기록과 실제 PCK가 다릅니다.');
}

async function verifyServer(url, web, pack) {
    const response=await fetch(new URL('index.html',url),{signal:AbortSignal.timeout(10000)});
    if (!response.ok || digest(Buffer.from(await response.arrayBuffer()))!==fileHash(resolve(web,'index.html'))) throw new Error('검수 URL과 지정 Web 폴더의 HTML이 다릅니다.');
    const download=await fetch(new URL(pack.name,url),{signal:AbortSignal.timeout(30000)});
    if (!download.ok || !download.body) throw new Error('실제 제공 PCK를 읽을 수 없습니다.');
    const hash=createHash('sha256');
    for await (const chunk of download.body) hash.update(chunk);
    if (hash.digest('hex')!==pack.sha256) throw new Error('서버 PCK 바이트가 freeze 빌드와 다릅니다.');
    // 동일 HTML/PCK만으로 WASM/JS 교체를 놓치지 않도록 부속 Web 파일도 비교한다.
    for (const name of readdirSync(web).sort()) {
        const path=resolve(web,name);
        if (!statSync(path).isFile() || name==='index.html' || name===pack.name) continue;
        const resource=await fetch(new URL(name,url),{signal:AbortSignal.timeout(30000)});
        if (!resource.ok || !resource.body) throw new Error('서버 부속 파일을 읽을 수 없습니다: '+name);
        const resourceHash=createHash('sha256');
        for await (const chunk of resource.body) resourceHash.update(chunk);
        if (resourceHash.digest('hex')!==fileHash(path)) throw new Error('서버 부속 파일 바이트가 다릅니다: '+name);
    }
}

async function capture(root, round, options) {
    const current=session(root);
    reserveRound(current,round);
    const previousEntry=current.rounds.find(item=>item.round===round);
    const previous=previousEntry?json(resolve(root,'round-'+round,'manifest.json')):null;
    const attempt=(previousEntry?.attempt ?? 0)+1;
    const folder=resolve(root,'round-'+round,'attempt-'+attempt);
    mkdirSync(folder,{recursive:true});
    const frozen=Boolean(options['build-record']);
    const web=resolve(options['web-dir'] ?? resolve(project,'build/web'));
    const url=options.url ?? 'http://127.0.0.1:8890/';
    const before=frozen?json(resolve(options['build-record'])).source:sourceSnapshot(project);
    const record=frozen?json(resolve(options['build-record'])):null;
    // 화면을 만들 수 있었던 후보를 바꿔 같은 회차의 '기술 재시도'로 숨기지 않는다.
    if (previous?.pack && previous.source.sha256!==before.sha256) throw new Error('기술 재시도는 같은 소스만 가능합니다. 실패 파일을 보존하고 다음 후보 회차를 사용하세요.');
    const reuseCandidate=!frozen && Boolean(previous?.pack);
    const manifest={schemaVersion:1,round,attempt,status:'building',kind:frozen?'frozen_baseline':'candidate',reference:current.reference,gitCommit:record?.gitCommit ?? (reuseCandidate?previous.gitCommit:null) ?? execFileSync('git',['rev-parse','HEAD'],{cwd:repository,encoding:'utf8'}).trim(),source:before,captureConditions:'기본1×·절약화질·DPR1. phone PNG720×1280, phone-landscape PNG1280×720. 실제3D 제출 해상도는 각 상태의 native_width/native_height로 별도 기록한다.',captures:[]};
    saveRound(root,current,manifest);
    try {
        if (!frozen) {
            if (!reuseCandidate) await logged(resolve(project,'tools/export_web.sh'),[],resolve(folder,'build.log'));
            if (sourceSnapshot(project).sha256!==before.sha256) throw new Error('빌드 중 운영 소스가 변경됐습니다.');
        }
        manifest.pack=packAt(web);
        if (record) validateBuildRecord(record,manifest.pack);
        if (previous?.pack && (previous.pack.name!==manifest.pack.name || previous.pack.sha256!==manifest.pack.sha256)) throw new Error('기술 재시도는 같은 PCK만 가능합니다.');
        const webHash=webSnapshot(web);
        manifest.web={directory:web,sha256:webHash};
        if (previous?.web && previous.web.sha256!==webHash) throw new Error('기술 재시도 Web 파일이 바뀌었습니다.');
        await verifyServer(url,web,manifest.pack);
        manifest.status='capturing';saveRound(root,current,manifest);
        for (const item of captureCases(options['entrance-at'])) {
            const path=resolve(folder,item.id+'.png');
            const statePath=resolve(folder,item.id+'.json');
            const args=[resolve(project,'tools/screenshot.mjs'),'--scene',item.scene,'--class','mage','--device',item.device,'--viewport',item.viewport,'--zoom','1','--quality','low','--dpr','1','--capture-timeout','120000','--url',url,'--out',path,'--state-out',statePath,'--settle','1000'];
            if (item.at) args.push('--at',item.at);
            console.log('CAPTURE_START '+item.id);
            await logged(process.execPath,args,resolve(folder,item.id+'.log'));
            const state=json(statePath);
            validateCapture(state,manifest.pack.name,item);
            const png=readFileSync(path);
            if (png.subarray(0,8).toString('hex')!=='89504e470d0a1a0a') throw new Error('실제 PNG 캡처가 아닙니다: '+item.id);
            manifest.captures.push({...item,path,state:statePath,sha256:fileHash(path),stateSha256:fileHash(statePath),pngPixels:[png.readUInt32BE(16),png.readUInt32BE(20)],nativePixels:[state.probe.native_width,state.probe.native_height]});
            console.log('CAPTURE_PASS '+item.id);
        }
        if (webSnapshot(web)!==webHash) throw new Error('촬영 도중 Web 산출물이 변경됐습니다.');
        if (!frozen && sourceSnapshot(project).sha256!==before.sha256) throw new Error('촬영 도중 운영 소스가 변경됐습니다.');
        manifest.status='ready';manifest.finishedAt=new Date().toISOString();
        writeJSON(resolve(folder,'manifest.json'),manifest);
        saveRound(root,current,manifest);
        console.log('ROUND_CAPTURE_READY '+round);
    } catch (error) {
        manifest.status='failed';manifest.error=error.message;
        writeJSON(resolve(folder,'manifest.json'),manifest);
        saveRound(root,current,manifest);
        throw error;
    }
}

function accept(root, round) {
    const current=session(root);
    assertRound(round);
    const entry=current.rounds.find(item=>item.round===round);
    if (!entry || entry.reviewSha256) throw new Error('미검토 ready 회차만 감독 판정을 봉인할 수 있습니다.');
    const folder=resolve(root,'round-'+round);
    const path=resolve(folder,'review.json');
    const manifest=json(resolve(folder,'manifest.json'));
    const review=json(path);
    validateReview(review,manifest,current.rounds.filter(item=>item.reviewSha256).length);
    if (review.verdict==='pass' && manifest.kind==='candidate' && sourceSnapshot(project).sha256!==manifest.source.sha256) throw new Error('감독이 통과시킨 사진 이후 운영 소스가 바뀌었습니다.');
    writeFileSync(resolve(folder,'review.accepted.json'),readFileSync(path),{flag:'wx'});
    entry.reviewSha256=fileHash(path);entry.verdict=review.verdict;
    writeJSON(resolve(root,'session.json'),current);
    console.log('REVIEW_ACCEPTED '+round+' '+review.verdict);
}

function gallery(root) {
    const current=session(root);
    const escape=value=>String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
    const sections=current.rounds.map(item=>{
        const folder=resolve(root,'round-'+item.round);
        const manifest=json(resolve(folder,'manifest.json'));
        const review=item.reviewSha256?json(resolve(folder,'review.accepted.json')):null;
        if (review && fileHash(resolve(folder,'review.accepted.json'))!==item.reviewSha256) throw new Error('봉인된 감독 판정이 변경됐습니다.');
        const pictures=manifest.captures.map(c=>`<figure><figcaption>${escape(c.id)} · ${escape(c.purpose)}</figcaption><a href="${escape(relative(root,c.path))}"><img loading="lazy" src="${escape(relative(root,c.path))}" alt="${escape(c.id)}"></a></figure>`).join('');
        const notes=review?[...review.blockers,...review.nextChanges].map(note=>`<li>${escape(note)}</li>`).join(''):'';
        const reviewNumber=current.rounds.filter(r=>r.round<=item.round && r.reviewSha256).length;
        return `<section><h2>후보 ${item.round} · ${review ? '감독 '+reviewNumber+'/5' : '미검토'} · ${escape(review?.verdict ?? manifest.status)}</h2><p>${escape(manifest.captureConditions)}</p><p>정성 척도0..5: ${escape(JSON.stringify(review?.scores ?? {}))}</p><ul>${notes}</ul><div class="pictures">${pictures}</div></section>`;
    }).join('');
    writeFileSync(resolve(root,'index.html'),`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>동굴 구현·독립 감독 비교</title><style>body{background:#17201f;color:#e7e4d5;font:16px/1.6 system-ui;margin:24px}main{max-width:1500px;margin:auto}.pictures{display:flex;flex-wrap:wrap;gap:20px}figure{margin:0;max-width:430px}img{width:100%;height:auto}section{border-top:1px solid #65715b;margin-top:32px}a{color:#d1dfbc}.reference{max-width:300px}</style><main><h1>동굴 구현·독립 감독 비교</h1><p>실제 비교는 최대5회이며 baseline도1회입니다. 이미지·상태·소스·PCK를 고정하고 독립 감독이 판정합니다. 정성 점수는 달성률이 아닙니다.</p><figure class="reference"><figcaption>사용자 스타일 원본</figcaption><img src="${escape(relative(root,reference))}" alt="사용자 스타일 원본"></figure>${sections}</main></html>`);
}

async function main() {
    const [command,...tokens]=process.argv.slice(2);
    const options=Object.fromEntries(tokens.reduce((pairs,value,index,array)=>value.startsWith('--')?[...pairs,[value.slice(2),array[index+1]]]:pairs,[]));
    const root=resolve(options.out ?? defaultOutput);
    const round=Number(options.round ?? (command==='baseline'?1:NaN));
    if (command==='baseline') {
        if (!options['build-record'] || !options['web-dir']) throw new Error('baseline에는 --build-record와 --web-dir이 필요합니다.');
        await capture(root,round,options);
    } else if (command==='capture') {
        if (options['build-record'] || options['web-dir']) throw new Error('새 후보는 운영 소스를 직접 빌드합니다. baseline 옵션을 사용할 수 없습니다.');
        await capture(root,round,options);
    } else if (command==='accept-review') accept(root,round);
    else if (command!=='gallery') throw new Error('사용법: harness.mjs baseline|capture --round N|accept-review --round N|gallery [--out 폴더]');
    gallery(root);
}
if (process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) main().catch(error=>{console.error(error.message);process.exitCode=1;});
