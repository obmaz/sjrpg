import { GAME_DURATION_SECONDS, MAP_HEIGHT, MAP_WIDTH, TILE_SIZE } from './constants.js';
import { WEAPONS } from '../data/weapons.js';
const session = {
    terrainRevision: 0,
    gamePaused: false,
    slotMachineOpen: false,
    gameOver: false,
    gameVictory: false,
    lastTime: performance.now(),
    gameStarted: false,
    inventoryOpen: false,
    selectedInventoryIndex: 0,
    compendiumOpen: false,
    shopOpen: false,
    currentShopType: 'village',
    tileMap: [],
};

// ============================================================
//  PLAYER
// ============================================================
const player = {
    x: (MAP_WIDTH * TILE_SIZE) / 2,
    y: (MAP_HEIGHT * TILE_SIZE) / 2,
    w: 24,
    h: 28,
    speed: 225, // pixels per second (1.25x)
    hp: 100,
    maxHp: 100,
    weapon: WEAPONS[0], // 현재 장착 무기
    auxWeapon: null,
    auxWeapons: [], // inventory of aux weapons
    auxCooldown: 0,
    dir: 0, // 0=down, 1=left, 2=up, 3=right
    animTimer: 0,
    animFrame: 0,
    attackTimer: 0,
    attackCooldown: 0.4, // seconds (overridden by weapon)
    invincible: 0,
    gold: 0,
    comboHits: 0, // 연속 타격 횟수
    stage: 1, // 현재 단계
    kills: 0, // 처치 수
    damageDealt: 0, // 누적 피해량
    shieldActive: 0, // 방패 남은 시간
    mount: null, // 현재 탄 탈것 (null = 도보)
    activeQuests: [],
    completedQuests: [],
    killsByName: {},
    bossKills: 0,
    bossKillsByName: {},
    forestCleared: false,
    items: [], // consumable items (max 3)
    collection: { weapons: [], auxiliaryWeapons: [], items: [], enemies: [] },
    currentRegion: 'forest', // 'forest' | 'desert'
    gameTime: GAME_DURATION_SECONDS, // 10 minutes in seconds
    maxGameTime: GAME_DURATION_SECONDS,
    poisonTimer: 0, // 남은 독 시간 (초)
    poisonTick: 0, // 독 틱 타이머
    poisonDamage: 1,
    visionReduction: 0, // 시야 감소 타이머 (초)
    speedBoost: 0, // 스피드 포션 남은 시간 (초)
    bossKilled: false, // 현재 스테이지 보스 처치 여부
    playerFace: '😊', // 캐릭터 외관
    comboTimer: 0,
    attackSerial: 0,
    lastAttackCooldown: 0,
    fountainTimer: 0,
    desertUnlocked: false,
};
const inventory = []; // array of weapon objects

// ============================================================
//  WORLD STATE
// ============================================================
const enemies = [];
const particles = [];
const projectiles = [];
const fireZones = [];
const goldPickups = []; // map gold
const chests = []; // breakable chests
const npcs = []; // NPCs on map
const weaponPickups = []; // weapon drops on ground
// pause for dialogs

const enemyProjectiles = []; // ranged enemy projectiles
const mounts = []; // rideable mounts
const portals = []; // stage portals
const scarecrows = []; // training dummies (허수아비)
const floatingTexts = [];

const pendingGameActions = [];
const WORLD_ENTITY_LISTS = [
    enemies,
    particles,
    projectiles,
    fireZones,
    goldPickups,
    chests,
    npcs,
    weaponPickups,
    enemyProjectiles,
    mounts,
    portals,
    scarecrows,
    floatingTexts,
    pendingGameActions,
];
export {
    player,
    inventory,
    enemies,
    particles,
    projectiles,
    fireZones,
    goldPickups,
    chests,
    npcs,
    weaponPickups,
    enemyProjectiles,
    mounts,
    portals,
    scarecrows,
    floatingTexts,
    pendingGameActions,
    WORLD_ENTITY_LISTS,
    session,
};
