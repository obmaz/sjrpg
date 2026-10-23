import { CONSUMABLE_CAPACITY } from '../core/constants.js';
import { player } from '../core/state.js';
import { DESERT_QUESTS, MAIN_QUESTS } from '../data/quests.js';

const hudElements = new Map();
const renderedValues = new WeakMap();

function getHudElement(id) {
    if (!hudElements.has(id)) hudElements.set(id, document.getElementById(id));
    return hudElements.get(id);
}

function setValue(target, property, value) {
    if (!target) return;
    let previous = renderedValues.get(target);
    if (!previous) {
        previous = {};
        renderedValues.set(target, previous);
    }
    if (previous[property] === value) return;
    target[property] = value;
    previous[property] = value;
    // Both setters replace the same content, so invalidate the alternate representation.
    if (property === 'textContent') delete previous.innerHTML;
    else if (property === 'innerHTML') delete previous.textContent;
}

function setText(id, text) {
    setValue(getHudElement(id), 'textContent', text);
}

function setClass(element, name, enabled) {
    if (element.classList.contains(name) !== enabled) element.classList.toggle(name, enabled);
}

function updateHud() {
    const weapon = player.weapon;
    const usesText = weapon.uses !== undefined ? ` [${weapon.uses}회]` : '';
    setValue(
        getHudElement('equipmentSlot'),
        'innerHTML',
        `${weapon.icon} ${weapon.name} <span style="color:#ff8888;font-size:10px;">ATK ${weapon.atk}${usesText}</span>`,
    );
    setText('hpText', `${Math.max(0, Math.round(player.hp))} / ${player.maxHp}`);

    const hpRatio = Math.max(0, player.hp / player.maxHp);
    const hpBar = getHudElement('hpBarFill');
    setValue(hpBar.style, 'width', `${hpRatio * 100}%`);
    setClass(hpBar, 'low', hpRatio < 0.3);
    setClass(hpBar, 'mid', hpRatio >= 0.3 && hpRatio < 0.6);

    // Portrait face based on HP
    const portrait = getHudElement('charPortrait');
    const hudTop = getHudElement('hudTop');
    setClass(portrait, 'danger', hpRatio < 0.2);
    setClass(portrait, 'warning', hpRatio >= 0.2 && hpRatio < 0.4);
    setClass(hudTop, 'danger', hpRatio < 0.2);
    setText('portraitFace', hpRatio < 0.2 ? '🤕' : hpRatio < 0.4 ? '😰' : player.playerFace);

    setText('goldDisplay', `💰 ${player.gold}`);
    const minutes = Math.floor(player.gameTime / 60);
    const seconds = Math.floor(player.gameTime % 60);
    const timeDisplay = getHudElement('timeDisplay');
    const timeColor =
        player.gameTime < 60 ? '#ff4444' : player.gameTime < 180 ? '#ffaa44' : '#ff8866';
    setValue(timeDisplay, 'textContent', `⏱ ${minutes}:${seconds.toString().padStart(2, '0')}`);
    setValue(timeDisplay.style, 'color', timeColor);

    // Statuses can coexist: a speed boost must not hide ongoing poison damage.
    const statusDisplay = getHudElement('poisonDisplay');
    const statuses = [];
    if (player.speedBoost > 0) statuses.push(`⚡ 스피드 ${player.speedBoost.toFixed(1)}s`);
    if (player.poisonTimer > 0) {
        const poisonMinutes = Math.floor(player.poisonTimer / 60);
        const poisonSeconds = Math.floor(player.poisonTimer % 60);
        statuses.push(`☠️ 독 ${poisonMinutes}:${poisonSeconds.toString().padStart(2, '0')}`);
    }
    setValue(statusDisplay.style, 'display', statuses.length ? 'block' : 'none');
    setValue(statusDisplay.style, 'color', player.poisonTimer > 0 ? '#88ff44' : '#ffff44');
    setValue(statusDisplay, 'textContent', statuses.join(' | '));
    setText('stageInfo', `Stage ${player.stage}`);

    // Aux weapon display
    const auxiliaryWeapon = player.auxWeapon;
    const auxDisplay = getHudElement('auxDisplay');
    if (auxiliaryWeapon) {
        const usesText =
            auxiliaryWeapon.uses > 0
                ? ` [${auxiliaryWeapon.uses}]`
                : auxiliaryWeapon.uses === -1
                  ? ' [∞]'
                  : '';
        const cdText = player.auxCooldown > 0 ? ` (${player.auxCooldown.toFixed(1)}s)` : '';
        setValue(
            auxDisplay,
            'innerHTML',
            `${auxiliaryWeapon.icon} ${auxiliaryWeapon.name}${usesText}${cdText}`,
        );
        setValue(auxDisplay.style, 'color', auxiliaryWeapon.uses > 0 ? '#ff6644' : '#66bb6a');
    } else {
        setValue(auxDisplay, 'textContent', '없음');
        setValue(auxDisplay.style, 'color', '#888');
    }

    const regionQuests = player.currentRegion === 'desert' ? DESERT_QUESTS : MAIN_QUESTS;
    const mainProgress = regionQuests.filter((questId) =>
        player.completedQuests.includes(questId),
    ).length;
    setText('clearProgress', `📜 주요 퀘스트: ${mainProgress} / ${regionQuests.length}`);

    const mount = player.mount;
    const mountSlot = getHudElement('equipMount');
    if (mount) setText('mountDisplay', `${mount.icon} ${mount.name}`);
    setValue(mountSlot.style, 'display', mount ? 'flex' : 'none');

    for (let i = 0; i < CONSUMABLE_CAPACITY; i++) {
        setText('item' + (i + 1), player.items[i] ? player.items[i].icon : '—');
    }
}

export { updateHud };
