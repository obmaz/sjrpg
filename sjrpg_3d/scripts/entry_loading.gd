class_name EntryLoading
extends CanvasLayer
## A real paint barrier precedes blocking persistence and native-world construction.
const TEXT := {
	"load": "저장된 모험을 불러오는 중",
	"create": "새 모험을 기록하는 중",
	"world": "숲의 길을 준비하는 중",
	"ready": "모험에 들어가는 중",
}
var sequence := 0
var operation := ""
var slot := 1
var hero_class := ""
var phase := ""
var painted_phases: Array[String] = []
var _active := true
var _status: Label
var _panel: PanelContainer
var _native_root: Control
var _web := false

const WEB_UI := """
(() => {
 if(window.__sjrpgEntryLoadingUI)return;
 let state=null, first=0, second=0;
 const cancelPaint=()=>{cancelAnimationFrame(first);cancelAnimationFrame(second);first=0;second=0;};
 const publish=()=>{window.__sjrpgEntryLoading=JSON.parse(JSON.stringify(state));};
 const keyBlock=e=>{if(!e.ctrlKey&&!e.metaKey&&!e.altKey&&e.key!=='F5'){e.preventDefault();e.stopImmediatePropagation();}};
 const eventFor=phase=>{let e=state.phase_events.findLast(v=>v.phase===phase);return e;};
 window.__sjrpgEntryLoadingUI={
  mount(data){
   cancelPaint();
   const old=document.getElementById('sjrpg-entry-loading');if(old)old.remove();
   if(!document.getElementById('sjrpg-entry-loading-css')){
    const style=document.createElement('style');style.id='sjrpg-entry-loading-css';
    style.textContent='#sjrpg-entry-loading{position:fixed;inset:0;z-index:10000;display:grid;place-items:center;padding:max(20px,env(safe-area-inset-top)) max(18px,env(safe-area-inset-right)) max(20px,env(safe-area-inset-bottom)) max(18px,env(safe-area-inset-left));background:#080b10;background-position:center;background-size:cover;color:#e7dfd0;font-family:"Apple SD Gothic Neo","Malgun Gothic",sans-serif;outline:none;touch-action:none;user-select:none;-webkit-user-select:none;box-sizing:border-box}#sjrpg-entry-loading .entry-load-card{box-sizing:border-box;width:min(100%,440px);padding:28px 24px;border:1px solid #756348;border-radius:5px;background:#171e1cf2;text-align:center;box-shadow:0 12px 40px #0008}#sjrpg-entry-loading h2{font-size:clamp(22px,5vw,30px);margin:16px 0 14px;font-weight:700;line-height:1.35}#sjrpg-entry-loading-status{font-size:16px;line-height:1.6;margin:0;color:#e7dfd0;overflow-wrap:anywhere}#sjrpg-entry-loading .entry-load-note{font-size:13px;line-height:1.6;margin:16px 0 0;color:#afa28c}#sjrpg-entry-loading-spinner{display:block;margin:auto;width:30px;height:30px;box-sizing:border-box;border:2px solid #75634866;border-top-color:#c9af7c;border-right-color:#a48b63;border-radius:50%;animation:sjrpgEntrySpin 1.1s linear infinite;will-change:transform}#sjrpg-entry-loading .entry-load-track{height:4px;margin-top:24px;background:#080c0c;overflow:hidden;border-radius:2px}#sjrpg-entry-loading .entry-load-fill{display:block;width:35%;height:100%;background:linear-gradient(90deg,#756348,#c9af7c);animation:sjrpgEntrySweep 1.8s ease-in-out infinite;will-change:transform}@keyframes sjrpgEntrySpin{to{transform:rotate(360deg)}}@keyframes sjrpgEntrySweep{0%{transform:translateX(-105%)}100%{transform:translateX(390%)}}#sjrpg-entry-loading.reduce-motion #sjrpg-entry-loading-spinner,#sjrpg-entry-loading.reduce-motion .entry-load-fill{animation:none}@media(prefers-reduced-motion:reduce){#sjrpg-entry-loading-spinner,#sjrpg-entry-loading .entry-load-fill{animation:none}}@media(max-height:400px){#sjrpg-entry-loading .entry-load-card{padding:16px 24px}#sjrpg-entry-loading h2{margin:10px 0;font-size:22px}#sjrpg-entry-loading .entry-load-track{margin-top:16px}#sjrpg-entry-loading .entry-load-note{margin-top:10px}}';
    document.head.appendChild(style);
   }
   const el=document.createElement('section');el.id='sjrpg-entry-loading';el.tabIndex=-1;el.setAttribute('role','status');el.setAttribute('aria-live','polite');el.setAttribute('aria-label','모험 준비');
   el.innerHTML='<div class="entry-load-card"><span id="sjrpg-entry-loading-spinner" aria-hidden="true"></span><h2>모험을 준비합니다</h2><p id="sjrpg-entry-loading-status"></p><div class="entry-load-track" aria-hidden="true"><span class="entry-load-fill"></span></div><p class="entry-load-note">잠시만 기다려 주세요.</p></div>';
   el.classList.toggle('reduce-motion',data.reduce_motion);
   const loading=document.getElementById('loading');const bg=loading?getComputedStyle(loading,'::before').backgroundImage:'none';
   if(bg&&bg!=='none')el.style.backgroundImage='linear-gradient(#080d0bc9,#080b10f5),'+bg;
   document.body.appendChild(el);
   window.addEventListener('keydown',keyBlock,true);el.focus({preventScroll:true});
   state={...data,visible:true,phase:'',phase_events:[],painted_phases:[],began_at:performance.now(),native_ready_at:null,finished_at:null};
   publish();
  },
  phase(sequence,phase,text){
   if(!state||state.sequence!==sequence||!state.visible)return;
   cancelPaint();state.phase=phase;state.status=text;
   state.phase_events.push({phase,shown_at:performance.now(),raf1_at:null,painted_at:null,work_at:null});
   const el=document.getElementById('sjrpg-entry-loading');el.dataset.phase=phase;
   document.getElementById('sjrpg-entry-loading-status').textContent=text;publish();
  },
  requestPaint(sequence,phase){
   if(!state||state.sequence!==sequence||!state.visible)return;
   cancelPaint();
   first=requestAnimationFrame(()=>{
    if(!state||state.sequence!==sequence||!state.visible||state.phase!==phase)return;
    eventFor(phase).raf1_at=performance.now();publish();
    second=requestAnimationFrame(()=>{
     if(!state||state.sequence!==sequence||!state.visible||state.phase!==phase)return;
     eventFor(phase).painted_at=performance.now();
     if(!state.painted_phases.includes(phase))state.painted_phases.push(phase);publish();
    });
   });
  },
  painted(sequence,phase){return !!state&&state.sequence===sequence&&state.visible&&state.phase===phase&&state.painted_phases.includes(phase);},
  work(sequence,phase){if(state&&state.sequence===sequence&&state.visible){const e=eventFor(phase);if(e)e.work_at=performance.now();publish();}},
  nativeReady(sequence){if(state&&state.sequence===sequence&&state.visible){state.native_ready_at=performance.now();publish();}},
  hide(sequence,reason){
   if(!state||state.sequence!==sequence||!state.visible)return;
   cancelPaint();state.visible=false;state.finished_at=performance.now();state.result=reason;publish();
   const el=document.getElementById('sjrpg-entry-loading');if(el)el.remove();
   window.removeEventListener('keydown',keyBlock,true);
   const canvas=document.getElementById('canvas');if(canvas)canvas.focus({preventScroll:true});
  }
 };
})();
"""


func setup(action: String, selected_slot: int, cls: String, id: int) -> EntryLoading:
	operation = action
	slot = selected_slot
	hero_class = cls
	sequence = id
	return self


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	if _web:
		JavaScriptBridge.eval(WEB_UI, true)
		var data := {"sequence": sequence, "operation": operation, "slot": slot, "class": hero_class, "reduce_motion": Prefs.reduce_motion}
		JavaScriptBridge.eval("window.__sjrpgEntryLoadingUI.mount(" + JSON.stringify(data) + ")", true)
	else:
		_build_native()


func _build_native() -> void:
	_native_root = Control.new()
	_native_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_native_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_native_root.focus_mode = Control.FOCUS_ALL
	add_child(_native_root)
	EntryUi.backdrop(_native_root)
	EntryUi.shade(_native_root, 0.97)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_native_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color("171e1c"), EntryUi.BRONZE, 5))
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)
	var title := EntryUi.label("모험을 준비합니다", 30, EntryUi.TEXT, true)
	title.name = "LoadingTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	_status = EntryUi.label("", 22, EntryUi.TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var progress := ProgressBar.new()
	progress.indeterminate = true
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 6)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("080c0c")
	var fill := StyleBoxFlat.new()
	fill.bg_color = EntryUi.BRONZE
	progress.add_theme_stylebox_override("background", track)
	progress.add_theme_stylebox_override("fill", fill)
	box.add_child(progress)
	var note := EntryUi.label("잠시만 기다려 주세요.", 16, EntryUi.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	get_viewport().size_changed.connect(_fit_native)
	_fit_native()
	_native_root.grab_focus()


func _fit_native() -> void:
	if _panel == null:
		return
	var view := get_viewport().get_visible_rect().size
	var width := maxf(120.0, minf(520.0, view.x - 48.0))
	_panel.custom_minimum_size = Vector2(width, 0)
	# Container minimums follow real wrapped text; fixed proportional heights are not used.


func set_phase(value: String) -> void:
	phase = value
	var text: String = str(TEXT.get(value, "모험을 준비하는 중"))
	if _web:
		JavaScriptBridge.eval("window.__sjrpgEntryLoadingUI.phase(%d,%s,%s)" % [sequence, JSON.stringify(phase), JSON.stringify(text)], true)
		JavaScriptBridge.eval("window.__sjrpgEntryLoadingUI.requestPaint(%d,%s)" % [sequence, JSON.stringify(phase)], true)
	elif _status != null:
		_status.text = text


func browser_painted() -> bool:
	if not _web:
		return true
	var ready: Variant = JavaScriptBridge.eval("window.__sjrpgEntryLoadingUI.painted(%d,%s) ? 1 : 0" % [sequence, JSON.stringify(phase)], true)
	return (ready is int or ready is float) and int(ready) == 1


func mark_painted() -> void:
	if not painted_phases.has(phase):
		painted_phases.append(phase)


func note_work() -> void:
	if _web:
		JavaScriptBridge.eval("window.__sjrpgEntryLoadingUI.work(%d,%s)" % [sequence, JSON.stringify(phase)], true)


func note_native_ready() -> void:
	if _web:
		JavaScriptBridge.eval("window.__sjrpgEntryLoadingUI.nativeReady(%d)" % sequence, true)


func dismiss(reason := "ready") -> void:
	if not _active:
		return
	_active = false
	if _web:
		JavaScriptBridge.eval("window.__sjrpgEntryLoadingUI.hide(%d,%s)" % [sequence, JSON.stringify(reason)], true)


func _exit_tree() -> void:
	dismiss("cancelled")


func _input(_event: InputEvent) -> void:
	if _active:
		get_viewport().set_input_as_handled()


func snapshot() -> Dictionary:
	var view := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	return {"visible": _active and is_inside_tree(), "phase": phase, "sequence": sequence,
		"operation": operation, "slot": slot, "class": hero_class,
		"painted_phases": painted_phases.duplicate(), "viewport": [view.x, view.y],
		"rect": [0.0, 0.0, view.x, view.y]}
