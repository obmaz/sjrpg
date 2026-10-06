'use strict';

function dismountPlayer() {
    if (!canAct() || !player.mount) return;
    const m = player.mount;
    const mountX = player.x,
        mountY = player.y;
    // Find a walkable tile near the mount
    let ox = player.x,
        oy = player.y;
    const searchOffsets = [
        [0, TILE_SIZE],
        [TILE_SIZE, 0],
        [-TILE_SIZE, 0],
        [0, -TILE_SIZE],
        [TILE_SIZE, TILE_SIZE],
        [-TILE_SIZE, TILE_SIZE],
        [TILE_SIZE, -TILE_SIZE],
        [-TILE_SIZE, -TILE_SIZE],
        [0, TILE_SIZE * 2],
        [TILE_SIZE * 2, 0],
        [-TILE_SIZE * 2, 0],
        [0, -TILE_SIZE * 2],
    ];
    let found = false;
    for (const [dx, dy] of searchOffsets) {
        const tx = player.x + dx,
            ty = player.y + dy;
        const ttx = Math.floor(tx / TILE_SIZE),
            tty = Math.floor(ty / TILE_SIZE);
        if (
            ttx >= 0 &&
            ttx < MAP_WIDTH &&
            tty >= 0 &&
            tty < MAP_HEIGHT &&
            !collidesWithMap(tx, ty, player.w, player.h) &&
            !collidesWithEntities(tx, ty, player.w, player.h, player) &&
            !rectanglesOverlap(
                tx,
                ty,
                player.w,
                player.h,
                mountX - 5,
                mountY - 5,
                m.w + 10,
                m.h + 10,
            )
        ) {
            // Both boats and land mounts must leave the player on walkable land.
            ox = tx;
            oy = ty;
            found = true;
            break;
        }
    }
    if (!found) {
        // Last resort: teleport to fountain (FOUNTAIN_CENTER_X/CY are already in pixels)
        ox = FOUNTAIN_CENTER_X;
        oy = FOUNTAIN_CENTER_Y;
        addMessage('⚠️ 내릴 곳이 없어 분수로 이동합니다.', 'info');
    }
    player.x = ox;
    player.y = oy;
    mounts.push({ ...m, x: mountX, y: mountY });
    player.mount = null;
    addMessage(`내렸습니다. ${m.icon} ${m.name}`, 'info');
    updateHud();
}

function spawnMount(mountType, x, y) {
    const mount = { ...mountType, x, y, w: MOUNT_WIDTH, h: MOUNT_HEIGHT };
    if (mount.waterOnly) {
        if (!canOccupyMountPosition(mount, x, y)) return null;
    } else {
        const position = findNearbySpawnPosition(x, y, mount.w, mount.h);
        if (!position) return null;
        Object.assign(mount, position);
    }
    mounts.push(mount);
    return mount;
}
