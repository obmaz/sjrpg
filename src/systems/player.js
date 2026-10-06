import {
    canOccupyMountPosition,
    collidesWithEntities,
    collidesWithMap,
    rectanglesOverlap,
} from '../core/collision.js';
import { MAP_HEIGHT, MAP_WIDTH, TILE_SIZE } from '../core/constants.js';
import { mounts, player, session } from '../core/state.js';
import { attackWithWeapon } from './combat.js';
import { keys } from '../ui/input.js';
import { addMessage } from '../ui/messages.js';

function updatePlayer(deltaTime) {
    // Movement - blocked when inventory is open
    let dx = 0,
        dy = 0;
    if (!session.inventoryOpen) {
        if (keys.ArrowLeft || keys.KeyA) dx -= 1;
        if (keys.ArrowRight || keys.KeyD) dx += 1;
        if (keys.ArrowUp || keys.KeyW) dy -= 1;
        if (keys.ArrowDown || keys.KeyS) dy += 1;
    }

    // Normalize diagonal
    if (dx !== 0 && dy !== 0) {
        dx *= 0.707;
        dy *= 0.707;
    }

    // Direction
    if (dy > 0.3) player.dir = 0;
    else if (dx < -0.3) player.dir = 1;
    else if (dy < -0.3) player.dir = 2;
    else if (dx > 0.3) player.dir = 3;

    const moving = dx !== 0 || dy !== 0;

    // Speed boost timer
    if (player.speedBoost > 0) {
        player.speedBoost -= deltaTime;
        if (player.speedBoost <= 0) {
            player.speedBoost = 0;
            addMessage('⚡ 스피드 포션 효과가 끝났습니다.', 'info');
        }
    }

    // Collision resolution (separate axes)
    const mount = player.mount;
    const baseSpd = mount ? mount.speed : player.speed;
    const speedMult = player.speedBoost > 0 ? 1.5 : 1.0;
    const spd = baseSpd * speedMult * deltaTime;
    const pw = mount ? mount.w : player.w;
    const ph = mount ? mount.h : player.h;
    const newX = player.x + dx * spd;
    const newY = player.y + dy * spd;

    const canMove = (x, y) =>
        mount
            ? canOccupyMountPosition(mount, x, y)
            : !collidesWithMap(x, y, pw, ph) && !collidesWithEntities(x, y, pw, ph, player);
    if (canMove(newX, player.y)) {
        player.x = newX;
    }
    if (canMove(player.x, newY)) {
        player.y = newY;
    }

    // Auto-mount: check nearby mounts
    if (!mount) {
        for (const m of mounts) {
            if (
                rectanglesOverlap(
                    player.x,
                    player.y,
                    player.w,
                    player.h,
                    m.x - 5,
                    m.y - 5,
                    m.w + 10,
                    m.h + 10,
                ) &&
                canOccupyMountPosition(m, m.x, m.y)
            ) {
                player.mount = m;
                player.x = m.x;
                player.y = m.y;
                mounts.splice(mounts.indexOf(m), 1);
                addMessage(`🐎 ${m.icon} ${m.name}에 탑승! (U: 내리기)`, 'loot');
                break;
            }
        }
    }

    // Clamp to map
    player.x = Math.max(
        0,
        Math.min(MAP_WIDTH * TILE_SIZE - (player.mount ? player.mount.w : player.w), player.x),
    );
    player.y = Math.max(
        0,
        Math.min(MAP_HEIGHT * TILE_SIZE - (player.mount ? player.mount.h : player.h), player.y),
    );

    // Animation
    if (moving) {
        player.animTimer += deltaTime;
        if (player.animTimer > 0.15) {
            player.animTimer = 0;
            player.animFrame = (player.animFrame + 1) % 4;
        }
    } else {
        player.animFrame = 0;
        player.animTimer = 0;
    }

    // Attack - blocked when inventory is open
    player.attackTimer -= deltaTime;
    if (!session.inventoryOpen && (keys.Space || keys.KeyJ) && player.attackTimer <= 0) {
        attackWithWeapon();
    }

    // Combo decay timer
    if (player.comboHits > 0) {
        // combo decays after 2.5 seconds of no hits
        player.comboTimer = (player.comboTimer || 0) + deltaTime;
        if (player.comboTimer > 2.5) {
            player.comboHits = 0;
            player.comboTimer = 0;
        }
    }

    // Invincibility
    if (player.invincible > 0) player.invincible -= deltaTime;
    // Shield timer
    if (player.shieldActive > 0) player.shieldActive -= deltaTime;
    // Aux cooldown
    if (player.auxCooldown > 0) player.auxCooldown -= deltaTime;
}

export { updatePlayer };
