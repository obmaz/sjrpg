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
