'use strict';

function distance(x1, y1, x2, y2) {
    return Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function isGameActive() {
    return gameStarted && !gameOver && !gameVictory;
}

function canAct() {
    return isGameActive() && player.hp > 0 && !gamePaused && !inventoryOpen;
}

function checkPlayerDeath(reason = '전투 중 사망') {
    if (player.hp > 0) return false;
    showGameOverScreen(reason);
    return true;
}

function healPlayer(amount) {
    player.hp = clamp(player.hp + amount, 0, player.maxHp);
}

function applyPlayerPoison(duration, damage = 1) {
    player.poisonTimer += duration;
    player.poisonDamage = Math.max(player.poisonDamage, damage);
    if (player.poisonTick <= 0) player.poisonTick = POISON_TICK_INTERVAL;
}

function movePlayerTo(x, y) {
    if (player.mount) mounts.push({ ...player.mount, x: player.x, y: player.y });
    player.mount = null;
    player.x = x;
    player.y = y;
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);
}

function clearWorldEntities() {
    for (const entities of WORLD_ENTITY_LISTS) entities.length = 0;
}

function deferGameAction(delay, callback) {
    pendingGameActions.push({ delay, callback });
}

function updateDeferredActions(deltaTime) {
    for (let i = pendingGameActions.length - 1; i >= 0; i--) {
        const action = pendingGameActions[i];
        action.delay -= deltaTime;
        if (action.delay <= 0) {
            pendingGameActions.splice(i, 1);
            action.callback();
        }
    }
}

function getAvailableQuests(npc) {
    return QUESTS.filter(
        (quest) => npc.quests.includes(quest.id) && isQuestAvailable(quest, player),
    );
}

function findNearbySpawnPosition(x, y, width, height, ignoreTerrain = false) {
    const isValid = (px, py) =>
        px >= 0 &&
        py >= 0 &&
        px + width <= MAP_WIDTH * TILE_SIZE &&
        py + height <= MAP_HEIGHT * TILE_SIZE &&
        (ignoreTerrain || !collidesWithMap(px, py, width, height)) &&
        !collidesWithEntities(px, py, width, height, null);
    if (isValid(x, y)) return { x, y };
    for (let radius = 1; radius <= 6; radius++) {
        for (let dy = -radius; dy <= radius; dy++) {
            for (let dx = -radius; dx <= radius; dx++) {
                if (Math.max(Math.abs(dx), Math.abs(dy)) !== radius) continue;
                const px = x + dx * TILE_SIZE;
                const py = y + dy * TILE_SIZE;
                if (isValid(px, py)) return { x: px, y: py };
            }
        }
    }
    return null;
}

// Live enemies whose center is within `radius` of (cx, cy).
// Returns a snapshot array so callers can kill enemies mid-loop without skipping any.
function getEnemiesInRadius(cx, cy, radius) {
    return enemies.filter(
        (enemy) =>
            enemy.hp > 0 &&
            distance(cx, cy, enemy.x + enemy.w / 2, enemy.y + enemy.h / 2) < radius + enemy.w / 2,
    );
}

// Pick a random tile position (tile coords as floats), retrying until isValidTile(txi, tyi, x, y)
// is true. If random sampling fails, scan tile centers before reporting no position.
function findSpawnTile(margin, isValidTile, maxAttempts = 80) {
    for (let i = 0; i < maxAttempts; i++) {
        const x = margin + Math.random() * (MAP_WIDTH - margin * 2);
        const y = margin + Math.random() * (MAP_HEIGHT - margin * 2);
        if (isValidTile(Math.floor(x), Math.floor(y), x, y)) return { x, y };
    }
    for (let y = margin; y < MAP_HEIGHT - margin; y++) {
        for (let x = margin; x < MAP_WIDTH - margin; x++) {
            if (isValidTile(x, y, x + 0.5, y + 0.5)) return { x: x + 0.5, y: y + 0.5 };
        }
    }
    return null;
}

function recordDiscovery(type, id) {
    const collection = player.collection[type];
    if (!collection.includes(id)) {
        collection.push(id);
    }
}
