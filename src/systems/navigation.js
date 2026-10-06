import {
    MAP_WIDTH,
    MAP_HEIGHT,
    TILE_SIZE,
    FOUNTAIN_CENTER_X,
    FOUNTAIN_CENTER_Y,
} from '../core/constants.js';
import {
    collidesWithMap,
    rectanglesOverlap,
    distanceBetweenRectangles,
} from '../core/collision.js';
import { chests, player, session } from '../core/state.js';
import { findGridPath } from './pathfinding.js';

const arrivalReachability = new WeakMap();

export function isReachableFromArrival(x, y, width, height) {
    const body = { w: width, h: height };
    const point = (tx, ty) => ({
        x: (tx + 0.5) * TILE_SIZE - width / 2,
        y: (ty + 0.5) * TILE_SIZE - height / 2,
    });
    const signature = `${width}:${height}:${session.terrainRevision}:${chests
        .filter((chest) => !chest.opened)
        .map((chest) => `${chest.x},${chest.y},${chest.w},${chest.h}`)
        .join(';')}`;
    let mapCache = arrivalReachability.get(session.tileMap);
    if (!mapCache) {
        mapCache = new Map();
        arrivalReachability.set(session.tileMap, mapCache);
    }
    if (!mapCache.has(signature)) {
        const reached = new Uint8Array(MAP_WIDTH * MAP_HEIGHT);
        const walkable = new Int8Array(MAP_WIDTH * MAP_HEIGHT).fill(-1);
        const canVisit = (tx, ty) => {
            const key = ty * MAP_WIDTH + tx;
            if (walkable[key] === -1) {
                const position = point(tx, ty);
                walkable[key] = Number(canStand(body, position.x, position.y));
            }
            return walkable[key] === 1;
        };
        const sx = Math.floor(FOUNTAIN_CENTER_X / TILE_SIZE),
            sy = Math.floor(FOUNTAIN_CENTER_Y / TILE_SIZE);
        const queue = [];
        if (canVisit(sx, sy)) {
            reached[sy * MAP_WIDTH + sx] = 1;
            queue.push({ x: sx, y: sy });
        }
        for (let head = 0; head < queue.length; head++) {
            const current = queue[head];
            for (const [dx, dy] of [
                [0, -1],
                [1, 0],
                [0, 1],
                [-1, 0],
            ]) {
                const tx = current.x + dx,
                    ty = current.y + dy;
                if (
                    tx < 0 ||
                    ty < 0 ||
                    tx >= MAP_WIDTH ||
                    ty >= MAP_HEIGHT ||
                    reached[ty * MAP_WIDTH + tx] ||
                    !canVisit(tx, ty) ||
                    !canTraverseTerrain(body, point(current.x, current.y), point(tx, ty))
                )
                    continue;
                reached[ty * MAP_WIDTH + tx] = 1;
                queue.push({ x: tx, y: ty });
            }
        }
        // Keep only the current obstacle signature per body size.
        for (const key of mapCache.keys())
            if (key.startsWith(`${width}:${height}:`)) mapCache.delete(key);
        mapCache.set(signature, reached);
    }
    const reached = mapCache.get(signature);
    const tx = Math.floor((x + width / 2) / TILE_SIZE),
        ty = Math.floor((y + height / 2) / TILE_SIZE);
    for (let dy = -1; dy <= 1; dy++)
        for (let dx = -1; dx <= 1; dx++) {
            const ax = tx + dx,
                ay = ty + dy;
            if (
                ax >= 0 &&
                ay >= 0 &&
                ax < MAP_WIDTH &&
                ay < MAP_HEIGHT &&
                reached[ay * MAP_WIDTH + ax] &&
                canTraverseTerrain(body, point(ax, ay), { x, y })
            )
                return true;
        }
    return false;
}

function canStand(enemy, x, y) {
    return (
        x >= 0 &&
        y >= 0 &&
        x + enemy.w <= MAP_WIDTH * TILE_SIZE &&
        y + enemy.h <= MAP_HEIGHT * TILE_SIZE &&
        !collidesWithMap(x, y, enemy.w, enemy.h) &&
        !chests.some(
            (chest) =>
                !chest.opened &&
                rectanglesOverlap(x, y, enemy.w, enemy.h, chest.x, chest.y, chest.w, chest.h),
        )
    );
}

export function canTraverseTerrain(enemy, from, to) {
    // Swept body checks prevent squeezing through corners between clear nodes.
    const steps = Math.max(1, Math.ceil(Math.hypot(to.x - from.x, to.y - from.y) / 8));
    for (let step = 0; step <= steps; step++) {
        const fraction = step / steps;
        if (
            !canStand(
                enemy,
                from.x + (to.x - from.x) * fraction,
                from.y + (to.y - from.y) * fraction,
            )
        )
            return false;
    }
    return true;
}

export function getNavigationWaypoint(enemy, targetX, targetY, deltaTime, reach = 0) {
    const target = { x: targetX - enemy.w / 2, y: targetY - enemy.h / 2 };
    const from = { x: enemy.x, y: enemy.y };
    if (canTraverseTerrain(enemy, from, target)) {
        enemy.navigation = null;
        return target;
    }
    const goalX = Math.floor(targetX / TILE_SIZE),
        goalY = Math.floor(targetY / TILE_SIZE);
    const point = (x, y) => ({
        x: (x + 0.5) * TILE_SIZE - enemy.w / 2,
        y: (y + 0.5) * TILE_SIZE - enemy.h / 2,
    });
    let route = enemy.navigation;
    if (route) route.remaining -= deltaTime;
    if (
        !route ||
        route.remaining <= 0 ||
        route.goalX !== goalX ||
        route.goalY !== goalY ||
        route.map !== session.tileMap ||
        (route.points.length && !canTraverseTerrain(enemy, from, route.points[0]))
    ) {
        // Snap only to an anchor that the entire body can actually reach.
        const sx = Math.floor((enemy.x + enemy.w / 2) / TILE_SIZE),
            sy = Math.floor((enemy.y + enemy.h / 2) / TILE_SIZE);
        const candidates = [];
        for (let dy = -1; dy <= 1; dy++)
            for (let dx = -1; dx <= 1; dx++) {
                const x = sx + dx,
                    y = sy + dy,
                    position = point(x, y);
                if (
                    x >= 0 &&
                    y >= 0 &&
                    x < MAP_WIDTH &&
                    y < MAP_HEIGHT &&
                    canTraverseTerrain(enemy, from, position)
                )
                    candidates.push({
                        x,
                        y,
                        distance: Math.hypot(position.x - enemy.x, position.y - enemy.y),
                    });
            }
        candidates.sort((a, b) => a.distance - b.distance);
        const walkable = new Map();
        const isWalkable = (x, y) => {
            const key = y * MAP_WIDTH + x;
            if (!walkable.has(key)) {
                const position = point(x, y);
                walkable.set(key, canStand(enemy, position.x, position.y));
            }
            return walkable.get(key);
        };
        const goalBody = reach > 0 ? player : { x: targetX, y: targetY, w: 0, h: 0 };
        const gap = (x, y) =>
            distanceBetweenRectangles({ ...point(x, y), w: enemy.w, h: enemy.h }, goalBody);
        const start = candidates[0];
        const path = start
            ? findGridPath(start, {
                  width: MAP_WIDTH,
                  height: MAP_HEIGHT,
                  isWalkable,
                  canStep: (ax, ay, bx, by) =>
                      canTraverseTerrain(enemy, point(ax, ay), point(bx, by)),
                  isGoal: (x, y) => (reach > 0 ? gap(x, y) <= reach : x === goalX && y === goalY),
                  heuristic: (x, y) => Math.max(0, gap(x, y) - reach) / TILE_SIZE,
              })
            : null;
        const points = path ? path.map((node) => point(node.x, node.y)) : [];
        // Avoid walking back to the start anchor on every replan (especially
        // for slow enemies that take more than 0.5 seconds to cross a tile).
        if (path && (!points.length || !canTraverseTerrain(enemy, from, points[0])))
            points.unshift(point(start.x, start.y));
        route = enemy.navigation = { goalX, goalY, map: session.tileMap, remaining: 0.5, points };
    }
    while (
        route.points.length &&
        Math.hypot(route.points[0].x - enemy.x, route.points[0].y - enemy.y) < 2
    )
        route.points.shift();
    return route.points[0] || null;
}
