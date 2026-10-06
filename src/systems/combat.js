'use strict';

function attackWithWeapon() {
    if (!canAct()) return;
    const weapon = player.weapon;
    const cooldown = weapon.cooldown || player.attackCooldown;
    player.attackTimer = cooldown;
    player.attackSerial = (player.attackSerial || 0) + 1;
    player.lastAttackCooldown = cooldown;
    playSlashSound();

    // Check scarecrow hits
    const origin = getPlayerAttackOrigin();
    const range = weapon.range || 36;
    for (const scarecrow of scarecrows) {
        const dist = distance(
            origin.x,
            origin.y,
            scarecrow.x + scarecrow.w / 2,
            scarecrow.y + scarecrow.h / 2,
        );
        if (dist < range + scarecrow.w / 2) {
            const dmg = weapon.atk + Math.floor(Math.random() * 3);
            hitScarecrow(scarecrow, dmg);
        }
    }

    const ability = weapon.ability || 'basic';

    // Combo tracking
    let comboBonus = 0;
    if (ability === 'combo' || ability === 'combo_wide' || ability === 'legend') {
        player.comboHits++;
        const comboMax = weapon.comboMax || 5;
        if (player.comboHits >= comboMax) {
            comboBonus = weapon.comboMult || 2;
            player.comboHits = 0;
            spawnFloatingText(player.x + player.w / 2, player.y - 30, '💥 COMBO!', '#ffd700');
            addMessage(`💥 ${comboMax}연속 타격! ${comboBonus}배 피해!`, 'loot');
        }
    }

    switch (ability) {
        case 'combo':
            meleeAttack(weapon, comboBonus);
            break;
        case 'wide':
            wideAttack(weapon, 0);
            break;
        case 'combo_wide':
            wideAttack(weapon, comboBonus);
            break;
        case 'ranged':
            rangedAttack(weapon);
            break;
        case 'fire':
            fireAttack(weapon);
            break;
        case 'legend':
            legendAttack(weapon, comboBonus);
            break;
        case 'push':
            pushAttack(weapon);
            break;
        case 'slam':
            slamAttack(weapon);
            break;
        default:
            meleeAttack(weapon, 0);
    }

    // Consume durability after resolving the attack, including the final use.
    if (weapon.uses !== undefined && weapon.uses > 0) {
        weapon.uses--;
        if (weapon.uses === 0) {
            addMessage(`💔 ${weapon.icon} ${weapon.name}이(가) 부서졌습니다!`, 'damage');
            player.weapon = WEAPONS[0];
            player.comboHits = 0;
            player.comboTimer = 0;
        }
        updateHud();
    }
}

function getPlayerAttackOrigin() {
    let ax = player.x + player.w / 2;
    let ay = player.y + player.h / 2;
    switch (player.dir) {
        case 0:
            ay += player.h / 2 + 6;
            break;
        case 1:
            ax -= player.w / 2 + 6;
            break;
        case 2:
            ay -= player.h / 2 + 6;
            break;
        case 3:
            ax += player.w / 2 + 6;
            break;
    }
    return { x: ax, y: ay };
}

// Move a point `dist` px along the player's facing direction (0=down,1=left,2=up,3=right)
function offsetInDirection(x, y, dir, dist) {
    switch (dir) {
        case 0:
            return { x, y: y + dist };
        case 1:
            return { x: x - dist, y };
        case 2:
            return { x, y: y - dist };
        case 3:
            return { x: x + dist, y };
        default:
            return { x, y };
    }
}

// dir: 0=down, 1=left, 2=up, 3=right → screen-space angle (0=right, π/2=down, π=left, -π/2=up)
function getFacingAngle(dir) {
    switch (dir) {
        case 0:
            return Math.PI / 2; // down
        case 1:
            return Math.PI; // left
        case 2:
            return -Math.PI / 2; // up
        case 3:
            return 0; // right
    }
}

function damageEnemy(enemy, dmg, knockback = true) {
    if (enemy.hp <= 0 || !enemies.includes(enemy)) return;
    enemy.hp -= dmg;
    player.damageDealt += dmg;
    playHitSound();
    enemy.hurtTimer = 0.25;
    enemy.state = 'hurt';
    enemy.stateTimer = 0.4;
    spawnFloatingText(enemy.x + enemy.w / 2, enemy.y - 8, `-${dmg}`, '#ff4444');
    // Knockback: push enemy away from player
    if (knockback) {
        const dx = enemy.x + enemy.w / 2 - (player.x + player.w / 2);
        const dy = enemy.y + enemy.h / 2 - (player.y + player.h / 2);
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const kbForce = 10 + dmg * 0.6;
        enemy.knockbackX = (dx / dist) * kbForce;
        enemy.knockbackY = (dy / dist) * kbForce;
    }
    // Reset combo decay timer on hit
    player.comboTimer = 0;
    if (enemy.hp <= 0) {
        killEnemy(enemy);
    }
}

function meleeAttack(weapon, comboBonus) {
    const origin = getPlayerAttackOrigin();
    const range = weapon.range || 36;
    spawnParticles(origin.x, origin.y, weapon.color, 16);
    // Extra slash trail particles
    const facing = getFacingAngle(player.dir);
    for (let i = 0; i < 6; i++) {
        const a = facing - 0.5 + Math.random();
        particles.push({
            x: origin.x + Math.cos(a) * 15,
            y: origin.y + Math.sin(a) * 15,
            vx: Math.cos(a) * (200 + Math.random() * 200),
            vy: Math.sin(a) * (200 + Math.random() * 200),
            life: 0.3,
            maxLife: 0.3,
            color: '#ffffff',
            size: 3 + Math.random() * 3,
        });
    }

    const baseDmg = weapon.atk + Math.floor(Math.random() * 3);
    const dmg = comboBonus > 0 ? Math.floor(baseDmg * comboBonus) : baseDmg;

    const targets = getEnemiesInRadius(origin.x, origin.y, range);
    for (const enemy of targets) {
        damageEnemy(enemy, dmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, weapon.color, 16);
    }
    if (targets.length === 0) {
        player.comboHits = 0;
        addMessage('헛스윙!', 'info');
    }
}

function wideAttack(weapon, comboBonus) {
    const origin = getPlayerAttackOrigin();
    const range = weapon.range || 48;
    const angle = weapon.wideAngle || 0.3;

    // Wide arc particle effect - more particles, bigger
    const facing = getFacingAngle(player.dir);
    for (let i = 0; i < 22; i++) {
        const a = facing - angle + (angle * 2 * i) / 21;
        const r = range * 0.45;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 300,
            vy: Math.sin(a) * 300,
            life: 0.45,
            maxLife: 0.45,
            color: weapon.color,
            size: 4 + Math.random() * 3,
        });
    }
    // Extra bright core slash
    for (let i = 0; i < 8; i++) {
        const a = facing - angle * 0.5 + (angle * i) / 7;
        const r = range * 0.2;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 400,
            vy: Math.sin(a) * 400,
            life: 0.25,
            maxLife: 0.25,
            color: '#ffffff',
            size: 3,
        });
    }

    const baseDmg = weapon.atk + Math.floor(Math.random() * 4);
    const dmg = comboBonus > 0 ? Math.floor(baseDmg * comboBonus) : baseDmg;

    let hit = false;
    for (const enemy of getEnemiesInRadius(origin.x, origin.y, range)) {
        const dx = enemy.x + enemy.w / 2 - origin.x;
        const dy = enemy.y + enemy.h / 2 - origin.y;
        const dist = distance(origin.x, origin.y, enemy.x + enemy.w / 2, enemy.y + enemy.h / 2);
        let angleDiff = Math.abs(Math.atan2(dy, dx) - facing);
        if (angleDiff > Math.PI) angleDiff = Math.PI * 2 - angleDiff;
        // Hit if inside the arc, or very close (point-blank)
        if (angleDiff < angle + 0.3 || dist < range * 0.5) {
            damageEnemy(enemy, dmg);
            spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, weapon.color, 6);
            hit = true;
        }
    }
    if (!hit) {
        player.comboHits = 0;
        addMessage('헛스윙!', 'info');
    }
}

function rangedAttack(weapon) {
    const origin = getPlayerAttackOrigin();
    const dmg = weapon.atk + Math.floor(Math.random() * 3);

    // Magic particles at origin - more intense
    spawnParticles(origin.x, origin.y, weapon.color, 22);
    // Ring effect - larger
    for (let i = 0; i < 12; i++) {
        const a = (Math.PI * 2 * i) / 12;
        particles.push({
            x: origin.x,
            y: origin.y,
            vx: Math.cos(a) * 100,
            vy: Math.sin(a) * 100,
            life: 0.4,
            maxLife: 0.4,
            color: weapon.color,
            size: 5 + Math.random() * 3,
        });
    }
    // Second inner ring
    for (let i = 0; i < 8; i++) {
        const a = (Math.PI * 2 * i) / 8 + 0.2;
        particles.push({
            x: origin.x,
            y: origin.y,
            vx: Math.cos(a) * 50,
            vy: Math.sin(a) * 50,
            life: 0.25,
            maxLife: 0.25,
            color: '#ffffff',
            size: 3,
        });
    }

    const sizeMult = weapon.projectileSize || 1;
    spawnProjectile(
        origin.x,
        origin.y,
        player.dir,
        weapon.projectileSpeed || 350,
        dmg,
        weapon.color,
        weapon.icon,
        sizeMult,
    );
}

function fireAttack(weapon) {
    const origin = getPlayerAttackOrigin();

    // Fire slash
    const baseDmg = weapon.atk + Math.floor(Math.random() * 3);
    const range = weapon.range || 42;

    // Fire particles - much more intense
    const facing = getFacingAngle(player.dir);
    for (let i = 0; i < 28; i++) {
        const a = facing - 0.6 + Math.random() * 1.2;
        const r = range * Math.random() * 0.8;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * (100 + Math.random() * 300),
            vy: Math.sin(a) * (100 + Math.random() * 300) - 40,
            life: 0.35 + Math.random() * 0.4,
            maxLife: 0.75,
            color: Math.random() > 0.5 ? '#ff4400' : '#ffaa00',
            size: 4 + Math.random() * 7,
        });
    }
    // Smoke/ember particles
    for (let i = 0; i < 10; i++) {
        particles.push({
            x: origin.x + (Math.random() - 0.5) * 30,
            y: origin.y + (Math.random() - 0.5) * 30,
            vx: (Math.random() - 0.5) * 60,
            vy: -60 - Math.random() * 80,
            life: 0.5 + Math.random() * 0.5,
            maxLife: 1.0,
            color: '#444444',
            size: 3 + Math.random() * 5,
        });
    }

    const targets = getEnemiesInRadius(origin.x, origin.y, range);
    for (const enemy of targets) {
        damageEnemy(enemy, baseDmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ff4400', 18);
    }

    // Create fire zone on ground in front
    const fz = offsetInDirection(player.x + player.w / 2, player.y + player.h / 2, player.dir, 50);
    spawnFireZone(fz.x, fz.y, weapon.fireDuration || 2, weapon.fireDmg || 4, 45);

    if (targets.length === 0) {
        player.comboHits = 0;
        addMessage('🔥 불꽃이 땅을 태웠다!', 'info');
    }
}

function legendAttack(weapon, comboBonus) {
    const origin = getPlayerAttackOrigin();
    const range = weapon.range || 60;

    // Golden explosion
    for (let i = 0; i < 40; i++) {
        const a = Math.random() * Math.PI * 2;
        const r = range * Math.random();
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 350,
            vy: Math.sin(a) * 350,
            life: 0.35 + Math.random() * 0.5,
            maxLife: 0.85,
            color: Math.random() > 0.25 ? '#ffd700' : '#ffffff',
            size: 4 + Math.random() * 8,
        });
    }
    // Inner bright flash
    for (let i = 0; i < 15; i++) {
        const a = Math.random() * Math.PI * 2;
        particles.push({
            x: origin.x + Math.cos(a) * 10,
            y: origin.y + Math.sin(a) * 10,
            vx: Math.cos(a) * 500,
            vy: Math.sin(a) * 500,
            life: 0.2,
            maxLife: 0.2,
            color: '#ffffff',
            size: 5,
        });
    }

    const baseDmg = weapon.atk + Math.floor(Math.random() * 5);
    const dmg = comboBonus > 0 ? Math.floor(baseDmg * comboBonus) : baseDmg;

    for (const enemy of getEnemiesInRadius(origin.x, origin.y, range)) {
        damageEnemy(enemy, dmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ffd700', 12);
    }

    // Fire zone
    spawnFireZone(origin.x, origin.y, weapon.fireDuration || 1.5, weapon.fireDmg || 6, 55);

    // Projectile
    spawnProjectile(
        origin.x,
        origin.y,
        player.dir,
        weapon.projectileSpeed || 400,
        Math.floor(baseDmg * 0.7),
        '#ffd700',
        '✨',
        weapon.projectileSize || 1,
    );
}

function pushAttack(weapon) {
    const origin = getPlayerAttackOrigin();
    const range = weapon.range || 100;
    const pushForce = weapon.pushForce || 350;
    const pushAngle = weapon.pushAngle || 0.6;
    const facing = getFacingAngle(player.dir);

    // Wind particle effect - more intense
    for (let i = 0; i < 35; i++) {
        const a = facing - pushAngle + Math.random() * pushAngle * 2;
        const r = range * Math.random() * 0.9;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 400,
            vy: Math.sin(a) * 400,
            life: 0.35 + Math.random() * 0.35,
            maxLife: 0.7,
            color: Math.random() > 0.4 ? '#aaddff' : '#ffffff',
            size: 3 + Math.random() * 6,
        });
    }

    // Arc wind lines - more visible
    for (let i = 0; i < 8; i++) {
        const a = facing - pushAngle + (pushAngle * 2 * i) / 7;
        const r = range * 0.35;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 600,
            vy: Math.sin(a) * 600,
            life: 0.2,
            maxLife: 0.2,
            color: '#ffffff',
            size: 3,
        });
    }

    let hit = false;
    for (const enemy of getEnemiesInRadius(origin.x, origin.y, range)) {
        const dx = enemy.x + enemy.w / 2 - origin.x;
        const dy = enemy.y + enemy.h / 2 - origin.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        let angleDiff = Math.abs(Math.atan2(dy, dx) - facing);
        if (angleDiff > Math.PI) angleDiff = Math.PI * 2 - angleDiff;
        if (angleDiff < pushAngle + 0.4 || dist < range * 0.4) {
            damageEnemy(enemy, weapon.atk + Math.floor(Math.random() * 3), false);
            // Strong knockback + brief stun
            enemy.knockbackX = (dx / dist) * pushForce;
            enemy.knockbackY = (dy / dist) * pushForce;
            enemy.frozen = 0.3;
            spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#aaddff', 6);
            hit = true;
        }
    }
    addMessage(hit ? `🌀 ${weapon.name} 강풍! 적 밀어냄!` : '🌀 바람이 허공을 갈랐다...', 'info');
}

function slamAttack(weapon) {
    const origin = getPlayerAttackOrigin();
    const range = weapon.range || 80;
    const dmg = (weapon.slamDmg || weapon.atk) + Math.floor(Math.random() * 4);

    // 360 ring shockwave - bigger and more intense
    for (let i = 0; i < 50; i++) {
        const a = (Math.PI * 2 * i) / 50;
        particles.push({
            x: origin.x,
            y: origin.y,
            vx: Math.cos(a) * (250 + Math.random() * 350),
            vy: Math.sin(a) * (250 + Math.random() * 350),
            life: 0.3 + Math.random() * 0.25,
            maxLife: 0.55,
            color: '#ddcc88',
            size: 4 + Math.random() * 7,
        });
    }
    // Inner bright ring
    for (let i = 0; i < 30; i++) {
        const a = (Math.PI * 2 * i) / 30;
        particles.push({
            x: origin.x,
            y: origin.y,
            vx: Math.cos(a) * 500,
            vy: Math.sin(a) * 500,
            life: 0.15,
            maxLife: 0.15,
            color: '#ffffff',
            size: 3,
        });
    }

    // Ground crack effect - more dramatic
    for (let i = 0; i < 20; i++) {
        const a = Math.random() * Math.PI * 2;
        const r = range * Math.random() * 0.9;
        particles.push({
            x: origin.x + Math.cos(a) * r * 0.4,
            y: origin.y + Math.sin(a) * r * 0.4,
            vx: Math.cos(a) * 100,
            vy: Math.sin(a) * 100,
            life: 0.6 + Math.random() * 0.4,
            maxLife: 1.0,
            color: '#887744',
            size: 4 + Math.random() * 6,
        });
    }

    const targets = getEnemiesInRadius(origin.x, origin.y, range);
    for (const enemy of targets) {
        enemy.frozen = Math.max(enemy.frozen || 0, 0.4); // brief stun
        damageEnemy(enemy, dmg, true);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ddcc88', 12);
    }
    addMessage(
        targets.length > 0 ? `🔨 ${weapon.name} 360도 강타!` : '🔨 땅이 울렸다!',
        targets.length > 0 ? 'damage' : 'info',
    );
}

function killEnemy(enemy) {
    if (!enemies.includes(enemy)) return;
    playEnemyDeathSound(enemy.name);
    spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, enemy.color, 25);
    spawnFloatingText(enemy.x + enemy.w / 2, enemy.y - 10, '처치!', '#ffd700');

    // Stage progression
    player.kills++;
    player.killsByName[enemy.name] = (player.killsByName[enemy.name] || 0) + 1;
    recordDiscovery('enemies', enemy.name);
    const newStage = 1 + Math.floor(player.kills / 5);
    if (newStage > player.stage) {
        const oldStage = player.stage;
        player.stage = newStage;
        addMessage(`⚡ Stage ${player.stage} 돌입! 적들이 강해집니다!`, 'loot');
        spawnMoreEnemies();
        // Full heal on stage up
        player.hp = player.maxHp;
        addMessage('💚 단계 상승! 체력 완전 회복!', 'heal');
        // Spawn stage-gated NPCs
        spawnStageNpcs(oldStage, newStage);
    }

    // Drop weapon
    if (Math.random() < enemy.dropRate && enemy.dropPool.length > 0) {
        const weaponId = enemy.dropPool[Math.floor(Math.random() * enemy.dropPool.length)];
        const weapon = WEAPONS.find((weapon) => weapon.id === weaponId);
        if (weapon && inventory.length < INVENTORY_CAPACITY) {
            inventory.push({ ...weapon });
            recordDiscovery('weapons', weapon.id);
            addMessage(`🎁 ${weapon.icon} ${weapon.name} 획득!`, 'loot');
            spawnFloatingText(
                enemy.x + enemy.w / 2,
                enemy.y - 30,
                `${weapon.icon} ${weapon.name}`,
                '#ffd700',
            );
        } else if (weapon) {
            spawnWeaponPickup(player.x + player.w / 2, player.y + player.h / 2, weapon);
            addMessage(`🎒 인벤토리가 가득 차 ${weapon.name}이(가) 발밑에 떨어졌습니다.`, 'loot');
        }
    }

    // Gold
    const goldDrop =
        enemy.gold ||
        (enemy.megaBoss ? 500 : enemy.isBoss ? 100 : 5 + Math.floor(Math.random() * 16));
    player.gold += goldDrop;
    spawnFloatingText(enemy.x + enemy.w / 2, enemy.y - 20, `+${goldDrop}💰`, '#ffd700');

    if (enemy.isBoss) {
        player.bossKills++;
        player.bossKillsByName[enemy.name] = (player.bossKillsByName[enemy.name] || 0) + 1;
        // Track boss kill for portal unlock
        player.bossKilled = true;
        // Check portal spawn condition
        checkPortalSpawn();
    }

    // Remove enemy
    const idx = enemies.indexOf(enemy);
    if (idx >= 0) enemies.splice(idx, 1);

    // Update UI
    updateHud();
}

// ============================================================
//  SCARECROW (허수아비) - training dummy
// ============================================================
function hitScarecrow(scarecrow, dmg) {
    scarecrow.hurtTimer = 0.25;
    scarecrow.animTimer = 0;
    spawnFloatingText(scarecrow.x + scarecrow.w / 2, scarecrow.y - 8, `-${dmg}`, '#ffaa44');
    spawnParticles(scarecrow.x + scarecrow.w / 2, scarecrow.y + scarecrow.h / 2, '#ddcc88', 8);
}
