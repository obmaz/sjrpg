import { MAP_HEIGHT, MAP_WIDTH, TILE_KEYS, TILE_TYPES } from '../core/constants.js';
import { VILLAGE, villageTile } from '../data/village.js';
import { createLandscape, landscapeTile } from '../data/landscape.js';
import { session } from '../core/state.js';

function generateLandscapeMap(seed, region) {
    const landscape = createLandscape(seed, region);
    session.tileMap = Array.from({ length: MAP_HEIGHT }, (_, y) =>
        Array.from({ length: MAP_WIDTH }, (_, x) =>
            TILE_KEYS.indexOf(landscapeTile(landscape, x * 32 + 16, y * 32 + 16) || 'DIRT'),
        ),
    );
    for (const prop of landscape.props)
        for (let dy = 0; dy < prop.h / 32; dy++)
            for (let dx = 0; dx < prop.w / 32; dx++) {
                const tx = prop.x / 32 + dx,
                    ty = prop.y / 32 + dy;
                if (tx >= 0 && ty >= 0 && tx < MAP_WIDTH && ty < MAP_HEIGHT)
                    session.tileMap[ty][tx] = TILE_KEYS.indexOf(
                        prop.key === 'tree' || prop.key === 'palm' ? 'TREE' : 'ROCK',
                    );
            }
    session.landscape = landscape;
    session.landscapeMap = session.tileMap;
    session.terrainRevision++;
}
function generateForestMap(seed) {
    generateLandscapeMap(seed, 'forest');
    // Keep the opening painting and its collision layout unchanged.
    for (let y = 0; y < VILLAGE.height / 32; y++)
        for (let x = 0; x < VILLAGE.width / 32; x++)
            session.tileMap[VILLAGE.y / 32 + y][VILLAGE.x / 32 + x] = TILE_KEYS.indexOf(
                villageTile((x + 0.5) / (VILLAGE.width / 32), (y + 0.5) / (VILLAGE.height / 32)),
            );
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
    generateLandscapeMap(seed, 'desert');
}

export {
    ensureConnectivity,
    generateForestMap,
    getTile,
    isSolidTile,
    isWaterTile,
    generateDesertMap,
};
