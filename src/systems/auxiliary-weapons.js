import {
    canAct,
    deferGameAction,
    getEnemiesInRadius,
    healPlayer,
    isGameActive,
} from '../core/helpers.js';
import { enemies, particles, player, projectiles } from '../core/state.js';
import { damageEnemy, getFacingAngle, getPlayerAttackOrigin, offsetInDirection } from './combat.js';
import { spawnFireZone, spawnParticles, spawnProjectile } from './entities.js';
import { updateHud } from '../ui/hud.js';
import { addMessage } from '../ui/messages.js';

// ============================================================
//  AUXILIARY WEAPON
// ============================================================
function cycleAuxWeapon() {
    if (!canAct()) return;
    if (player.auxWeapons.length <= 1) return;
    const curIdx = player.auxWeapons.indexOf(player.auxWeapon);
    const nextIdx = (curIdx + 1) % player.auxWeapons.length;
    player.auxWeapon = player.auxWeapons[nextIdx];
    addMessage(`🔄 ${player.auxWeapon.icon} ${player.auxWeapon.name} 장착`, 'info');
    updateHud();
}

function useAuxWeapon() {
    if (!canAct() || !player.auxWeapon || player.auxCooldown > 0) return;

    const auxiliaryWeapon = player.auxWeapon;

    // Check uses for limited weapons
    if (auxiliaryWeapon.uses > 0) {
        auxiliaryWeapon.uses--;
    }
    if (auxiliaryWeapon.cooldown) {
        player.auxCooldown = auxiliaryWeapon.cooldown;
    }

    const origin = getPlayerAttackOrigin();

    switch (auxiliaryWeapon.ability) {
        case 'aoe_fire':
            useFireBomb(auxiliaryWeapon, origin);
            break;
        case 'freeze':
            useIceBomb(auxiliaryWeapon, origin);
            break;
        case 'lightning':
            useLightning(auxiliaryWeapon, origin);
            break;
        case 'poison_zone':
            usePoisonZone(auxiliaryWeapon, origin);
            break;
        case 'heal':
            useHealingAuxiliary(auxiliaryWeapon);
            break;
        case 'taunt':
            useTaunt(auxiliaryWeapon);
            break;
        case 'boomerang':
            throwBoomerang(auxiliaryWeapon, origin);
            break;
        case 'shuriken':
            throwShuriken(auxiliaryWeapon, origin);
            break;
        case 'shield':
            activateShield(auxiliaryWeapon);
            break;
        case 'trap':
            placeTrap(auxiliaryWeapon, origin);
            break;
    }

    updateHud();

    // Remove if out of uses
    if (auxiliaryWeapon.uses === 0) {
        addMessage(`${auxiliaryWeapon.icon} ${auxiliaryWeapon.name} 모두 사용!`, 'info');
        const idx = player.auxWeapons.indexOf(auxiliaryWeapon);
        if (idx >= 0) player.auxWeapons.splice(idx, 1);
        player.auxWeapon = player.auxWeapons.length > 0 ? player.auxWeapons[0] : null;
        updateHud();
    }
}

function useFireBomb(auxiliaryWeapon, origin) {
    const radius = auxiliaryWeapon.range || 80;
    for (let i = 0; i < 30; i++) {
        const a = Math.random() * Math.PI * 2;
        const dist = Math.random() * radius;
        particles.push({
            x: origin.x + Math.cos(a) * dist,
            y: origin.y + Math.sin(a) * dist,
            vx: Math.cos(a) * 300,
            vy: Math.sin(a) * 300 - 20,
            life: 0.3 + Math.random() * 0.4,
            maxLife: 0.7,
            color: Math.random() > 0.5 ? '#ff4400' : '#ffaa00',
            size: 3 + Math.random() * 5,
        });
    }
    spawnFireZone(origin.x, origin.y, 1.5, 10, radius * 0.7);
    for (const enemy of getEnemiesInRadius(origin.x, origin.y, radius)) {
        damageEnemy(enemy, auxiliaryWeapon.dmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ff4400', 10);
    }
    addMessage(`🧨 ${auxiliaryWeapon.name} 폭발!`, 'damage');
}

function useIceBomb(auxiliaryWeapon, origin) {
    const radius = auxiliaryWeapon.range || 70;
    for (let i = 0; i < 20; i++) {
        const a = Math.random() * Math.PI * 2;
        const dist = Math.random() * radius;
        particles.push({
            x: origin.x + Math.cos(a) * dist,
            y: origin.y + Math.sin(a) * dist,
            vx: (Math.random() - 0.5) * 60,
            vy: (Math.random() - 0.5) * 60,
            life: 0.5,
            maxLife: 0.5,
            color: '#aaddff',
            size: 3 + Math.random() * 4,
        });
    }
    for (const enemy of getEnemiesInRadius(origin.x, origin.y, radius)) {
        enemy.frozen = auxiliaryWeapon.freezeTime;
        damageEnemy(enemy, auxiliaryWeapon.dmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#88ccff', 8);
    }
    addMessage(`❄️ 주변 적 얼림!`, 'info');
}

function useLightning(auxiliaryWeapon, origin) {
    let hit = false;
    // Straight line in facing direction
    const radius = auxiliaryWeapon.range || 90;
    for (let i = 0; i < 12; i++) {
        let lx = origin.x,
            ly = origin.y;
        switch (player.dir) {
            case 0:
                ly += (i / 12) * radius;
                break;
            case 1:
                lx -= (i / 12) * radius;
                break;
            case 2:
                ly -= (i / 12) * radius;
                break;
            case 3:
                lx += (i / 12) * radius;
                break;
        }
        particles.push({
            x: lx + (Math.random() - 0.5) * 16,
            y: ly + (Math.random() - 0.5) * 16,
            vx: (Math.random() - 0.5) * 60,
            vy: (Math.random() - 0.5) * 60,
            life: 0.2,
            maxLife: 0.2,
            color: '#ffff44',
            size: 2 + Math.random() * 3,
        });
    }
    const vertical = player.dir === 0 || player.dir === 2;
    for (const enemy of getEnemiesInRadius(origin.x, origin.y, radius + 30)) {
        // Hit if the enemy is along the lightning line (in front, within width)
        const ex = enemy.x + enemy.w / 2,
            ey = enemy.y + enemy.h / 2;
        const dx = ex - origin.x,
            dy = ey - origin.y;
        let along = 0;
        switch (player.dir) {
            case 0:
                along = dy;
                break;
            case 1:
                along = -dx;
                break;
            case 2:
                along = -dy;
                break;
            case 3:
                along = dx;
                break;
        }
        const perp = Math.abs(vertical ? dx : dy);
        if (along > 0 && along < radius && perp < 30) {
            damageEnemy(enemy, auxiliaryWeapon.dmg, true);
            spawnParticles(ex, ey, '#ffff44', 15);
            hit = true;
        }
    }
    if (hit) addMessage(`⚡ ${auxiliaryWeapon.name} 강타!`, 'damage');
}

function usePoisonZone(auxiliaryWeapon, origin) {
    spawnFireZone(
        origin.x,
        origin.y,
        auxiliaryWeapon.duration,
        auxiliaryWeapon.dmg,
        auxiliaryWeapon.range,
    );
    for (let i = 0; i < 15; i++) {
        const a = Math.random() * Math.PI * 2;
        particles.push({
            x: origin.x + Math.cos(a) * auxiliaryWeapon.range * 0.5,
            y: origin.y + Math.sin(a) * auxiliaryWeapon.range * 0.5,
            vx: (Math.random() - 0.5) * 40,
            vy: (Math.random() - 0.5) * 40 - 10,
            life: 0.8,
            maxLife: 0.8,
            color: '#88ff44',
            size: 2 + Math.random() * 3,
        });
    }
    addMessage(`☠️ 독 안개 살포!`, 'damage');
}

function useHealingAuxiliary(auxiliaryWeapon) {
    const healAmt = auxiliaryWeapon.healAmount;
    healPlayer(healAmt);
    for (let i = 0; i < 12; i++) {
        particles.push({
            x: player.x + player.w / 2 + (Math.random() - 0.5) * 20,
            y: player.y - 5,
            vx: (Math.random() - 0.5) * 30,
            vy: -30 - Math.random() * 50,
            life: 0.5 + Math.random() * 0.3,
            maxLife: 0.8,
            color: '#66ff66',
            size: 3 + Math.random() * 4,
        });
    }
    addMessage(`🧪 +${healAmt} HP 회복!`, 'heal');
}

function useTaunt(auxiliaryWeapon) {
    for (const enemy of enemies) {
        if (enemy.hp <= 0) continue;
        enemy.frozen = auxiliaryWeapon.stunTime;
        enemy.state = 'chase';
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ffff00', 8);
    }
    addMessage(`🥁 모든 적 도발 + 스턴!`, 'info');
}

function throwBoomerang(auxiliaryWeapon, origin) {
    const throwDir = player.dir;
    spawnProjectile(origin.x, origin.y, throwDir, 320, auxiliaryWeapon.dmg, '#aaccff', '🪃');
    // Boomerang returns after a delay
    deferGameAction(0.35, () => {
        if (!isGameActive()) return;
        const rOrigin = getPlayerAttackOrigin();
        const revDir = (throwDir + 2) % 4;
        spawnProjectile(rOrigin.x, rOrigin.y, revDir, 280, auxiliaryWeapon.dmg, '#aaccff', '🪃');
    });
    addMessage('🪃 부메랑 투척!', 'info');
}

function throwShuriken(auxiliaryWeapon, origin) {
    for (let i = -1; i <= 1; i++) {
        // 3-way spread around the facing angle
        const fAngle = getFacingAngle(player.dir) + i * 0.25;
        const spd = 300;
        projectiles.push({
            x: origin.x,
            y: origin.y,
            vx: Math.cos(fAngle) * spd,
            vy: Math.sin(fAngle) * spd,
            dmg: auxiliaryWeapon.dmg,
            color: '#ffcc88',
            icon: '🔸',
            life: 0.7,
            size: 5,
        });
    }
    addMessage('🔸 수리검 발사!', 'info');
}

function activateShield(auxiliaryWeapon) {
    player.shieldActive = auxiliaryWeapon.duration;
    for (let i = 0; i < 10; i++) {
        const a = (Math.PI * 2 * i) / 10;
        particles.push({
            x: player.x + player.w / 2 + Math.cos(a) * 20,
            y: player.y + player.h / 2 + Math.sin(a) * 20,
            vx: Math.cos(a) * 50,
            vy: Math.sin(a) * 50,
            life: 0.6,
            maxLife: 0.6,
            color: '#aaaaff',
            size: 3,
        });
    }
    addMessage(`🛡️ ${auxiliaryWeapon.duration}초간 방패 활성화!`, 'info');
}

function placeTrap(auxiliaryWeapon, origin) {
    // Spawn trap as a long-lived damage zone in front of the player
    const fz = offsetInDirection(player.x + player.w / 2, player.y + player.h / 2, player.dir, 30);
    spawnFireZone(fz.x, fz.y, 8, auxiliaryWeapon.dmg, 28);
    spawnParticles(fz.x, fz.y, '#aa8844', 8);
    addMessage('🪤 덫 설치!', 'info');
}

export { cycleAuxWeapon, useAuxWeapon, throwBoomerang };
