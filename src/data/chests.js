// ============================================================
//  CHEST TYPE DEFINITIONS
// ============================================================
const CHEST_TYPES = [
    {
        id: 'wooden',
        name: '나무 상자',
        w: 28,
        h: 26,
        hp: 3,
        color: '#8B6914',
        dropCount: 1,
        dropGold: [10, 40],
        dropWeapons: ['dagger', 'iron', 'axe'],
    },
    {
        id: 'iron',
        name: '철 상자',
        w: 72,
        h: 66,
        hp: 9,
        color: '#6a7a8a',
        dropCount: 3,
        dropGold: [40, 120],
        dropWeapons: ['axe', 'staff', 'firesword', 'legend', 'ice_sword'],
    },
];

export { CHEST_TYPES };
