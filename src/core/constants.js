// ============================================================
//  TERRAIN GENERATION
// ============================================================
const TILE_SIZE = 32;
const MOUNT_WIDTH = TILE_SIZE * 1.5;
const MOUNT_HEIGHT = TILE_SIZE * 1.2;
const MAP_WIDTH = 80;
const MAP_HEIGHT = 60;
const FOUNTAIN_CENTER_X = (MAP_WIDTH / 2) * TILE_SIZE;
const FOUNTAIN_CENTER_Y = (MAP_HEIGHT / 2) * TILE_SIZE;

const TILE_TYPES = {
    WATER_DEEP: { char: '~', color: '#104878', name: '깊은 물', solid: true },
    WATER: { char: '≈', color: '#1868a0', name: '물', solid: true },
    SAND: { char: '·', color: '#d8c898', name: '모래', solid: false },
    GRASS: { char: '∴', color: '#609840', name: '풀밭', solid: false },
    GRASS_TALL: { char: '※', color: '#488030', name: '긴 풀', solid: false },
    DIRT: { char: '∴', color: '#b89060', name: '흙길', solid: false },
    ROCK: { char: '◆', color: '#788078', name: '바위', solid: true },
    TREE: { char: '♣', color: '#306828', name: '나무', solid: true },
    FLOWER: { char: '❀', color: '#d84068', name: '꽃', solid: false },
    BUSH: { char: '♠', color: '#408030', name: '덤불', solid: true },
    PATH: { char: '·', color: '#c8b070', name: '길', solid: false },
    WALL: { char: '▦', color: '#686868', name: '돌담', solid: true },
};

const TILE_KEYS = Object.keys(TILE_TYPES);

const INVENTORY_CAPACITY = 12;
const INVENTORY_COLUMNS = 4;
const CONSUMABLE_CAPACITY = 3;
const MAX_FRAME_DELTA = 0.1;
const GAME_DURATION_SECONDS = 600;
const POISON_TICK_INTERVAL = 10;
const SNAKE_POISON_DURATION = 30;

export {
    TILE_SIZE,
    MOUNT_WIDTH,
    MOUNT_HEIGHT,
    MAP_WIDTH,
    MAP_HEIGHT,
    FOUNTAIN_CENTER_X,
    FOUNTAIN_CENTER_Y,
    TILE_TYPES,
    TILE_KEYS,
    INVENTORY_CAPACITY,
    INVENTORY_COLUMNS,
    CONSUMABLE_CAPACITY,
    MAX_FRAME_DELTA,
    GAME_DURATION_SECONDS,
    POISON_TICK_INTERVAL,
    SNAKE_POISON_DURATION,
};
