import { FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y, TILE_KEYS } from '../core/constants.js';
const CHUNK_SIZE = 640;
const CHUNK_ORIGIN_X = FOUNTAIN_CENTER_X - 1600;
const CHUNK_ORIGIN_Y = FOUNTAIN_CENTER_Y - 896;
function chunkHash(seed, column, row) {
    let hash =
        Math.imul((seed | 0) ^ Math.imul(column + 17, 73856093), 19349663) ^
        Math.imul(row + 29, 83492791);
    hash = Math.imul(hash ^ (hash >>> 16), 2246822519);
    return hash >>> 0;
}
function chunkVariant(seed, column, row) {
    return chunkHash(seed, column, row) % 8;
}
function chunkAppearance(seed, column, row, region = null) {
    if (region === 'desert' && column === 2 && row === 1)
        return { variant: 0, mirrored: false, light: 0 };
    const hash = chunkHash(seed, column, row);
    return { variant: hash % 8, mirrored: !!(hash & 32), light: (hash >>> 8) % 3 };
}
function chunkCoordinates(x, y) {
    const column = Math.floor((x - CHUNK_ORIGIN_X) / CHUNK_SIZE),
        row = Math.floor((y - CHUNK_ORIGIN_Y) / CHUNK_SIZE);
    return {
        column,
        row,
        u: (x - CHUNK_ORIGIN_X - column * CHUNK_SIZE) / CHUNK_SIZE,
        v: (y - CHUNK_ORIGIN_Y - row * CHUNK_SIZE) / CHUNK_SIZE,
    };
}
function distanceToTrail(u, v, points) {
    let best = Infinity;
    for (let i = 1; i < points.length; i++) {
        const [x, y] = points[i - 1],
            [endX, endY] = points[i],
            dx = endX - x,
            dy = endY - y;
        const t = Math.max(0, Math.min(1, ((u - x) * dx + (v - y) * dy) / (dx * dx + dy * dy)));
        best = Math.min(best, Math.hypot(u - x - t * dx, v - y - t * dy));
    }
    return best;
}
const WINDING = [
    [
        [0.5, 0],
        [0.5, 0.1],
        [0.37, 0.2],
        [0.35, 0.3],
        [0.56, 0.4],
        [0.61, 0.5],
        [0.5, 0.6],
        [0.38, 0.7],
        [0.39, 0.8],
        [0.5, 0.9],
        [0.5, 1],
    ],
    [
        [0, 0.5],
        [0.17, 0.45],
        [0.35, 0.36],
    ],
    [
        [1, 0.5],
        [0.82, 0.42],
        [0.61, 0.5],
    ],
];
const COURTYARD = [
    [
        [0.5, 0],
        [0.33, 0.18],
        [0.24, 0.4],
        [0.27, 0.55],
        [0.4, 0.7],
        [0.5, 1],
    ],
    [
        [0, 0.5],
        [0.14, 0.52],
        [0.27, 0.55],
    ],
    [
        [1, 0.5],
        [0.74, 0.55],
        [0.6, 0.7],
        [0.4, 0.7],
    ],
];
function chunkTile(variant, u, v, region) {
    const ground = region === 'desert' ? 'SAND' : 'DIRT';
    if (variant === 4 && ((u - 0.365) / 0.18) ** 2 + ((v - 0.49) / 0.105) ** 2 < 1) return 'ROCK';
    if (variant === 4)
        return WINDING.some((path) => distanceToTrail(u, v, path) < 0.085)
            ? ground
            : region === 'forest'
              ? 'TREE'
              : 'ROCK';
    if (variant === 5) {
        const radius = Math.hypot((u - 0.5) / 0.34, (v - 0.48) / 0.29);
        if (radius < 0.58) return 'ROCK';
        return radius <= 1.3 || Math.abs(u - 0.5) < 0.13 || Math.abs(v - 0.5) < 0.13
            ? ground
            : region === 'forest'
              ? 'TREE'
              : 'ROCK';
    }
    if (variant === 6) {
        const bridge =
            distanceToTrail(u, v, [
                [0.76, 0.26],
                [0.24, 0.64],
            ]) < 0.06;
        const banks = [
            [
                [0.5, 0],
                [0.5, 0.13],
                [0.76, 0.26],
            ],
            [
                [0.24, 0.64],
                [0.48, 0.87],
                [0.5, 1],
            ],
            [
                [0, 0.5],
                [0.12, 0.54],
                [0.24, 0.64],
            ],
            [
                [1, 0.5],
                [0.84, 0.36],
                [0.76, 0.26],
            ],
        ];
        if (bridge || banks.some((path) => distanceToTrail(u, v, path) < 0.095)) return ground;
        if (Math.abs(v - u - 0.02) < 0.18) return 'WATER';
        return 'ROCK';
    }
    if (variant === 7)
        return Math.hypot(u - 0.73, v - 0.52) < 0.23 ||
            COURTYARD.some((path) => distanceToTrail(u, v, path) < 0.115)
            ? ground
            : region === 'forest'
              ? 'TREE'
              : 'ROCK';
    if (variant === 1 && ((u - 0.235) / 0.205) ** 2 + ((v - 0.235) / 0.205) ** 2 < 1)
        return 'WATER';
    const dx = Math.abs(u - 0.5),
        dy = Math.abs(v - 0.5);
    if (dx <= 0.14 || dy <= 0.14 || dx * dx + dy * dy < 0.26 * 0.26) return ground;
    return region === 'desert' || variant === 2 ? 'ROCK' : 'TREE';
}
const masks = new Map();
function chunkMask(variant, region) {
    const key = region + variant;
    if (!masks.has(key))
        masks.set(
            key,
            Array.from({ length: 20 }, (_, y) =>
                Array.from({ length: 20 }, (_, x) =>
                    TILE_KEYS.indexOf(chunkTile(variant, (x + 0.5) / 20, (y + 0.5) / 20, region)),
                ),
            ),
        );
    return masks.get(key);
}
export {
    CHUNK_SIZE,
    CHUNK_ORIGIN_X,
    CHUNK_ORIGIN_Y,
    chunkVariant,
    chunkAppearance,
    chunkCoordinates,
    chunkTile,
    chunkMask,
};
