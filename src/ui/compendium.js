import { isGameActive } from '../core/helpers.js';
import { player, session } from '../core/state.js';
import { AUX_WEAPONS } from '../data/aux-weapons.js';
import { BOSS_TYPES } from '../data/bosses.js';
import { DESERT_ENEMY_TYPES, ENEMY_TYPES } from '../data/enemies.js';
import { ITEMS } from '../data/items.js';
import { WEAPONS } from '../data/weapons.js';

// ============================================================
//  COMPENDIUM (도감)
// ============================================================

function toggleCompendium() {
    if (
        !isGameActive() ||
        session.shopOpen ||
        session.inventoryOpen ||
        (session.gamePaused && !session.compendiumOpen)
    )
        return;
    session.compendiumOpen = !session.compendiumOpen;
    const panel = document.getElementById('compendiumPanel');
    if (session.compendiumOpen) {
        session.gamePaused = true;
        panel.classList.remove('hidden');
        renderCompendium();
    } else {
        session.gamePaused = false;
        panel.classList.add('hidden');
    }
}

function renderCompendium() {
    const grid = document.getElementById('compendiumGrid');
    grid.innerHTML = '';

    // Weapons section
    const weaponHeader = document.createElement('div');
    weaponHeader.className = 'compendium-section-header';
    weaponHeader.textContent = '⚔️ 무기';
    grid.appendChild(weaponHeader);

    WEAPONS.forEach((weapon) => {
        const owned = player.collection.weapons.includes(weapon.id);
        const card = document.createElement('div');
        card.className = 'compendium-card' + (owned ? '' : ' locked');
        card.innerHTML = `<span class="cc-icon">${owned ? weapon.icon : '❓'}</span><span class="cc-name">${owned ? weapon.name : '???'}</span>`;
        if (owned) {
            card.title = `${weapon.icon} ${weapon.name}\nATK: ${weapon.atk}\n${weapon.desc || ''}\n능력: ${weapon.ability || '기본'}\n희귀도: ${weapon.rarity || '일반'}`;
        } else {
            card.title = '아직 발견하지 못한 무기';
        }
        grid.appendChild(card);
    });

    // Items section
    const itemHeader = document.createElement('div');
    itemHeader.className = 'compendium-section-header';
    itemHeader.textContent = '🧪 아이템';
    grid.appendChild(itemHeader);

    ITEMS.forEach((item) => {
        const owned = player.collection.items.includes(item.id);
        const card = document.createElement('div');
        card.className = 'compendium-card' + (owned ? '' : ' locked');
        card.innerHTML = `<span class="cc-icon">${owned ? item.icon : '❓'}</span><span class="cc-name">${owned ? item.name : '???'}</span>`;
        if (owned) {
            card.title = `${item.icon} ${item.name}\n${item.desc}\n가격: ${item.price}💰`;
        } else {
            card.title = '아직 발견하지 못한 아이템';
        }
        grid.appendChild(card);
    });

    // Enemies section
    const enemyHeader = document.createElement('div');
    enemyHeader.className = 'compendium-section-header';
    enemyHeader.textContent = '👾 적';
    grid.appendChild(enemyHeader);

    const allEnemyTypes = [
        ...ENEMY_TYPES.filter((enemy) => !enemy.isBoss),
        ...DESERT_ENEMY_TYPES.filter((enemy) => !enemy.isBoss),
        ...ENEMY_TYPES.filter((enemy) => enemy.isBoss),
        ...DESERT_ENEMY_TYPES.filter((enemy) => enemy.isBoss),
        ...BOSS_TYPES,
    ];
    const seen = new Set();
    const uniqueEnemies = [];
    for (const enemy of allEnemyTypes) {
        if (!seen.has(enemy.name)) {
            seen.add(enemy.name);
            uniqueEnemies.push(enemy);
        }
    }

    uniqueEnemies.forEach((enemy) => {
        const owned = player.collection.enemies.includes(enemy.name);
        const card = document.createElement('div');
        card.className = 'compendium-card' + (owned ? '' : ' locked');
        const kills = player.killsByName[enemy.name] || 0;
        card.innerHTML = `<span class="cc-icon">${owned ? enemy.icon || '👾' : '❓'}</span><span class="cc-name">${owned ? enemy.name : '???'}</span>`;
        if (owned) {
            card.title = `${enemy.icon || '👾'} ${enemy.name}\nHP: ${enemy.hp} | ATK: ${enemy.atk}\n처치 수: ${kills}마리\n${enemy.flying ? '🕊️ 비행' : ''}${enemy.ranged ? '🏹 원거리' : ''}${enemy.giant ? '👣 거대' : ''}`;
        } else {
            card.title = '아직 만나보지 못한 적';
        }
        grid.appendChild(card);
    });

    // Aux weapons section
    const auxHeader = document.createElement('div');
    auxHeader.className = 'compendium-section-header';
    auxHeader.textContent = '🎒 보조무기';
    grid.appendChild(auxHeader);

    AUX_WEAPONS.forEach((auxiliaryWeapon) => {
        const owned = player.collection.auxiliaryWeapons.includes(auxiliaryWeapon.id);
        const card = document.createElement('div');
        card.className = 'compendium-card' + (owned ? '' : ' locked');
        card.innerHTML = `<span class="cc-icon">${owned ? auxiliaryWeapon.icon : '❓'}</span><span class="cc-name">${owned ? auxiliaryWeapon.name : '???'}</span>`;
        if (owned) {
            card.title = `${auxiliaryWeapon.icon} ${auxiliaryWeapon.name}\n${auxiliaryWeapon.desc}\n사용: ${auxiliaryWeapon.uses > 0 ? auxiliaryWeapon.uses + '회' : '무제한'}`;
        } else {
            card.title = '아직 발견하지 못한 보조무기';
        }
        grid.appendChild(card);
    });

    // Stats
    const totalWeapons = WEAPONS.length;
    const foundWeapons = player.collection.weapons.length;
    const totalItems = ITEMS.length;
    const foundItems = player.collection.items.length;
    const totalEnemies = uniqueEnemies.length;
    const foundEnemies = player.collection.enemies.length;
    document.getElementById('compendiumStats').textContent =
        `무기 ${foundWeapons}/${totalWeapons} | 아이템 ${foundItems}/${totalItems} | 적 ${foundEnemies}/${totalEnemies}`;
}

export { toggleCompendium, renderCompendium };
