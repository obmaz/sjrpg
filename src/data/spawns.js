// ============================================================
//  SPAWN RULES  (per-map enemy spawning by distance from fountain)
//  ------------------------------------------------------------
//  분수(맵 중앙)에서 가까울수록 저랩 몹, 멀어질수록 고랩 몹이 나옵니다.
//  `dist`는 분수 중심으로부터의 픽셀 거리.
//  - bands: 거리대(maxDist)별 등장 가능한 적 타입 인덱스 풀. 순서대로
//           검사하여 첫 번째로 거리를 포함하는 밴드를 사용합니다.
//           밴드 순서(tier 0,1,2,...)가 그대로 몹 레벨대가 됩니다.
//  - wildcard: 거리와 무관하게 가끔 끼어드는 특수 몹(예: 독수리).
//
//  ⚠️ types 인덱스는 enemies.js의 ENEMY_TYPES / DESERT_ENEMY_TYPES 순서를
//     가리킵니다. 보스 인덱스(forest:5 악당보스, desert:7 파라오)는 제외.
// ============================================================
const SPAWN_RULES = {
    forest: {
        bands: [
            { maxDist: 350, types: [0, 1] }, // 슬라임, 고블린
            { maxDist: 650, types: [1, 2, 3] }, // 고블린, 늑대, 해골 전사
            { maxDist: 1000, types: [2, 3, 4, 7] }, // 늑대~다크 메이지, 거대 슬라임
            { maxDist: Infinity, types: [3, 4, 8, 9] }, // 해골~다크 메이지, 트롤, 고대 골렘
        ],
        wildcard: { chance: 0.12, types: [6] }, // 독수리 (어디서나 가끔)
    },
    desert: {
        bands: [
            { maxDist: 350, types: [0, 1] }, // 전갈, 모래 도마뱀
            { maxDist: 650, types: [1, 2, 4] }, // 모래 도마뱀, 미라, 독사
            { maxDist: 1000, types: [2, 3, 4] }, // 미라, 모래 마법사, 독사
            { maxDist: Infinity, types: [3, 5, 6] }, // 모래 마법사, 사막 트롤, 모래 골렘
        ],
        wildcard: { chance: 0.1, types: [5] }, // 사막 트롤 (어디서나 가끔)
    },
};

// 분수로부터의 거리(픽셀)로 등장 적 타입을 고른다.
// 반환: { idx: 적 타입 인덱스, tier: 거리대(0=근접/저랩 ...) }
function pickSpawnType(region, dist) {
    const rule = SPAWN_RULES[region] || SPAWN_RULES.forest;
    let tier = rule.bands.findIndex((b) => dist < b.maxDist);
    if (tier < 0) tier = rule.bands.length - 1;
    // tier(거리대)는 항상 거리를 반영 → 레벨 표기에 사용. 와일드카드는 타입 풀만 교체.
    let types = rule.bands[tier].types;
    if (rule.wildcard && Math.random() < rule.wildcard.chance) types = rule.wildcard.types;
    return { idx: types[Math.floor(Math.random() * types.length)], tier };
}

// 거리대(tier)로부터 몹 레벨 산출: 분수 근처 Lv1~ , 멀수록 높아짐.
function spawnLevelForTier(tier) {
    return 1 + tier * 3 + Math.floor(Math.random() * 3);
}

export { SPAWN_RULES, pickSpawnType, spawnLevelForTier };
