import { updateCamera } from '../core/canvas.js';
import { MAP_HEIGHT, MAP_WIDTH, TILE_SIZE } from '../core/constants.js';
import { clearWorldEntities, distance, isGameActive } from '../core/helpers.js';
import { player, portals } from '../core/state.js';
import { abandonRegionQuests, updateQuestProgress } from './quests.js';
import { spawnDesertEnemies, spawnDesertNpcs, spawnDesertPickups } from './spawning.js';
import { generateDesertMap } from './world.js';
import { showDesertTravelDialog } from '../ui/dialogs.js';
import { updateHud } from '../ui/hud.js';
import { addMessage } from '../ui/messages.js';

// ============================================================
//  PORTAL SYSTEM (분수 → 사막 포탈)
// ============================================================
function checkPortalSpawn() {
    // 조건: 보스 처치 + 1000골드 + 포탈이 아직 없음 + 숲 지역
    if (
        player.bossKilled &&
        player.gold >= 1000 &&
        portals.length === 0 &&
        player.currentRegion === 'forest'
    ) {
        spawnPortal();
    }
}

function spawnPortal() {
    const fcx = Math.floor(MAP_WIDTH / 2);
    const fcy = Math.floor(MAP_HEIGHT / 2);
    portals.push({
        x: fcx * TILE_SIZE + TILE_SIZE / 2 - 28,
        y: fcy * TILE_SIZE + TILE_SIZE / 2 - 28,
        w: 56,
        h: 56,
        animTimer: 0,
    });
    addMessage('🌀 분수 중앙에 차원 포탈이 열렸다! 다가가서 상호작용하세요 [E]', 'loot');
}

function interactPortal() {
    let closestPortal = null,
        closestDist = 50;
    for (const p of portals) {
        const dist = distance(
            player.x + player.w / 2,
            player.y + player.h / 2,
            p.x + p.w / 2,
            p.y + p.h / 2,
        );
        if (dist < closestDist) {
            closestPortal = p;
            closestDist = dist;
        }
    }
    if (!closestPortal) return false;

    showDesertTravelDialog(
        {
            icon: '🌀',
            name: '차원 포탈',
            dialog: '사막으로 통하는 포탈이 열려있습니다. 들어가시겠습니까?',
        },
        '포탈을 통해 사막 지역으로 떠납니다',
    );
    return true;
}

// ============================================================
//  DESERT TRAVEL
// ============================================================
function travelToDesert() {
    if (!isGameActive() || player.currentRegion !== 'forest') return;
    updateQuestProgress();
    abandonRegionQuests('forest');
    player.currentRegion = 'desert';
    player.bossKilled = false;
    // Clear current world state
    clearWorldEntities();
    player.fountainTimer = 0;

    // Generate desert map
    generateDesertMap(Math.floor(Math.random() * 100000) + 50000);

    // Place player at desert center
    player.x = (MAP_WIDTH * TILE_SIZE) / 2;
    player.y = (MAP_HEIGHT * TILE_SIZE) / 2;
    player.mount = null;

    // Spawn desert enemies
    spawnDesertEnemies();
    // Spawn desert pickups
    spawnDesertPickups();
    // Spawn desert NPCs
    spawnDesertNpcs();

    updateHud();
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);
    addMessage('🏜️ 사막에 도착했습니다! 새로운 모험이 기다립니다!', 'loot');
    addMessage('☠️ 사막의 적들은 더욱 강력합니다...', 'damage');
}

export { checkPortalSpawn, interactPortal, travelToDesert };
