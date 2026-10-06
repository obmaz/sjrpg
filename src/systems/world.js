'use strict';

function generateForestMap(seed) {
    const noise = new SimpleNoise(seed);
    const moistureNoise = new SimpleNoise(seed + 9999);
    tileMap = [];

    for (let y = 0; y < MAP_HEIGHT; y++) {
        tileMap[y] = [];
        for (let x = 0; x < MAP_WIDTH; x++) {
            // Height: -1 to 1
            const h = noise.fbm(x * 0.03, y * 0.03, 5, 2.3, 0.55);
            // Moisture: -1 to 1
            const m = moistureNoise.fbm(x * 0.04, y * 0.04, 4, 2.1, 0.5);

            // Add some large-scale variation for continents
            const continent = noise.noise2D(x * 0.008, y * 0.008) * 0.6;

            const height = h + continent * 0.4;
            const moisture = m;

            let tile;
            if (height < -0.35) {
                tile = 'WATER_DEEP';
            } else if (height < -0.2) {
                tile = 'WATER';
            } else if (height < -0.08) {
                tile = 'SAND';
            } else if (height < -0.02) {
                tile = moisture > 0.1 ? 'GRASS_TALL' : 'GRASS';
            } else if (height < 0.15) {
                tile = moisture > 0.2 ? 'TREE' : moisture > 0 ? 'GRASS_TALL' : 'GRASS';
            } else if (height < 0.3) {
                tile = moisture > 0.15 ? 'TREE' : Math.random() < 0.3 ? 'BUSH' : 'ROCK';
            } else {
                tile = 'ROCK';
            }

            // Scatter flowers on grass
            if (
                (tile === 'GRASS' || tile === 'GRASS_TALL') &&
                Math.abs(noise.noise2D(x * 1.7, y * 1.7)) > 0.6
            ) {
                tile = 'FLOWER';
            }
            // Create paths between areas (Zelda-like dirt paths)
            if (tile === 'GRASS' || tile === 'GRASS_TALL') {
                const pathNoise = Math.abs(noise.noise2D(x * 0.06 + 50, y * 0.06 + 50));
                if (pathNoise < 0.08) tile = 'PATH';
            }

            tileMap[y][x] = TILE_KEYS.indexOf(tile);
        }
    }

    // Clear fountain area at center (make it larger plaza with village)
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    const plazaR = 7; // enlarged from 4
    for (let y = fcy - plazaR; y <= fcy + plazaR; y++) {
        for (let x = fcx - plazaR; x <= fcx + plazaR; x++) {
            if (y >= 0 && y < MAP_HEIGHT && x >= 0 && x < MAP_WIDTH) {
                const dist = Math.sqrt((x - fcx) ** 2 + (y - fcy) ** 2);
                if (dist < 6.5) {
                    tileMap[y][x] = TILE_KEYS.indexOf('SAND');
                } else if (dist < 7.5) {
                    tileMap[y][x] = TILE_KEYS.indexOf('DIRT');
                }
            }
        }
    }
    // Place fountain tile marker
    tileMap[fcy][fcx] = TILE_KEYS.indexOf('GRASS');

    // Add decorative walls around fountain plaza (larger ring)
    const wallR = 6;
    for (let y = fcy - wallR; y <= fcy + wallR; y++) {
        for (let x = fcx - wallR; x <= fcx + wallR; x++) {
            if (y < 0 || y >= MAP_HEIGHT || x < 0 || x >= MAP_WIDTH) continue;
            const dist = Math.sqrt((x - fcx) ** 2 + (y - fcy) ** 2);
            if (
                dist > 6.2 &&
                dist < 7.0 &&
                tileMap[y][x] !== TILE_KEYS.indexOf('WATER') &&
                tileMap[y][x] !== TILE_KEYS.indexOf('WATER_DEEP')
            ) {
                if (Math.abs(dist - 6.5) < 0.35 && (x + y) % 3 !== 0) {
                    tileMap[y][x] = TILE_KEYS.indexOf('WALL');
                }
            }
        }
    }

    // Clear village buildings around the plaza (wider ring)
    for (let y = fcy - 10; y <= fcy + 10; y++) {
        for (let x = fcx - 10; x <= fcx + 10; x++) {
            if (y < 0 || y >= MAP_HEIGHT || x < 0 || x >= MAP_WIDTH) continue;
            const dist = Math.sqrt((x - fcx) ** 2 + (y - fcy) ** 2);
            if (
                dist > 7.5 &&
                dist < 10.5 &&
                tileMap[y][x] !== TILE_KEYS.indexOf('WATER') &&
                tileMap[y][x] !== TILE_KEYS.indexOf('WATER_DEEP')
            ) {
                // Create village paths and clearings
                if ((x + y) % 4 === 0 || (x - y) % 4 === 0) {
                    tileMap[y][x] = TILE_KEYS.indexOf('PATH');
                }
            }
        }
    }

    // Ensure map connectivity - fill isolated walkable areas
    ensureConnectivity();
}

function ensureConnectivity() {
    const visited = new Uint8Array(MAP_WIDTH * MAP_HEIGHT);
    const queue = [];
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
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

    // Convert unreachable walkable tiles to deep water
    for (let y = 0; y < MAP_HEIGHT; y++) {
        for (let x = 0; x < MAP_WIDTH; x++) {
            if (!visited[y * MAP_WIDTH + x] && !isSolidTile(x, y)) {
                tileMap[y][x] = TILE_KEYS.indexOf('WATER_DEEP');
            }
        }
    }
}

function getTile(x, y) {
    if (x < 0 || y < 0 || x >= MAP_WIDTH || y >= MAP_HEIGHT) return TILE_KEYS.indexOf('WATER_DEEP');
    return tileMap[y]?.[x] ?? TILE_KEYS.indexOf('WATER_DEEP');
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
    const noise = new SimpleNoise(seed);
    tileMap = [];

    for (let y = 0; y < MAP_HEIGHT; y++) {
        tileMap[y] = [];
        for (let x = 0; x < MAP_WIDTH; x++) {
            const h = noise.fbm(x * 0.03, y * 0.03, 4, 2.2, 0.5);

            let tile;
            if (h < -0.25) {
                tile = 'SAND';
            } else if (h < -0.1) {
                tile = Math.random() < 0.3 ? 'ROCK' : 'SAND';
            } else if (h < 0.1) {
                tile = Math.random() < 0.15 ? 'ROCK' : 'SAND';
            } else if (h < 0.25) {
                tile = Math.random() < 0.5 ? 'ROCK' : 'SAND';
            } else {
                tile = 'ROCK';
            }

            // Add oasis near center
            const fcx = Math.floor(MAP_WIDTH / 2);
            const fcy = Math.floor(MAP_HEIGHT / 2);
            const dist = Math.sqrt((x - fcx) ** 2 + (y - fcy) ** 2);
            if (dist < 4) {
                tile = 'WATER';
            } else if (dist < 6) {
                tile = Math.random() < 0.5 ? 'GRASS' : 'SAND';
            } else if (dist < 8) {
                tile = Math.random() < 0.2 ? 'GRASS' : 'SAND';
            }

            // Scatter cacti (use BUSH)
            if (tile === 'SAND' && Math.random() < 0.03) {
                tile = 'BUSH';
            }

            tileMap[y][x] = TILE_KEYS.indexOf(tile);
        }
    }

    // Keep a dry arrival area and a path across the oasis before flood filling.
    // Starting the flood fill in water would erase every walkable desert tile.
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    for (let y = fcy - 1; y <= fcy + 1; y++) {
        for (let x = fcx - 1; x <= fcx + 8; x++) {
            tileMap[y][x] = TILE_KEYS.indexOf('PATH');
        }
    }
    ensureConnectivity();
}
