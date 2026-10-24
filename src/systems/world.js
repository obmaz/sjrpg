import { MAP_HEIGHT, MAP_WIDTH, TILE_KEYS, TILE_TYPES } from '../core/constants.js';
import { VILLAGE, villageTile } from '../data/village.js';
import {
    chunkAppearance,
    chunkMask,
    CHUNK_SIZE,
    CHUNK_ORIGIN_X,
    CHUNK_ORIGIN_Y,
} from '../data/world-chunks.js';
import { session } from '../core/state.js';

function generateChunkMap(seed, region) {
    session.tileMap = Array.from({ length: MAP_HEIGHT }, () => Array(MAP_WIDTH));
    const firstColumn = Math.floor(-CHUNK_ORIGIN_X / CHUNK_SIZE),
        lastColumn = Math.floor((MAP_WIDTH * 32 - 1 - CHUNK_ORIGIN_X) / CHUNK_SIZE);
    const firstRow = Math.floor(-CHUNK_ORIGIN_Y / CHUNK_SIZE),
        lastRow = Math.floor((MAP_HEIGHT * 32 - 1 - CHUNK_ORIGIN_Y) / CHUNK_SIZE);
    for (let row = firstRow; row <= lastRow; row++)
        for (let column = firstColumn; column <= lastColumn; column++) {
            const appearance = chunkAppearance(seed, column, row, region),
                mask = chunkMask(appearance.variant, region);
            const startX = (CHUNK_ORIGIN_X + column * CHUNK_SIZE) / 32,
                startY = (CHUNK_ORIGIN_Y + row * CHUNK_SIZE) / 32;
            for (let localY = 0; localY < 20; localY++) {
                const y = startY + localY;
                if (y < 0 || y >= MAP_HEIGHT) continue;
                for (let localX = 0; localX < 20; localX++) {
                    const x = startX + localX;
                    if (x < 0 || x >= MAP_WIDTH) continue;
                    session.tileMap[y][x] =
                        mask[localY][appearance.mirrored ? 19 - localX : localX];
                }
            }
        }
    session.chunkSeed = seed;
    session.chunkRegion = region;
    session.chunkMap = session.tileMap;
    session.terrainRevision++;
}
function generateForestMap(seed) {
    generateChunkMap(seed, 'forest');
    // Ensure map connectivity - fill isolated walkable areas
    for (let y = 0; y < VILLAGE.height / 32; y++)
        for (let x = 0; x < VILLAGE.width / 32; x++)
            session.tileMap[VILLAGE.y / 32 + y][VILLAGE.x / 32 + x] = TILE_KEYS.indexOf(
                villageTile((x + 0.5) / (VILLAGE.width / 32), (y + 0.5) / (VILLAGE.height / 32)),
            );
    // Flood fill starts on the footpath below the fountain.
    ensureConnectivity('forest', Math.floor(MAP_HEIGHT / 2) + 5);
    session.terrainRevision++;
}

function ensureConnectivity(region = 'forest', arrivalRow = Math.floor(MAP_HEIGHT / 2)) {
    const visited = new Uint8Array(MAP_WIDTH * MAP_HEIGHT);
    const queue = [];
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = arrivalRow;
    queue.push(fcx, fcy);
    visited[fcy * MAP_WIDTH + fcx] = 1;

    const dirs = [
        [0, -1],
        [0, 1],
        [-1, 0],
        [1, 0],
    ];
    for (let head = 0; head < queue.length; head += 2) {
        const cx = queue[head];
        const cy = queue[head + 1];
        for (const [dx, dy] of dirs) {
            const nx = cx + dx,
                ny = cy + dy;
            if (nx < 0 || ny < 0 || nx >= MAP_WIDTH || ny >= MAP_HEIGHT) continue;
            if (visited[ny * MAP_WIDTH + nx]) continue;
            if (!isSolidTile(nx, ny)) {
                visited[ny * MAP_WIDTH + nx] = 1;
                queue.push(nx, ny);
            }
        }
    }

    let changed = false;
    // Closed woodland gaps become undergrowth; preserve real lakes and desert behaviour.
    for (let y = 0; y < MAP_HEIGHT; y++) {
        for (let x = 0; x < MAP_WIDTH; x++) {
            if (!visited[y * MAP_WIDTH + x] && !isSolidTile(x, y)) {
                let nearbyTrees = 0;
                if (region === 'forest')
                    for (let dy = -1; dy <= 1; dy++)
                        for (let dx = -1; dx <= 1; dx++)
                            if (TILE_KEYS[getTile(x + dx, y + dy)] === 'TREE') nearbyTrees++;
                session.tileMap[y][x] = TILE_KEYS.indexOf(nearbyTrees >= 2 ? 'BUSH' : 'WATER_DEEP');
                changed = true;
            }
        }
    }
    if (changed) session.terrainRevision++;
}

function getTile(x, y) {
    if (x < 0 || y < 0 || x >= MAP_WIDTH || y >= MAP_HEIGHT) return TILE_KEYS.indexOf('WATER_DEEP');
    return session.tileMap[y]?.[x] ?? TILE_KEYS.indexOf('WATER_DEEP');
}

function isSolidTile(x, y) {
    const idx = getTile(x, y);
    return TILE_TYPES[TILE_KEYS[idx]].solid;
}

function isWaterTile(x, y) {
    const tileKey = TILE_KEYS[getTile(x, y)];
    return tileKey === 'WATER' || tileKey === 'WATER_DEEP';
}

function generateDesertMap(seed) {
    generateChunkMap(seed, 'desert');
    ensureConnectivity('desert');
}

export {
    ensureConnectivity,
    generateForestMap,
    getTile,
    isSolidTile,
    isWaterTile,
    generateDesertMap,
};
