const WORLD_FRAMES = Object.freeze({
    heroDown: ['forest', 0],
    heroLeft: ['forest', 1],
    heroUp: ['forest', 2],
    heroRight: ['forest', 3],
    merchant: ['forest', 4],
    villager: ['forest', 5],
    traveler: ['forest', 6],
    stylist: ['forest', 7],
    tree: ['forest', 8],
    bush: ['forest', 9],
    rock: ['forest', 10],
    chest: ['forest', 11],
    fountain: ['forest', 12],
    shop: ['forest', 13],
    goblin: ['forest', 14],
    wolf: ['forest', 15],
    palm: ['desert', 0],
    cactus: ['desert', 1],
    sandstone: ['desert', 2],
    desertShop: ['desert', 3],
    scorpion: ['desert', 4],
    mummy: ['desert', 5],
    skeleton: ['desert', 6],
    cultist: ['desert', 7],
    troll: ['desert', 8],
    golem: ['desert', 9],
    slime: ['desert', 10],
    pharaoh: ['desert', 11],
    horse: ['desert', 12],
    bicycle: ['desert', 13],
    motor: ['desert', 14],
    boat: ['desert', 15],
});

function enemyWorldArt(enemy) {
    if (enemy.name === '고대 드래곤') return 'ancientDragon';
    if (enemy.name === '파라오') return 'pharaoh';
    if (enemy.name === '회색 점액괴물' || enemy.name === '황토 젤리') return 'slime';
    return {
        8: 'goblin',
        9: 'wolf',
        10: 'skeleton',
        11: 'cultist',
        12: 'troll',
        13: 'golem',
        14: 'scorpion',
        15: 'mummy',
    }[enemy.artIndex];
}

export { WORLD_FRAMES, enemyWorldArt };

const MOUNT_ART_ROWS = Object.freeze({ horse: 0, bicycle: 1, motor: 2, boat: 3 });
function getMountArtFrame(id, direction = 0) {
    const row = MOUNT_ART_ROWS[id];
    if (row === undefined) return null;
    const facing = Number.isInteger(direction) && direction >= 0 && direction < 4 ? direction : 0;
    return ['mounts', row * 4 + facing];
}
export { getMountArtFrame };

// Measured sprite rectangles: row spacing in the generated sheet is not assumed uniform.
const MOUNT_SPRITE_BOUNDS = [
    [77, 24, 132, 327],
    [320, 101, 302, 232],
    [723, 22, 128, 328],
    [941, 99, 309, 234],
    [69, 383, 156, 263],
    [305, 418, 329, 210],
    [698, 383, 169, 263],
    [913, 418, 322, 209],
    [52, 676, 191, 267],
    [296, 723, 346, 200],
    [697, 690, 168, 247],
    [915, 723, 338, 201],
    [61, 951, 165, 271],
    [302, 1013, 320, 158],
    [702, 954, 156, 267],
    [926, 1012, 315, 159],
];
export { MOUNT_SPRITE_BOUNDS };
