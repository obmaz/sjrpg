import {
    canOccupyMountPosition,
    collidesWithEntities,
    collidesWithMap,
} from '../core/collision.js';
import {
    FOUNTAIN_CENTER_X,
    FOUNTAIN_CENTER_Y,
    MAP_HEIGHT,
    MAP_WIDTH,
    MOUNT_HEIGHT,
    MOUNT_WIDTH,
    TILE_SIZE,
} from '../core/constants.js';
import { distance, findNearbySpawnPosition, findSpawnTile } from '../core/helpers.js';
import { enemies, npcs, player, scarecrows } from '../core/state.js';
import { getRandomBoss } from '../data/bosses.js';
import { DESERT_ENEMY_TYPES, ENEMY_TYPES } from '../data/enemies.js';
import { MOUNT_TYPES } from '../data/mounts.js';
import { pickSpawnType, spawnLevelForTier } from '../data/spawns.js';
import { spawnChest, spawnGoldPickup } from './entities.js';
import { spawnMount } from './mounts.js';
import { isReachableFromArrival } from './navigation.js';
import { isSolidTile, isWaterTile } from './world.js';
import { addMessage } from '../ui/messages.js';

function spawnEnemy(type, x, y, level = null, options = {}) {
    const position = findNearbySpawnPosition(
        x,
        y,
        type.size,
        type.size,
        type.flying || type.megaBoss,
        type.flying || type.megaBoss
            ? () => true
            : (px, py) => isReachableFromArrival(px, py, type.size, type.size),
    );
    if (!position) return null;
    const stageMultiplier = options.stageMultiplier ?? 1 + (player.stage - 1) * 0.25;
    const bossHpMultiplier = type.isBoss ? 1.3 : 1;
    const maxHp = Math.floor(type.hp * stageMultiplier * bossHpMultiplier);
    const speed =
        options.randomizeSpeed === false
            ? type.speed
            : (type.speed + (Math.random() - 0.5) * 30) * (1 + (player.stage - 1) * 0.05);
    const enemy = {
        x: position.x,
        y: position.y,
        w: type.size,
        h: type.size,
        hp: maxHp,
        maxHp,
        atk: Math.floor(type.atk * stageMultiplier),
        speed,
        name: type.name,
        icon: type.icon ?? '',
        color: type.color,
        dropRate: Math.min(1, type.dropRate + (player.stage - 1) * 0.03),
        dropPool: type.dropPool,
        isBoss: type.isBoss ?? false,
        megaBoss: type.megaBoss ?? false,
        ranged: type.ranged ?? false,
        flying: type.flying ?? false,
        poison: type.poison ?? false,
        poisonDmg: type.poisonDmg ?? 1,
        rangeCooldown: type.rangeCooldown ?? 2,
        rangeDmg: type.rangeDmg ?? Math.floor(type.atk * stageMultiplier),
        projSpeed: type.projSpeed ?? 250,
        destroyTerrain: type.destroyTerrain ?? false,
        spawnMinions: type.spawnMinions ?? false,
        minionType: type.minionType ?? 3,
        spawnCooldown: type.spawnCooldown ?? 8,
        spawnCount: type.spawnCount ?? 2,
        spawnTimer: type.spawnCooldown ?? 8,
        gold: type.gold,
        level: level ?? player.stage + Math.floor(Math.random() * 3),
        animTimer: Math.random() * Math.PI * 2,
        state: 'wander',
        stateTimer: 0,
        attackCooldown: 0,
        rangeAttackCd: 1,
        hurtTimer: 0,
        frozen: 0,
        knockbackX: 0,
        knockbackY: 0,
        dir: 0,
        wanderTarget: { ...position },
    };
    enemies.push(enemy);
    return enemy;
}

// Spawn a non-boss enemy at tile (ex, ey) chosen by its distance from the fountain,
// using the per-map rules in data/spawns.js. Level scales with that distance.
function spawnByDistance(region, ex, ey) {
    const pool = region === 'desert' ? DESERT_ENEMY_TYPES : ENEMY_TYPES;
    const px = ex * TILE_SIZE + TILE_SIZE / 2;
    const py = ey * TILE_SIZE + TILE_SIZE / 2;
    const dist = distance(px, py, FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);
    const { idx, tier } = pickSpawnType(region, dist);
    const type = pool[Math.min(idx, pool.length - 1)];
    if (!type || type.isBoss) return;
    spawnEnemy(type, px, py, spawnLevelForTier(tier));
}

function spawnBoss(bossData, x, y) {
    const enemy = spawnEnemy(
        {
            ...bossData,
            isBoss: true,
            megaBoss: true,
            dropRate: 1,
            dropPool: ['legend'],
            projSpeed: bossData.projSpeed ?? 180,
        },
        x,
        y,
        player.stage + 5,
        { randomizeSpeed: false },
    );
    if (enemy) addMessage(`👹 ${bossData.name} 등장! ${bossData.desc}`, 'damage');
    return enemy;
}

function spawnEnemies() {
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    const enemyCount = 20;
    for (let i = 0; i < enemyCount; i++) {
        const tile = findSpawnTile(
            4,
            (txi, tyi, x, y) =>
                !isSolidTile(txi, tyi) &&
                !isWaterTile(txi, tyi) &&
                distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 200 &&
                distance(x, y, fcx, fcy) >= 5,
        );
        if (tile) {
            const { x: ex, y: ey } = tile;
            spawnByDistance('forest', ex, ey);
        }
    }

    // Spawn random boss
    const bossData = getRandomBoss();
    const tile = findSpawnTile(
        8,
        (txi, tyi, x, y) =>
            !isSolidTile(txi, tyi) &&
            !isWaterTile(txi, tyi) &&
            distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 600,
    );
    if (tile) {
        const { x: bx, y: by } = tile;
        spawnBoss(bossData, bx * TILE_SIZE + TILE_SIZE / 2, by * TILE_SIZE + TILE_SIZE / 2);
    }
}

function spawnMoreEnemies() {
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    const count = 5 + player.stage * 2;
    const region = player.currentRegion === 'desert' ? 'desert' : 'forest';

    for (let i = 0; i < count; i++) {
        const tile = findSpawnTile(
            3,
            (txi, tyi, x, y) =>
                !isSolidTile(txi, tyi) &&
                !isWaterTile(txi, tyi) &&
                distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 180 &&
                distance(x, y, fcx, fcy) >= 5,
            30,
        );
        if (tile) {
            const { x: ex, y: ey } = tile;
            spawnByDistance(region, ex, ey);
        }
    }
}

// Stage-gated NPC definitions
const STAGE_NPCS = {
    2: [
        {
            icon: '🛡️',
            name: '경비대장',
            dialog: '해골 전사들을 처치해주게!',
            quests: ['hunt_skeletons'],
        },
    ],
};

function spawnStageNpcs(oldStage, newStage) {
    if (player.currentRegion !== 'forest') return;
    for (let s = oldStage + 1; s <= newStage; s++) {
        const defs = STAGE_NPCS[s];
        if (!defs) continue;
        for (const def of defs) {
            if (!spawnQuestNpc(def, 100)) continue;
            addMessage(`🆕 ${def.icon} ${def.name}이(가) 마을에 나타났다!`, 'loot');
        }
    }
}

function spawnInitialPickups() {
    for (let i = 0; i < 10; i++) {
        const tile = findSpawnTile(
            3,
            (txi, tyi) => !isSolidTile(txi, tyi) && !isWaterTile(txi, tyi),
        );
        if (tile) {
            const { x: gx, y: gy } = tile;
            spawnGoldPickup(gx * TILE_SIZE + TILE_SIZE / 2, gy * TILE_SIZE + TILE_SIZE / 2);
        }
    }
    // Spawn wooden chests
    for (let i = 0; i < 4; i++) {
        const tile = findSpawnTile(
            4,
            (txi, tyi, x, y) =>
                !isSolidTile(txi, tyi) &&
                !isWaterTile(txi, tyi) &&
                distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 150,
        );
        if (tile) {
            const { x: cx, y: cy } = tile;
            spawnChest(cx * TILE_SIZE + TILE_SIZE / 2, cy * TILE_SIZE + TILE_SIZE / 2, 'wooden');
        }
    }
    // Spawn 1 iron chest
    {
        const tile = findSpawnTile(
            5,
            (txi, tyi, x, y) =>
                !isSolidTile(txi, tyi) &&
                !isWaterTile(txi, tyi) &&
                distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 200,
        );
        if (tile) {
            const { x: cx, y: cy } = tile;
            spawnChest(cx * TILE_SIZE + TILE_SIZE / 2, cy * TILE_SIZE + TILE_SIZE / 2, 'iron');
        }
    }

    // Spawn mounts
    spawnInitialMounts();
    spawnForestNpcs();
}

function spawnForestNpcs() {
    // Create multiple NPCs scattered around the map
    const npcDefs = [
        {
            icon: '🧙',
            name: '현자',
            dialog: '안녕하신가, 용사여! 자네에게 주요 임무를 맡기겠네.',
            quests: ['kill_monsters', 'hunt_wolves'],
        },
        {
            icon: '👨‍🌾',
            name: '농부',
            dialog: '독수리가 내 작물을 망치고 있어요!',
            quests: ['hunt_eagles'],
        },
        { icon: '🧝', name: '요정', dialog: '반짝이는 골드가 필요해!', quests: ['collect_coins'] },
        {
            icon: '👴',
            name: '촌장',
            dialog: '용사여, 위대한 임무를 맡아주게나.',
            quests: ['collect_gold', 'slay_boss', 'collect_riches', 'collect_1000gold'],
        },
    ];
    for (const def of npcDefs) {
        if (!spawnQuestNpc(def, 100)) continue;
    }

    // ── Village shop NPC (near fountain) ──
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    spawnNpc({
        x: (fcx + 8) * TILE_SIZE + TILE_SIZE / 2 - 32,
        y: fcy * TILE_SIZE + TILE_SIZE / 2 - 32,
        w: 64,
        h: 64,
        icon: '🏪',
        name: '상인',
        dialog: '어서오세요! 좋은 무기를 골드로 판매합니다.',
        quests: [],
        isShop: true,
        shopType: 'village',
    });

    // ── Appearance change NPC (near fountain) ──
    spawnNpc({
        x: (fcx + 3) * TILE_SIZE + TILE_SIZE / 2 - 12,
        y: (fcy - 7) * TILE_SIZE + TILE_SIZE / 2 - 14,
        w: 24,
        h: 28,
        icon: '💈',
        name: '미용사',
        dialog: '용사님, 외관을 바꿔드릴까요? 멋진 모습으로 모험을 떠나보세요!',
        quests: [],
        isStylist: true,
    });

    // ── Scarecrow (training dummy) right next to fountain ──
    scarecrows.push({
        x: (fcx - 2) * TILE_SIZE + TILE_SIZE / 2 - 18,
        y: (fcy - 2) * TILE_SIZE + TILE_SIZE / 2 - 4,
        w: 36,
        h: 54,
        hp: 99999,
        maxHp: 99999,
        hurtTimer: 0,
        animTimer: 0,
    });

    // ── Slot machine NPC (near fountain, opposite side) ──
    spawnNpc({
        x: (fcx - 8) * TILE_SIZE + TILE_SIZE / 2 - 28,
        y: (fcy + 2) * TILE_SIZE + TILE_SIZE / 2 - 28,
        w: 56,
        h: 56,
        icon: '🎰',
        name: '슬롯머신',
        dialog: '50골드를 넣고 레버를 당기면 랜덤한 능력이 발동됩니다!\n\n🎁 200골드 획득 | 💸 100골드 잃음\n👁️ 시야 절반 | ☠️ 독 감염\n🌀 랜덤 이동 | 💎 전설 무기',
        quests: [],
        isSlotMachine: true,
    });

    // ── Black market NPC (map edge) ──
    let bmx, bmy;
    const corners = [
        [3, 3],
        [MAP_WIDTH - 4, 3],
        [3, MAP_HEIGHT - 4],
        [MAP_WIDTH - 4, MAP_HEIGHT - 4],
        [3, MAP_HEIGHT / 2],
        [MAP_WIDTH - 4, MAP_HEIGHT / 2],
        [MAP_WIDTH / 2, 3],
        [MAP_WIDTH / 2, MAP_HEIGHT - 4],
    ];
    for (const [cx, cy] of corners) {
        if (
            !isSolidTile(Math.floor(cx), Math.floor(cy)) &&
            !isWaterTile(Math.floor(cx), Math.floor(cy)) &&
            distance(cx * TILE_SIZE, cy * TILE_SIZE, player.x, player.y) > 400
        ) {
            bmx = cx;
            bmy = cy;
            break;
        }
    }
    if (!bmx) {
        bmx = 3;
        bmy = 3;
    }
    spawnNpc({
        x: bmx * TILE_SIZE + TILE_SIZE / 2 - 32,
        y: bmy * TILE_SIZE + TILE_SIZE / 2 - 32,
        w: 64,
        h: 64,
        icon: '🥷',
        name: '암시장 상인',
        dialog: '쉿... 희귀한 물건들입니다. 값은 비싸지만요.',
        quests: [],
        isShop: true,
        shopType: 'blackmarket',
    });
}

function spawnDesertTraveler() {
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    spawnNpc({
        x: (fcx - 8) * TILE_SIZE + TILE_SIZE / 2 - 12,
        y: fcy * TILE_SIZE + TILE_SIZE / 2 - 14,
        w: 24,
        h: 28,
        icon: '🐪',
        name: '사막 여행자',
        dialog: '사막으로 가는 길을 알고 있습니다. 함께 가시겠습니까?',
        quests: [],
        isDesertTraveler: true,
    });
    addMessage('🐪 분수 근처에 사막 여행자가 나타났다!', 'loot');
}

function spawnDesertEnemies() {
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    const enemyCount = 25;
    for (let i = 0; i < enemyCount; i++) {
        const tile = findSpawnTile(
            4,
            (txi, tyi, x, y) =>
                !isSolidTile(txi, tyi) &&
                !isWaterTile(txi, tyi) &&
                distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 200 &&
                distance(x, y, fcx, fcy) >= 5,
        );
        if (tile) {
            const { x: ex, y: ey } = tile;
            spawnByDistance('desert', ex, ey);
        }
    }

    // Spawn desert boss (Pharaoh) far away
    const bossData = DESERT_ENEMY_TYPES.find((e) => e.isBoss);
    if (bossData) {
        const tile = findSpawnTile(
            10,
            (txi, tyi, x, y) =>
                !isSolidTile(txi, tyi) &&
                !isWaterTile(txi, tyi) &&
                distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 500,
        );
        if (!tile) return;
        const { x: bx, y: by } = tile;
        spawnEnemy(
            bossData,
            bx * TILE_SIZE + TILE_SIZE / 2,
            by * TILE_SIZE + TILE_SIZE / 2,
            player.stage + 8,
            { stageMultiplier: 1, randomizeSpeed: false },
        );
        addMessage(`👑 ${bossData.name} 등장! 사막을 지배하는 자...`, 'damage');
    }
}

function spawnDesertPickups() {
    for (let i = 0; i < 12; i++) {
        const tile = findSpawnTile(
            3,
            (txi, tyi) => !isSolidTile(txi, tyi) && !isWaterTile(txi, tyi),
        );
        if (tile) {
            const { x: gx, y: gy } = tile;
            spawnGoldPickup(gx * TILE_SIZE + TILE_SIZE / 2, gy * TILE_SIZE + TILE_SIZE / 2);
        }
    }
    for (let i = 0; i < 3; i++) {
        const tile = findSpawnTile(
            4,
            (txi, tyi, x, y) =>
                !isSolidTile(txi, tyi) &&
                !isWaterTile(txi, tyi) &&
                distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 150,
        );
        if (tile) {
            const { x: cx, y: cy } = tile;
            spawnChest(cx * TILE_SIZE + TILE_SIZE / 2, cy * TILE_SIZE + TILE_SIZE / 2, 'iron');
        }
    }
}

function spawnDesertNpcs() {
    const npcDefs = [
        {
            icon: '🧕',
            name: '유목민',
            dialog: '사막에서 살아남으려면 좋은 무기가 필요하지...',
            quests: ['collect_1000gold'],
        },
        {
            icon: '📜',
            name: '고고학자',
            dialog: '파라오의 무덤에 대해 알고 있나?',
            quests: ['slay_pharaoh'],
        },
    ];
    for (const def of npcDefs) {
        if (!spawnQuestNpc(def, 120)) continue;
    }

    // Desert oasis shop
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    spawnNpc({
        x: (fcx + 8) * TILE_SIZE + TILE_SIZE / 2 - 32,
        y: fcy * TILE_SIZE + TILE_SIZE / 2 - 32,
        w: 64,
        h: 64,
        icon: '🏕️',
        name: '오아시스 상인',
        dialog: '사막의 희귀한 무기들... 관심 있나?',
        quests: [],
        isShop: true,
        shopType: 'blackmarket',
    });
}

function spawnInitialMounts() {
    // Land mounts
    const landMounts = [MOUNT_TYPES[0], MOUNT_TYPES[1], MOUNT_TYPES[2]]; // bicycle, horse, motor
    for (const mt of landMounts) {
        const tile = findSpawnTile(
            4,
            (txi, tyi, x, y) =>
                !isSolidTile(txi, tyi) &&
                !isWaterTile(txi, tyi) &&
                distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 150,
        );
        if (tile) {
            const { x: mx, y: my } = tile;
            spawnMount(mt, mx * TILE_SIZE + TILE_SIZE / 2, my * TILE_SIZE + TILE_SIZE / 2);
        }
    }
    // Boat: spawn at water edge
    const boat = { ...MOUNT_TYPES[3], w: MOUNT_WIDTH, h: MOUNT_HEIGHT };
    const boatTile = findSpawnTile(3, (_tileX, _tileY, x, y) => {
        const bx = x * TILE_SIZE;
        const by = y * TILE_SIZE;
        if (!canOccupyMountPosition(boat, bx, by)) return false;
        // The entire boat must fit on water, with a shore the player can stand on.
        const shorePositions = [
            [bx - player.w, by + (boat.h - player.h) / 2],
            [bx + boat.w, by + (boat.h - player.h) / 2],
            [bx + (boat.w - player.w) / 2, by - player.h],
            [bx + (boat.w - player.w) / 2, by + boat.h],
        ];
        return shorePositions.some(
            ([sx, sy]) =>
                !collidesWithMap(sx, sy, player.w, player.h) &&
                !collidesWithEntities(sx, sy, player.w, player.h, player),
        );
    });
    if (boatTile) spawnMount(boat, boatTile.x * TILE_SIZE, boatTile.y * TILE_SIZE);
}

function spawnQuestNpc(definition, minimumDistance) {
    const width = 24,
        height = 28;
    const tile = findSpawnTile(5, (tileX, tileY, x, y) => {
        const px = x * TILE_SIZE - width / 2;
        const py = y * TILE_SIZE - height / 2;
        return (
            !isSolidTile(tileX, tileY) &&
            !collidesWithMap(px, py, width, height) &&
            !collidesWithEntities(px, py, width, height, player) &&
            distance(px, py, player.x, player.y) > minimumDistance
        );
    });
    if (!tile) return false;
    return Boolean(
        spawnNpc({
            ...definition,
            x: tile.x * TILE_SIZE - width / 2,
            y: tile.y * TILE_SIZE - height / 2,
            w: width,
            h: height,
        }),
    );
}

// Fixed buildings and quest NPCs share full-body terrain validation.
function spawnNpc(definition) {
    const position = findNearbySpawnPosition(
        definition.x,
        definition.y,
        definition.w,
        definition.h,
    );
    if (!position) return null;
    const npc = { ...definition, ...position };
    npcs.push(npc);
    return npc;
}

export {
    spawnEnemy,
    spawnBoss,
    spawnEnemies,
    spawnMoreEnemies,
    spawnStageNpcs,
    spawnInitialPickups,
    spawnDesertTraveler,
    spawnDesertEnemies,
    spawnDesertPickups,
    spawnDesertNpcs,
    spawnNpc,
};
