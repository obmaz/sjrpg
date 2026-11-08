import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const source = readFileSync(new URL('./canvas-budget.js', import.meta.url), 'utf8');
function fixture({width=768,height=1024,ratio=3,agent='Android',platform='',touch=5}={}) {
  const events=new Map(),frames=[],canvas={width:300,height:150,style:{}};
  const bind=(target,type,fn)=>events.set(target+':'+type,fn);
  const window={innerWidth:width,innerHeight:height,devicePixelRatio:ratio,
    addEventListener:(type,fn)=>bind('window',type,fn),
    visualViewport:{addEventListener:(type,fn)=>bind('visual',type,fn)}};
  const document={getElementById:()=>canvas,addEventListener:(type,fn)=>bind('document',type,fn)};
  vm.runInNewContext(source,{window,document,navigator:{userAgent:agent,platform,maxTouchPoints:touch},
    requestAnimationFrame:fn=>frames.push(fn)});
  const config={canvasResizePolicy:2,persistentPaths:['/userfs/sjrpg_3d']};
  const status=window.SjrpgCanvasBudget.configure(config);
  return {window,canvas,config,status,api:window.SjrpgCanvasBudget,events,frames,
    emit:(target,type)=>events.get(target+':'+type)?.(),flush:()=>{while(frames.length)frames.shift()();}};
}
let checks=0;
function budget(f) {
  const {width,height}=f.canvas;
  assert(width*height<=2097152,'final render target pixel budget');
  assert(width<=Math.ceil(f.window.innerWidth*2)&&height<=Math.ceil(f.window.innerHeight*2),'density budget');
  assert(Math.abs(width/height-f.window.innerWidth/f.window.innerHeight)<=2/Math.min(width,height),'aspect and input mapping');
  assert.equal(f.window.devicePixelRatio,3,'real browser DPR preserved');
  assert.equal(f.canvas.style.width,'100%');assert.equal(f.canvas.style.height,'100%');
  checks++;
}
const fold=fixture();
assert(fold.status.active);assert.equal(fold.config.canvasResizePolicy,0);
assert.equal(fold.config.canvas,fold.canvas);assert.deepEqual(fold.config.persistentPaths,['/userfs/sjrpg_3d']);
budget(fold);
assert(fold.canvas.width*fold.canvas.height<768*1024*9/2,'material reduction against uncapped Fold compositor');
const count=fold.api.snapshot().resize_count;
fold.window.innerWidth=1024;fold.window.innerHeight=768;
fold.emit('window','resize');fold.emit('window','orientationchange');fold.emit('document','fullscreenchange');
assert.equal(fold.frames.length,1,'fold/fullscreen events coalesce');fold.flush();
assert.equal(fold.api.snapshot().resize_count,count+1);budget(fold);
fold.window.innerWidth=390;fold.window.innerHeight=844;fold.emit('visual','resize');fold.flush();budget(fold);
const before=fold.api.snapshot().resize_count;
assert.equal(fold.api.configure(fold.config),fold.status,'single lifetime subscription');
assert.equal(fold.api.snapshot().resize_count,before);
const desktop=fixture({agent:'Windows Chrome',touch:0});
assert.equal(desktop.status.active,false);assert.equal(desktop.config.canvasResizePolicy,2);
assert.equal(desktop.canvas.width,300);assert.equal(desktop.events.size,0);checks++;
assert(fixture({agent:'Macintosh',platform:'MacIntel',touch:5}).status.active,'touch iPad identification');checks++;
for(const [w,h] of [[390,844],[768,1024],[1024,768],[360,2600],[1920,1080],[1,1]]) {
  const f=fixture({width:w,height:h});budget(f);
}
for(const [w,h,d] of [[0,0,0],[NaN,Infinity,-1]]) {
  const result=fold.api.dimensions(w,h,d);
  assert.equal(result.width,1);assert.equal(result.height,1);checks++;
}
const shell=readFileSync(new URL('./shell.html',import.meta.url),'utf8');
assert(shell.includes('src="canvas-budget.js"'));
assert(shell.indexOf('SjrpgCanvasBudget.configure(GODOT_CONFIG)')<shell.indexOf('new Engine(GODOT_CONFIG)'),'budget before renderer/context initialization');checks++;
console.log('MOBILE_CANVAS_BUDGET_PASS '+JSON.stringify({checks,fold_pixels:fixture().canvas.width*fixture().canvas.height}));
