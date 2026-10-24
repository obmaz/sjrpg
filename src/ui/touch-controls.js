import { canAct } from '../core/helpers.js';
import { player } from '../core/state.js';
import { getInteractionTarget } from '../systems/interactions.js';
import { performInputAction, touchKeys } from './input.js';

let initialized = false;
let stickPointer = null;
let attackPointer = null;
let joystick;
let thumb;
let attackButton;
const renderedItems = [];
const controlElements = new Map();
const renderedControls = new WeakMap();

function control(id) {
    if (!controlElements.has(id)) controlElements.set(id, document.getElementById(id));
    return controlElements.get(id);
}

function setControlValue(target, property, value) {
    let previous = renderedControls.get(target);
    if (!previous) {
        previous = {};
        renderedControls.set(target, previous);
    }
    if (previous[property] === value) return;
    target[property] = value;
    previous[property] = value;
}

function releaseTouchControls() {
    for (const code of Object.keys(touchKeys)) delete touchKeys[code];
    if (!initialized) return;
    if (stickPointer !== null && joystick.hasPointerCapture(stickPointer))
        joystick.releasePointerCapture(stickPointer);
    if (attackPointer !== null && attackButton.hasPointerCapture(attackPointer))
        attackButton.releasePointerCapture(attackPointer);
    stickPointer = null;
    attackPointer = null;
    thumb.style.transform = 'translate(-50%, -50%)';
    joystick.classList.remove('active');
    attackButton.classList.remove('active');
}

function moveStick(event) {
    if (event.pointerId !== stickPointer) return;
    if (!canAct()) {
        releaseTouchControls();
        return;
    }
    event.preventDefault();
    const bounds = joystick.getBoundingClientRect();
    const radius = bounds.width * 0.36;
    const x = event.clientX - bounds.left - bounds.width / 2;
    const y = event.clientY - bounds.top - bounds.height / 2;
    const magnitude = Math.hypot(x, y);
    const scale = magnitude > radius ? radius / magnitude : 1;
    thumb.style.transform = `translate(calc(-50% + ${x * scale}px), calc(-50% + ${y * scale}px))`;
    const moving = magnitude > radius * 0.2;
    const horizontal = moving && Math.abs(x) >= Math.abs(y) * 0.45;
    const vertical = moving && Math.abs(y) >= Math.abs(x) * 0.45;
    touchKeys.ArrowLeft = horizontal && x < 0;
    touchKeys.ArrowRight = horizontal && x > 0;
    touchKeys.ArrowUp = vertical && y < 0;
    touchKeys.ArrowDown = vertical && y > 0;
}

function releaseStick(event) {
    if (event.pointerId !== stickPointer) return;
    stickPointer = null;
    for (const code of ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown']) delete touchKeys[code];
    thumb.style.transform = 'translate(-50%, -50%)';
    joystick.classList.remove('active');
}

function releaseAttack(event) {
    if (event.pointerId !== attackPointer) return;
    attackPointer = null;
    delete touchKeys.Space;
    attackButton.classList.remove('active');
}

function initializeTouchControls() {
    if (initialized) return;
    initialized = true;
    joystick = document.getElementById('touchJoystick');
    thumb = document.getElementById('touchThumb');
    attackButton = document.getElementById('touchAttack');
    joystick.addEventListener('pointerdown', (event) => {
        if (!canAct() || stickPointer !== null || event.button > 0) return;
        stickPointer = event.pointerId;
        joystick.setPointerCapture(stickPointer);
        joystick.classList.add('active');
        moveStick(event);
    });
    joystick.addEventListener('pointermove', moveStick);
    attackButton.addEventListener('pointerdown', (event) => {
        if (!canAct() || attackPointer !== null || event.button > 0) return;
        event.preventDefault();
        attackPointer = event.pointerId;
        attackButton.setPointerCapture(attackPointer);
        touchKeys.Space = true;
        attackButton.classList.add('active');
    });
    for (const name of ['pointerup', 'pointercancel', 'lostpointercapture']) {
        joystick.addEventListener(name, releaseStick);
        attackButton.addEventListener(name, releaseAttack);
    }
    const actions = {
        touchInventory: 'KeyI',
        touchCompendium: 'KeyC',
        touchQuests: 'KeyL',
        touchSettings: 'KeyP',
        touchDismount: 'KeyU',
        touchInteract: 'KeyE',
        touchAux: 'KeyN',
        touchCycle: 'KeyQ',
        touchItem1: 'Digit1',
        touchItem2: 'Digit2',
        touchItem3: 'Digit3',
        closeInventory: 'Escape',
        resumeInventory: 'Escape',
        closeShop: 'Escape',
        resumeShop: 'Escape',
        closeNpcDialog: 'Escape',
        resumeNpcDialog: 'Escape',
        closeAppearance: 'Escape',
        resumeAppearance: 'Escape',
        closeCompendium: 'Escape',
        closeQuestJournal: 'Escape',
        resumeQuestJournal: 'Escape',
        resumeCompendium: 'Escape',
    };
    for (const [id, code] of Object.entries(actions)) {
        document.getElementById(id).addEventListener('click', () => {
            performInputAction(code);
            updateTouchControls();
        });
    }
    window.addEventListener('blur', releaseTouchControls);
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) releaseTouchControls();
    });
    updateTouchControls();
}

function updateTouchControls() {
    if (!initialized) return;
    const enabled = canAct();
    document.getElementById('touchControls').classList.toggle('hidden', !enabled);
    if (!enabled) releaseTouchControls();
    for (let i = 0; i < 3; i++) {
        const button = document.getElementById(`touchItem${i + 1}`);
        const item = player.items[i];
        const signature = item ? `${item.id}:${item.icon}` : 'empty';
        if (renderedItems[i] !== signature) {
            const icon = item
                ? item.icon
                : '<svg class="ui-icon" aria-hidden="true"><use href="#icon-potion"></use></svg>';
            button.innerHTML = `<span class="quick-index">${i + 1}</span><span class="quick-icon">${icon}</span>`;
            renderedItems[i] = signature;
        }
        button.disabled = !enabled || !item;
        const label = item ? `${item.name} 사용` : `아이템 ${i + 1} 비어 있음`;
        if (button.getAttribute('aria-label') !== label) button.setAttribute('aria-label', label);
    }
    document.getElementById('touchDismount').disabled = !player.mount;
    document.getElementById('touchDismount').classList.toggle('hidden', !player.mount);
    const auxiliary = player.auxWeapon;
    const remaining = Math.max(0, player.auxCooldown);
    const cooldown = Math.max(auxiliary?.cooldown || 1, remaining);
    setControlValue(control('touchAttackIcon'), 'textContent', player.weapon.icon);
    setControlValue(control('touchAuxIcon'), 'textContent', auxiliary?.icon || '✦');
    setControlValue(
        control('touchAuxStatus'),
        'textContent',
        !auxiliary ? '미획득' : remaining > 0 ? `${Math.ceil(remaining)}초` : '보조',
    );
    setControlValue(
        control('touchAuxCount'),
        'textContent',
        auxiliary ? (auxiliary.uses === -1 ? '∞' : String(auxiliary.uses)) : '',
    );
    setControlValue(
        control('touchAuxRing').style,
        'strokeDashoffset',
        String(auxiliary ? Math.round((remaining / cooldown) * 100) : 100),
    );
    const attackLabel = `${player.weapon.name} 공격, 누르고 있으면 연속 공격`;
    if (attackButton.getAttribute('aria-label') !== attackLabel)
        attackButton.setAttribute('aria-label', attackLabel);
    const auxiliaryLabel = auxiliary
        ? `${auxiliary.name}, ${remaining > 0 ? `${Math.ceil(remaining)}초 후 사용 가능` : '사용 가능'}`
        : '보조무기 미획득';
    if (control('touchAux').getAttribute('aria-label') !== auxiliaryLabel)
        control('touchAux').setAttribute('aria-label', auxiliaryLabel);
    control('touchAux').disabled = !enabled || !auxiliary || remaining > 0;
    document.getElementById('touchCycle').disabled = player.auxWeapons.length < 2;
    const target = enabled ? getInteractionTarget() : null;
    const interact = control('touchInteract');
    setControlValue(interact, 'disabled', !target);
    setControlValue(control('touchInteractLabel'), 'textContent', target?.label || '대화');
    const symbol = `#${target?.symbol || 'icon-chat'}`;
    if (control('touchInteractSymbol').getAttribute('href') !== symbol)
        control('touchInteractSymbol').setAttribute('href', symbol);
    if (interact.classList.contains('ready') !== !!target)
        interact.classList.toggle('ready', !!target);
    const interactionLabel = target
        ? `${target.kind === 'portal' ? '차원 포탈' : target.entity.name}, ${target.label}`
        : '근처 인물이나 포탈에 다가가세요';
    if (interact.getAttribute('aria-label') !== interactionLabel)
        interact.setAttribute('aria-label', interactionLabel);
}

export { initializeTouchControls, updateTouchControls, releaseTouchControls };
