import { updateCamera } from '../core/canvas.js';
import {
    MAP_HEIGHT,
    MAP_WIDTH,
    MAX_FRAME_DELTA,
    POISON_TICK_INTERVAL,
    TILE_SIZE,
} from '../core/constants.js';
import {
    checkPlayerDeath,
    clamp,
    distance,
    isGameActive,
    updateDeferredActions,
} from '../core/helpers.js';
import { player, portals, scarecrows, session } from '../core/state.js';
import { updateEnemies } from './enemy-ai.js';
import {
    spawnFloatingText,
    spawnParticles,
    updateChests,
    updateEnemyProjectiles,
    updateFireZones,
    updateFloatingTexts,
    updateGoldPickups,
    updateParticles,
    updateProjectiles,
    updateWeaponPickups,
} from './entities.js';
import { updatePlayer } from './player.js';
import { updateQuestProgress } from './quests.js';
import { checkPortalSpawn } from './travel.js';
import { updateHud } from '../ui/hud.js';
import { addMessage } from '../ui/messages.js';
import { showGameOverScreen } from '../ui/results.js';

function update(deltaTime) {
    if (!isGameActive() || session.gamePaused || session.inventoryOpen) return;
    if (checkPlayerDeath()) return;

    // Cap dt
    const clampedDeltaTime = clamp(deltaTime, 0, MAX_FRAME_DELTA);

    updatePlayer(clampedDeltaTime);
    updateDeferredActions(clampedDeltaTime);
    updateEnemies(clampedDeltaTime);
    if (checkPlayerDeath()) return;
    updateProjectiles(clampedDeltaTime);
    updateEnemyProjectiles(clampedDeltaTime);
    if (checkPlayerDeath()) return;
    updateFireZones(clampedDeltaTime);
    updateGoldPickups(clampedDeltaTime);
    updateWeaponPickups(clampedDeltaTime);
    updateChests(clampedDeltaTime);
    if (checkPlayerDeath()) return;
    updateParticles(clampedDeltaTime);
    updateFloatingTexts(clampedDeltaTime);
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);

    // Fountain HP regen (costs gold)
    const fountainCX = (MAP_WIDTH / 2) * TILE_SIZE;
    const fountainCY = (MAP_HEIGHT / 2) * TILE_SIZE;
    const distToFountain = distance(
        player.x + player.w / 2,
        player.y + player.h / 2,
        fountainCX,
        fountainCY,
    );
    const canHeal = distToFountain < 180 && player.hp < player.maxHp && player.gold > 0;
    player.fountainTimer = canHeal ? (player.fountainTimer || 0) + clampedDeltaTime : 0;
    if (canHeal && player.fountainTimer >= 1.0) {
        player.fountainTimer -= 1.0;
        const healAmt = Math.min(3, player.maxHp - player.hp, player.gold);
        player.hp += healAmt;
        player.gold -= healAmt;
        updateHud();
        spawnFloatingText(player.x + player.w / 2, player.y - 16, `-${healAmt}💰`, '#ff8866');
        // Re-check portal condition when gold changes at fountain
        checkPortalSpawn();
    }

    // Game timer
    player.gameTime -= clampedDeltaTime;
    if (player.gameTime <= 0) {
        player.gameTime = 0;
        showGameOverScreen('⏱ 시간 초과');
        return;
    }

    // Poison timer
    if (player.poisonTimer > 0) {
        const poisonDeltaTime = Math.min(clampedDeltaTime, player.poisonTimer);
        player.poisonTimer -= poisonDeltaTime;
        player.poisonTick -= poisonDeltaTime;
        if (player.poisonTick <= 0) {
            player.poisonTick += POISON_TICK_INTERVAL;
            player.hp -= player.poisonDamage;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#88ff44', 5);
            spawnFloatingText(
                player.x + player.w / 2,
                player.y - 8,
                `☠-${player.poisonDamage}`,
                '#88ff44',
            );
            if (player.hp <= 0) {
                showGameOverScreen('☠️ 독으로 사망');
                return;
            }
        }
        if (player.poisonTimer <= 0) {
            player.poisonTimer = 0;
            player.poisonTick = 0;
            player.poisonDamage = 1;
            addMessage('☠️ 독이 해독되었습니다!', 'heal');
        }
    }

    // Vision reduction timer
    if (player.visionReduction > 0) {
        player.visionReduction -= clampedDeltaTime;
        if (player.visionReduction <= 0) {
            player.visionReduction = 0;
            addMessage('👁️ 시야가 정상으로 돌아왔습니다!', 'info');
        }
    }

    updateHud();

    // Update quest progress
    updateQuestProgress();
    checkPortalSpawn();

    // Update portals animation
    for (const p of portals) {
        p.animTimer += clampedDeltaTime;
    }

    // Update scarecrows
    for (const sc of scarecrows) {
        if (sc.hurtTimer > 0) sc.hurtTimer -= clampedDeltaTime;
    }
}

export { update };
