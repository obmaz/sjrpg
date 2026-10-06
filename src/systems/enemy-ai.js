'use strict';

function updateEnemies(deltaTime) {
    for (const enemy of enemies) {
        if (enemy.hp <= 0) continue;

        // Timers
        enemy.stateTimer -= deltaTime;
        enemy.attackCooldown -= deltaTime;
        if (enemy.hurtTimer > 0) enemy.hurtTimer -= deltaTime;
        if (enemy.frozen > 0) {
            enemy.frozen -= deltaTime;
            enemy.animTimer += deltaTime;
            continue; // frozen enemies can't act
        }

        const px = player.x + player.w / 2;
        const py = player.y + player.h / 2;
        const ex = enemy.x + enemy.w / 2;
        const ey = enemy.y + enemy.h / 2;
        const distanceToPlayer = distance(ex, ey, px, py);

        // State transitions
        if (enemy.state === 'hurt' && enemy.stateTimer <= 0) {
            enemy.state = 'chase';
        }

        const aggroRange = enemy.megaBoss ? 500 : enemy.isBoss ? 350 : 180;
        const meleeReach = enemy.megaBoss ? 40 : enemy.isBoss ? 20 : 16;
        const distanceToPlayerBody = distanceBetweenRectangles(enemy, player);
        const rangedRange = enemy.ranged ? 200 : 0;

        if (enemy.state === 'hurt') {
            // Preserve recoil until the recovery timer has expired.
        } else if (
            enemy.ranged &&
            distanceToPlayer < rangedRange &&
            distanceToPlayerBody > meleeReach
        ) {
            enemy.state = 'ranged';
        } else if (distanceToPlayerBody <= meleeReach) {
            enemy.state = 'attack';
        } else if (distanceToPlayer < aggroRange) {
            enemy.state = 'chase';
        } else {
            enemy.state = 'wander';
        }

        // Behavior
        let dx = 0,
            dy = 0;
        const speedPerFrame = enemy.speed * deltaTime;

        switch (enemy.state) {
            case 'wander':
                if (
                    enemy.stateTimer <= 0 ||
                    distance(ex, ey, enemy.wanderTarget.x, enemy.wanderTarget.y) < 10
                ) {
                    // Pick new wander target
                    const angle = Math.random() * Math.PI * 2;
                    const r = 50 + Math.random() * 120;
                    enemy.wanderTarget = {
                        x: ex + Math.cos(angle) * r,
                        y: ey + Math.sin(angle) * r,
                    };
                    enemy.stateTimer = 1.5 + Math.random() * 2;
                }
                dx = enemy.wanderTarget.x - ex;
                dy = enemy.wanderTarget.y - ey;
                break;

            case 'chase':
                dx = px - ex;
                dy = py - ey;
                break;

            case 'attack':
                dx = px - ex;
                dy = py - ey;
                if (enemy.attackCooldown <= 0) {
                    // Attack player
                    enemy.attackCooldown = enemy.isBoss ? 0.8 : 1.2;
                    if (player.invincible <= 0 && distanceToPlayerBody <= meleeReach) {
                        let dmg = enemy.atk + Math.floor(Math.random() * 4);
                        if (player.shieldActive > 0) dmg = Math.floor(dmg * 0.5);
                        player.hp -= dmg;
                        if (enemy.poison) applyPlayerPoison(SNAKE_POISON_DURATION, enemy.poisonDmg);
                        playPlayerHurtSound();
                        player.invincible = 0.5;
                        spawnFloatingText(
                            player.x + player.w / 2,
                            player.y - 8,
                            `-${dmg}${player.shieldActive > 0 ? '🛡️' : ''}`,
                            '#ff4444',
                        );
                        spawnParticles(
                            player.x + player.w / 2,
                            player.y + player.h / 2,
                            '#ff0000',
                            6,
                        );
                        addMessage(`${enemy.icon} ${enemy.name}의 공격! -${dmg}`, 'damage');
                        updateHud();
                    }
                }
                break;

            case 'hurt':
                // Briefly recoil
                dx = ex - px;
                dy = ey - py;
                break;

            case 'ranged':
                // Keep distance, shoot projectiles
                enemy.rangeAttackCd -= deltaTime;
                if (distanceToPlayer > rangedRange * 0.7) {
                    dx = px - ex;
                    dy = py - ey; // Move closer if too far
                } else if (distanceToPlayer < rangedRange * 0.3) {
                    dx = ex - px;
                    dy = ey - py; // Move away if too close
                } else {
                    dx = Math.random() - 0.5;
                    dy = Math.random() - 0.5; // Strafe
                }
                if (enemy.rangeAttackCd <= 0) {
                    enemy.rangeAttackCd = enemy.rangeCooldown || 1.8;
                    const projSpd = enemy.projSpeed || 250;
                    const pdx = px - ex,
                        pdy = py - ey;
                    const pmag = Math.sqrt(pdx * pdx + pdy * pdy) || 1;
                    spawnEnemyProjectile(
                        ex,
                        ey,
                        (pdx / pmag) * projSpd,
                        (pdy / pmag) * projSpd,
                        enemy.rangeDmg ?? enemy.atk,
                        enemy.color,
                    );
                }
                break;
        }

        // Normalize
        const magnitude = Math.sqrt(dx * dx + dy * dy);
        if (magnitude > 0) {
            dx = dx / magnitude;
            dy = dy / magnitude;
        }

        // Direction
        if (enemy.state !== 'hurt') {
            if (Math.abs(dy) > Math.abs(dx)) {
                enemy.dir = dy > 0 ? 0 : 2;
            } else {
                enemy.dir = dx > 0 ? 3 : 1;
            }
        }

        // Movement (with knockback)
        if (enemy.knockbackX || enemy.knockbackY) {
            const kbx = enemy.x + enemy.knockbackX * deltaTime * 4;
            const kby = enemy.y + enemy.knockbackY * deltaTime * 4;
            if (
                !collidesWithMap(kbx, enemy.y, enemy.w, enemy.h) &&
                !collidesWithEntities(kbx, enemy.y, enemy.w, enemy.h, enemy)
            )
                enemy.x = kbx;
            if (
                !collidesWithMap(enemy.x, kby, enemy.w, enemy.h) &&
                !collidesWithEntities(enemy.x, kby, enemy.w, enemy.h, enemy)
            )
                enemy.y = kby;
            const decay = Math.pow(0.85, deltaTime * 60);
            enemy.knockbackX *= decay;
            enemy.knockbackY *= decay;
            if (Math.abs(enemy.knockbackX) < 0.5) enemy.knockbackX = 0;
            if (Math.abs(enemy.knockbackY) < 0.5) enemy.knockbackY = 0;
        } else {
            const mx = enemy.x + dx * speedPerFrame;
            const my = enemy.y + dy * speedPerFrame;
            if (enemy.flying || enemy.megaBoss) {
                // Flying enemies ignore map collision
                if (!collidesWithEntities(mx, enemy.y, enemy.w, enemy.h, enemy)) enemy.x = mx;
                if (!collidesWithEntities(enemy.x, my, enemy.w, enemy.h, enemy)) enemy.y = my;
            } else {
                if (
                    !collidesWithMap(mx, enemy.y, enemy.w, enemy.h) &&
                    !collidesWithEntities(mx, enemy.y, enemy.w, enemy.h, enemy)
                )
                    enemy.x = mx;
                if (
                    !collidesWithMap(enemy.x, my, enemy.w, enemy.h) &&
                    !collidesWithEntities(enemy.x, my, enemy.w, enemy.h, enemy)
                )
                    enemy.y = my;
            }
        }

        // Clamp
        enemy.x = Math.max(0, Math.min(MAP_WIDTH * TILE_SIZE - enemy.w, enemy.x));
        enemy.y = Math.max(0, Math.min(MAP_HEIGHT * TILE_SIZE - enemy.h, enemy.y));

        // Boss: terrain destruction
        if (enemy.destroyTerrain && enemy.hp > 0) {
            const tileX = Math.floor(enemy.x / TILE_SIZE);
            const tileY = Math.floor(enemy.y / TILE_SIZE);
            for (let dy = -1; dy <= 1; dy++) {
                for (let dx = -1; dx <= 1; dx++) {
                    const tx = tileX + dx,
                        ty = tileY + dy;
                    if (tx >= 0 && ty >= 0 && tx < MAP_WIDTH && ty < MAP_HEIGHT) {
                        const tk = TILE_KEYS[getTile(tx, ty)];
                        if (tk === 'TREE' || tk === 'BUSH' || tk === 'ROCK' || tk === 'WALL') {
                            tileMap[ty][tx] = TILE_KEYS.indexOf('DIRT');
                        }
                    }
                }
            }
        }

        // Boss: minion spawn
        if (enemy.spawnMinions && enemy.hp > 0) {
            enemy.spawnTimer -= deltaTime;
            if (enemy.spawnTimer <= 0) {
                enemy.spawnTimer = enemy.spawnCooldown;
                for (let i = 0; i < enemy.spawnCount; i++) {
                    const sx = enemy.x + (Math.random() - 0.5) * enemy.w * 1.5;
                    const sy = enemy.y + (Math.random() - 0.5) * enemy.h * 1.5;
                    if (!isSolidTile(Math.floor(sx / TILE_SIZE), Math.floor(sy / TILE_SIZE))) {
                        spawnEnemy(ENEMY_TYPES[enemy.minionType], sx, sy);
                    }
                }
            }
        }

        // Animation
        enemy.animTimer += deltaTime;
    }
}
