'use strict';

// ============================================================
//  COLLISION
// ============================================================
function collidesWithMap(x, y, w, h) {
    return collidesWithTiles(x, y, w, h, isSolidTile);
}

function collidesWithTiles(x, y, w, h, isBlocked) {
    const margin = 4;
    const left = Math.floor((x + margin) / TILE_SIZE);
    const right = Math.floor((x + w - margin) / TILE_SIZE);
    const top = Math.floor((y + margin) / TILE_SIZE);
    const bottom = Math.floor((y + h - margin) / TILE_SIZE);
    for (let ty = top; ty <= bottom; ty++) {
        for (let tx = left; tx <= right; tx++) {
            if (isBlocked(tx, ty)) return true;
        }
    }
    return false;
}

function canOccupyMountPosition(mount, x, y) {
    if (
        x < 0 ||
        y < 0 ||
        x + mount.w > MAP_WIDTH * TILE_SIZE ||
        y + mount.h > MAP_HEIGHT * TILE_SIZE
    )
        return false;
    const blockedByTerrain = mount.waterOnly
        ? collidesWithTiles(x, y, mount.w, mount.h, (tx, ty) => !isWaterTile(tx, ty))
        : collidesWithMap(x, y, mount.w, mount.h);
    return !blockedByTerrain && !collidesWithEntities(x, y, mount.w, mount.h, player);
}

function distanceBetweenRectangles(first, second) {
    const dx = Math.max(first.x - second.x - second.w, second.x - first.x - first.w, 0);
    const dy = Math.max(first.y - second.y - second.h, second.y - first.y - first.h, 0);
    return Math.hypot(dx, dy);
}

// Return the first intersection along a segment, as a fraction from 0 to 1.
function getSegmentRectangleHitTime(startX, startY, endX, endY, rectangle, padding = 0) {
    let entryTime = 0;
    let exitTime = 1;
    const axes = [
        [startX, endX - startX, rectangle.x - padding, rectangle.x + rectangle.w + padding],
        [startY, endY - startY, rectangle.y - padding, rectangle.y + rectangle.h + padding],
    ];
    for (const [start, delta, minimum, maximum] of axes) {
        if (delta === 0) {
            if (start < minimum || start > maximum) return null;
            continue;
        }
        const first = (minimum - start) / delta;
        const second = (maximum - start) / delta;
        entryTime = Math.max(entryTime, Math.min(first, second));
        exitTime = Math.min(exitTime, Math.max(first, second));
        if (entryTime > exitTime) return null;
    }
    return entryTime;
}

function advanceProjectile(projectile, deltaTime, targets) {
    if (projectile.life <= 0) return null;
    const flightTime = Math.min(deltaTime, projectile.life);
    const startX = projectile.x;
    const startY = projectile.y;
    const endX = startX + projectile.vx * flightTime;
    const endY = startY + projectile.vy * flightTime;
    let collision = null;
    const left = Math.floor((Math.min(startX, endX) - projectile.size) / TILE_SIZE);
    const right = Math.floor((Math.max(startX, endX) + projectile.size) / TILE_SIZE);
    const top = Math.floor((Math.min(startY, endY) - projectile.size) / TILE_SIZE);
    const bottom = Math.floor((Math.max(startY, endY) + projectile.size) / TILE_SIZE);
    for (let ty = top; ty <= bottom; ty++) {
        for (let tx = left; tx <= right; tx++) {
            if (!isSolidTile(tx, ty)) continue;
            const tile = { x: tx * TILE_SIZE, y: ty * TILE_SIZE, w: TILE_SIZE, h: TILE_SIZE };
            const time = getSegmentRectangleHitTime(
                startX,
                startY,
                endX,
                endY,
                tile,
                projectile.size,
            );
            if (time !== null && (!collision || time < collision.time)) {
                collision = { time, target: null };
            }
        }
    }
    for (const target of targets) {
        if (target.hp <= 0) continue;
        const time = getSegmentRectangleHitTime(
            startX,
            startY,
            endX,
            endY,
            target,
            projectile.size,
        );
        // Terrain wins ties so an entity cannot be hit through a wall.
        if (time !== null && (!collision || time < collision.time)) {
            collision = { time, target };
        }
    }
    const time = collision?.time ?? 1;
    projectile.x = startX + (endX - startX) * time;
    projectile.y = startY + (endY - startY) * time;
    projectile.life -= deltaTime;
    return collision;
}

function collidesWithEntities(x, y, w, h, self) {
    if (self !== player) {
        if (rectanglesOverlap(x, y, w, h, player.x, player.y, player.w, player.h)) return true;
    }
    for (const e of enemies) {
        if (e === self || e.hp <= 0) continue;
        if (rectanglesOverlap(x, y, w, h, e.x, e.y, e.w, e.h)) return true;
    }
    // Chest collision
    for (const c of chests) {
        if (c.opened) continue;
        if (rectanglesOverlap(x, y, w, h, c.x, c.y, c.w, c.h)) return true;
    }
    return false;
}

function rectanglesOverlap(x1, y1, w1, h1, x2, y2, w2, h2) {
    return x1 < x2 + w2 && x1 + w1 > x2 && y1 < y2 + h2 && y1 + h1 > y2;
}
