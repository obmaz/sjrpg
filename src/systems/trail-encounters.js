import { getActorAngle } from '../core/facing.js';
import { canAct } from '../core/helpers.js';
import { enemies, player, session } from '../core/state.js';
import { inVillage, VILLAGE } from '../data/village.js';
import { ENEMY_TYPES, DESERT_ENEMY_TYPES } from '../data/enemies.js';
import { pickSpawnType, spawnLevelForTier } from '../data/spawns.js';
import { FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y } from '../core/constants.js';
import { spawnEnemy } from './spawning.js';

function updateTrailEncounters(deltaTime) {
    if (!session.trailEncountersEnabled || !canAct()) return;
    const village = player.currentRegion === 'forest' && inVillage(player.x, player.y);
    if (village && player.y < VILLAGE.y + VILLAGE.height * 0.4) return;
    if (
        !village &&
        (session.landscapeMap !== session.tileMap ||
            session.landscape?.region !== player.currentRegion)
    )
        return;
    // Unengaged roaming packs left far behind must not exhaust the new area's cap.
    for (let i = enemies.length - 1; i >= 0; i--) {
        const enemy = enemies[i];
        if (
            !enemy.isBoss &&
            !enemy.enemyPoison &&
            Math.hypot(enemy.x - player.x, enemy.y - player.y) > 1600
        )
            enemies.splice(i, 1);
    }
    const anchor = session.trailEncounterAnchor;
    if (
        !anchor ||
        anchor.region !== player.currentRegion ||
        Math.hypot(anchor.x - player.x, anchor.y - player.y) > 560
    ) {
        session.trailEncounterTimer = 0;
        session.trailEncounterAnchor = { x: player.x, y: player.y, region: player.currentRegion };
    }
    session.trailEncounterTimer -= deltaTime;
    if (session.trailEncounterTimer > 0) return;
    const nearby = enemies.filter(
        (e) => e.hp > 0 && Math.hypot(e.x - player.x, e.y - player.y) < 620,
    ).length;
    let population = enemies.filter((e) => e.hp > 0 && !e.isBoss).length;
    // Reserve room for the area the player is exploring, even after stage reinforcements.
    for (let i = enemies.length - 1; i >= 0 && population > 36; i--) {
        const e = enemies[i];
        if (!e.isBoss && !e.enemyPoison && Math.hypot(e.x - player.x, e.y - player.y) > 700) {
            enemies.splice(i, 1);
            population--;
        }
    }
    if (nearby >= 9 || population >= 40) {
        session.trailEncounterTimer = 2;
        return;
    }
    const pool = player.currentRegion === 'desert' ? DESERT_ENEMY_TYPES : ENEMY_TYPES;
    const positions = [
        [-0.08, 0.64],
        [0.1, 0.68],
        [-0.02, 0.78],
        [0.18, 0.72],
    ];
    const distance = Math.hypot(player.x - FOUNTAIN_CENTER_X, player.y - FOUNTAIN_CENTER_Y);
    const count = Math.min(nearby === 0 ? 3 : 2, 9 - nearby);
    let spawned = 0;
    for (let attempt = 0; attempt < 16 && spawned < count; attempt++) {
        const [dx, v] = positions[(attempt + player.stage) % positions.length];
        const angle =
                getActorAngle(player) +
                (attempt < 3 ? [0, 1.05, -1.05][attempt] : attempt * 2.399963),
            radius = 260 + (attempt % 3) * 65;
        const x = village
            ? VILLAGE.x + VILLAGE.width * (0.5 + dx)
            : player.x + Math.cos(angle) * radius;
        const y = village ? VILLAGE.y + VILLAGE.height * v : player.y + Math.sin(angle) * radius;
        const choice = pickSpawnType(player.currentRegion, distance);
        const type = village ? pool[spawned % 3 === 2 ? 2 : 1] : pool[choice.idx];
        const enemy = spawnEnemy(
            type,
            x,
            y,
            village ? Math.max(1, player.stage) : spawnLevelForTier(choice.tier),
            { randomizeSpeed: false },
        );
        if (enemy) {
            enemy.trailGuard = true;
            spawned++;
        }
    }
    session.trailEncounterTimer = spawned ? 10 : 2;
}
export { updateTrailEncounters };
