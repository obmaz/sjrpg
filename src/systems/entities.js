'use strict';

// ============================================================
//  PARTICLES
// ============================================================

function spawnParticles(x, y, color, count = 8) {
    for (let i = 0; i < count; i++) {
        const angle = Math.random() * Math.PI * 2;
        const speed = 60 + Math.random() * 140;
        const life = 0.4 + Math.random() * 0.4;
        particles.push({
            x,
            y,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life,
            maxLife: life,
            color,
            size: 2 + Math.random() * 3,
        });
    }
}

// ============================================================
//  PROJECTILES (for ranged weapons)
// ============================================================

function spawnProjectile(x, y, dir, speed, dmg, color, icon, sizeMult = 1) {
    let vx = 0,
        vy = 0;
    switch (dir) {
        case 0:
            vy = speed;
            break;
        case 1:
            vx = -speed;
            break;
        case 2:
            vy = -speed;
            break;
        case 3:
            vx = speed;
            break;
    }
    const baseSize = 6 * sizeMult;
    projectiles.push({ x, y, vx, vy, dmg, color, icon, life: 0.8, size: baseSize });
}

function spawnGoldPickup(x, y, amount = 0) {
    if (!amount) amount = 3 + Math.floor(Math.random() * 12);
    goldPickups.push({ x, y, amount, life: 60, bob: Math.random() * Math.PI * 2 });
}

function spawnWeaponPickup(x, y, weapon) {
    weaponPickups.push({
        x,
        y,
        weapon: { ...weapon },
        life: 120,
        bob: Math.random() * Math.PI * 2,
    });
}

function spawnChest(x, y, chestTypeId) {
    // Random chest type: wooden(65%), iron(15%), trap(10%), mimic(10%)
    const randomValue = Math.random();
    let chestKind = 'normal';
    let selectedChestTypeId = chestTypeId || 'wooden';
    if (!chestTypeId) {
        if (randomValue < 0.1) chestKind = 'trap';
        else if (randomValue < 0.2) chestKind = 'mimic';
        else if (randomValue < 0.35) selectedChestTypeId = 'iron';
    }
    const chestDefinition =
        CHEST_TYPES.find((chest) => chest.id === selectedChestTypeId) || CHEST_TYPES[0];
    const position = findNearbySpawnPosition(x, y, chestDefinition.w, chestDefinition.h);
    if (!position) return null;
    const chest = {
        ...position,
        w: chestDefinition.w,
        h: chestDefinition.h,
        hp: chestDefinition.hp,
        maxHp: chestDefinition.hp,
        type: chestKind,
        chestData: chestDefinition,
        opened: false,
    };
    chests.push(chest);
    return chest;
}

function spawnEnemyProjectile(x, y, vx, vy, dmg, color) {
    enemyProjectiles.push({ x, y, vx, vy, dmg, color, life: 2, size: 5 });
}

function spawnFireZone(x, y, duration, dmg, radius = 40) {
    fireZones.push({ x, y, duration, maxDuration: duration, dmg, radius, timer: 0 });
}

// ============================================================
//  FLOATING TEXT
// ============================================================

function spawnFloatingText(x, y, text, color = '#fff') {
    floatingTexts.push({ x, y, text, color, life: 1.0 });
}

function updateParticles(deltaTime) {
    for (let i = particles.length - 1; i >= 0; i--) {
        const projectile = particles[i];
        projectile.x += projectile.vx * deltaTime;
        projectile.y += projectile.vy * deltaTime;
        projectile.life -= deltaTime;
        if (projectile.life <= 0) particles.splice(i, 1);
    }
}

function updateProjectiles(deltaTime) {
    for (let i = projectiles.length - 1; i >= 0; i--) {
        const projectile = projectiles[i];
        const collision = advanceProjectile(projectile, deltaTime, enemies);
        if (collision) {
            if (collision.target) damageEnemy(collision.target, projectile.dmg);
            spawnParticles(projectile.x, projectile.y, projectile.color, collision.target ? 8 : 6);
        }
        if (collision || projectile.life <= 0) projectiles.splice(i, 1);
    }
}

function updateFireZones(deltaTime) {
    for (let i = fireZones.length - 1; i >= 0; i--) {
        const fireZone = fireZones[i];
        fireZone.duration -= deltaTime;
        fireZone.timer += deltaTime;

        // Damage enemies inside every 0.4s
        if (fireZone.timer >= 0.4) {
            fireZone.timer -= 0.4;
            for (const enemy of getEnemiesInRadius(fireZone.x, fireZone.y, fireZone.radius)) {
                damageEnemy(enemy, fireZone.dmg);
                spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ff4400', 5);
            }
        }

        // Spawn fire particles
        if (Math.random() < 0.3) {
            const a = Math.random() * Math.PI * 2;
            const randomValue = Math.random() * fireZone.radius;
            particles.push({
                x: fireZone.x + Math.cos(a) * randomValue,
                y: fireZone.y + Math.sin(a) * randomValue - 10,
                vx: (Math.random() - 0.5) * 20,
                vy: -40 - Math.random() * 60,
                life: 0.3 + Math.random() * 0.3,
                maxLife: 0.6,
                color: Math.random() > 0.5 ? '#ff6644' : '#ffaa00',
                size: 2 + Math.random() * 4,
            });
        }

        if (fireZone.duration <= 0) fireZones.splice(i, 1);
    }
}

function updateFloatingTexts(deltaTime) {
    for (let i = floatingTexts.length - 1; i >= 0; i--) {
        const floatingText = floatingTexts[i];
        floatingText.y -= 40 * deltaTime;
        floatingText.life -= deltaTime;
        if (floatingText.life <= 0) floatingTexts.splice(i, 1);
    }
}

function updateEnemyProjectiles(deltaTime) {
    for (let i = enemyProjectiles.length - 1; i >= 0; i--) {
        const projectile = enemyProjectiles[i];
        const targets = player.invincible <= 0 ? [player] : [];
        const collision = advanceProjectile(projectile, deltaTime, targets);
        if (collision?.target) {
            let dmg = projectile.dmg;
            if (player.shieldActive > 0) dmg = Math.floor(dmg * 0.5);
            player.hp -= dmg;
            player.invincible = 0.3;
            spawnFloatingText(player.x + player.w / 2, player.y - 8, `-${dmg}`, '#ff4444');
            spawnParticles(projectile.x, projectile.y, projectile.color, 6);
            updateHud();
        }
        if (collision || projectile.life <= 0) {
            enemyProjectiles.splice(i, 1);
        }
    }
}

function updateGoldPickups(deltaTime) {
    for (let i = goldPickups.length - 1; i >= 0; i--) {
        const goldPickup = goldPickups[i];
        goldPickup.life -= deltaTime;
        if (goldPickup.life <= 0) {
            goldPickups.splice(i, 1);
            continue;
        }
        const dist = distance(
            player.x + player.w / 2,
            player.y + player.h / 2,
            goldPickup.x,
            goldPickup.y,
        );
        if (dist < 30) {
            player.gold += goldPickup.amount;
            playCoinSound();
            spawnFloatingText(
                goldPickup.x,
                goldPickup.y - 10,
                `+${goldPickup.amount}💰`,
                '#ffd700',
            );
            goldPickups.splice(i, 1);
            updateHud();
        }
    }
    // Respawn gold on walkable tiles only (not water)
    if (goldPickups.length < 8 && Math.random() < deltaTime / 60) {
        const tile = findSpawnTile(
            3,
            (txi, tyi) => !isSolidTile(txi, tyi) && !isWaterTile(txi, tyi),
        );
        if (tile) {
            const { x: gx, y: gy } = tile;
            spawnGoldPickup(gx * TILE_SIZE + TILE_SIZE / 2, gy * TILE_SIZE + TILE_SIZE / 2, 20);
        }
    }
}

function updateWeaponPickups(deltaTime) {
    for (let i = weaponPickups.length - 1; i >= 0; i--) {
        const weaponPickup = weaponPickups[i];
        weaponPickup.life -= deltaTime;
        if (weaponPickup.life <= 0) {
            weaponPickups.splice(i, 1);
            continue;
        }
        const dist = distance(
            player.x + player.w / 2,
            player.y + player.h / 2,
            weaponPickup.x,
            weaponPickup.y,
        );
        if (dist < 28) {
            if (inventory.length >= INVENTORY_CAPACITY) {
                if (!weaponPickup.fullInventoryNotified) {
                    addMessage('🎒 인벤토리가 가득 찼습니다!', 'damage');
                    weaponPickup.fullInventoryNotified = true;
                }
                continue;
            }
            inventory.push({ ...weaponPickup.weapon });
            recordDiscovery('weapons', weaponPickup.weapon.id);
            addMessage(`🎁 ${weaponPickup.weapon.icon} ${weaponPickup.weapon.name} 획득!`, 'loot');
            playCoinSound();
            weaponPickups.splice(i, 1);
            updateHud();
        }
    }
}

function updateChests(deltaTime) {
    for (let i = chests.length - 1; i >= 0; i--) {
        const chest = chests[i];
        if (chest.opened) continue;
        // Player attack hits chest
        if (
            player.attackSerial &&
            chest.lastAttackSerial !== player.attackSerial &&
            player.attackTimer > player.lastAttackCooldown - 0.15
        ) {
            const origin = getPlayerAttackOrigin();
            const dist = distance(origin.x, origin.y, chest.x + chest.w / 2, chest.y + chest.h / 2);
            if (dist < 40) {
                chest.lastAttackSerial = player.attackSerial;
                chest.hp--;
                spawnParticles(chest.x + chest.w / 2, chest.y + chest.h / 2, '#aa8844', 5);
                if (chest.hp <= 0) {
                    chest.opened = true;
                    playChestBreak(chest.chestData && chest.chestData.id === 'iron');
                    openChest(chest);
                    chests.splice(i, 1);
                    if (player.hp <= 0) return;
                }
            }
        }
    }
}

function openChest(chest) {
    const cx = chest.x + chest.w / 2,
        cy = chest.y + chest.h / 2;
    if (chest.type === 'trap') {
        const dmg = chest.chestData.id === 'iron' ? 35 : 15;
        player.hp -= dmg;
        spawnParticles(cx, cy, '#ff4400', 25);
        addMessage(`💥 함정 상자! ${dmg} 피해!`, 'damage');
        updateHud();
    } else if (chest.type === 'mimic') {
        addMessage('👹 상자가 미믹이었다!', 'damage');
        const enemyType = chest.chestData.id === 'iron' ? ENEMY_TYPES[9] : ENEMY_TYPES[3];
        spawnEnemy(enemyType, chest.x, chest.y);
    } else {
        const cd = chest.chestData || CHEST_TYPES[0];
        const count = cd.dropCount || 1;
        // Direction away from player
        const pdx = cx - (player.x + player.w / 2);
        const pdy = cy - (player.y + player.h / 2);
        const pdist = Math.sqrt(pdx * pdx + pdy * pdy) || 1;
        const awayX = pdx / pdist;
        const awayY = pdy / pdist;

        for (let i = 0; i < count; i++) {
            const randomValue = Math.random();
            // Scatter position: away from player + random spread
            const spreadAngle = (Math.random() - 0.5) * Math.PI * 0.6; // ±54 degrees
            const cos = Math.cos(spreadAngle),
                sin = Math.sin(spreadAngle);
            const sx = awayX * cos - awayY * sin;
            const sy = awayX * sin + awayY * cos;
            const scatterDist = 30 + Math.random() * 50;
            let dropX = cx + sx * scatterDist;
            let dropY = cy + sy * scatterDist;
            // Ensure drop lands on walkable terrain (not solid, not water)
            const dtx = Math.floor(dropX / TILE_SIZE),
                dty = Math.floor(dropY / TILE_SIZE);
            if (isSolidTile(dtx, dty) || isWaterTile(dtx, dty)) {
                dropX = cx;
                dropY = cy;
            }

            if (randomValue < 0.35) {
                const [minG, maxG] = cd.dropGold;
                const amt = minG + Math.floor(Math.random() * (maxG - minG));
                spawnGoldPickup(dropX, dropY, amt);
                if (i === 0) addMessage(`📦 ${cd.name}에서 💰 ${amt}골드 획득!`, 'loot');
            } else if (randomValue < 0.7) {
                const pool = cd.dropWeapons;
                const wid =
                    pool[Math.floor(Math.random() * Math.min(pool.length, 1 + player.stage))];
                const weapon = WEAPONS.find((w) => w.id === wid);
                if (weapon) {
                    // Spawn as weapon pickup on ground
                    spawnWeaponPickup(dropX, dropY, weapon);
                    if (i === 0)
                        addMessage(`📦 ${cd.name}에서 ${weapon.icon} ${weapon.name} 등장!`, 'loot');
                }
            } else {
                const healAmt = cd.id === 'iron' ? 60 : 25;
                healPlayer(healAmt);
                if (i === 0) addMessage(`📦 ${cd.name}에서 💚 체력 회복!`, 'heal');
            }
            updateHud();
        }
    }
}
