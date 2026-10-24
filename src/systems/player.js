import {
    canOccupyMountPosition,
    collidesWithEntities,
    collidesWithMap,
} from '../core/collision.js';
import { MAP_HEIGHT, MAP_WIDTH, TILE_SIZE } from '../core/constants.js';
import { getActorAngle, setActorFacing } from '../core/facing.js';
import { player, session } from '../core/state.js';
import { attackWithWeapon } from './combat.js';
import { isKeyDown, touchStick } from '../ui/input.js';
import { addMessage } from '../ui/messages.js';

function updatePlayer(deltaTime) {
    // Movement - blocked when inventory is open
    let dx = 0,
        dy = 0;
    if (!session.inventoryOpen) {
        if (isKeyDown('ArrowLeft') || isKeyDown('KeyA')) dx -= 1;
        if (isKeyDown('ArrowRight') || isKeyDown('KeyD')) dx += 1;
        if (isKeyDown('ArrowUp') || isKeyDown('KeyW')) dy -= 1;
        if (isKeyDown('ArrowDown') || isKeyDown('KeyS')) dy += 1;
    }

    if (touchStick.active && !session.inventoryOpen) {
        dx = touchStick.x;
        dy = touchStick.y;
    } else {
        const length = Math.hypot(dx, dy);
        if (length > 1) {
            dx /= length;
            dy /= length;
        }
    }
    const moving = dx !== 0 || dy !== 0;
    player.moving = moving;
    if (moving) setActorFacing(player, Math.atan2(dy, dx));
    if (player.mount) player.mount.moving = moving;
    if (moving && player.mount) {
        player.mount.dir = player.dir;
        setActorFacing(player.mount, getActorAngle(player));
        player.mount.animFrame = player.animFrame;
    }

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
    if (
        !session.inventoryOpen &&
        (isKeyDown('Space') || isKeyDown('KeyJ')) &&
        player.attackTimer <= 0
    ) {
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
