const ITEMS = [
    {
        id: 'healpot',
        name: '치유의 물약',
        icon: '🧪',
        price: 30,
        desc: 'HP 50 회복 · 치유의 물약 2d4+2에서 실시간 전투용 조정',
        artIndex: 7,
        referenceDice: '2d4+2',
        use: 'heal',
        healAmount: 50,
    },
    {
        id: 'bomb',
        name: '폭탄',
        icon: '💣',
        price: 60,
        desc: '넓은 범위 폭발 (ATK 30)',
        use: 'bomb',
        bombDmg: 30,
        bombRange: 90,
    },
    {
        id: 'antidote',
        name: '해독제',
        icon: '🧴',
        price: 40,
        desc: '모든 이상상태 해제',
        use: 'antidote',
    },
    {
        id: 'speedpot',
        name: '스피드 포션',
        icon: '⚡',
        price: 80,
        desc: '10초간 이동속도 1.5배',
        use: 'speed',
    },
    {
        id: 'returngem',
        name: '귀환 보석',
        icon: '💠',
        price: 500,
        desc: '분수로 순간이동',
        use: 'return',
    },
];

export { ITEMS };
