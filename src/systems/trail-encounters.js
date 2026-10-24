import { canAct } from '../core/helpers.js';
import { enemies, player, session } from '../core/state.js';
import { inVillage, VILLAGE } from '../data/village.js';
import { ENEMY_TYPES } from '../data/enemies.js';
import { spawnEnemy } from './spawning.js';

function updateTrailEncounters(deltaTime) {
    if (!session.trailEncountersEnabled || !canAct() || player.currentRegion !== 'forest') return;
    if (!inVillage(player.x, player.y) || player.y < VILLAGE.y + VILLAGE.height * 0.4) return;
    session.trailEncounterTimer -= deltaTime;
    if (session.trailEncounterTimer > 0) return;
    const nearby = enemies.filter((e) => e.hp > 0 && inVillage(e.x, e.y)).length;
    if (nearby >= 9) {
        session.trailEncounterTimer = 2;
        return;
    }
    const positions = [
        [-0.08, 0.64],
        [0.1, 0.68],
        [-0.02, 0.78],
        [0.18, 0.72],
    ];
    const count = Math.min(nearby === 0 ? 3 : 2, 9 - nearby);
    for (let i = 0; i < count; i++) {
        const [dx, v] = positions[(i + player.stage) % positions.length];
        const enemy = spawnEnemy(
            ENEMY_TYPES[i % 3 === 2 ? 2 : 1],
            VILLAGE.x + VILLAGE.width * (0.5 + dx),
            VILLAGE.y + VILLAGE.height * v,
            Math.max(1, player.stage),
            { randomizeSpeed: false },
        );
        if (enemy) enemy.trailGuard = true;
    }
    session.trailEncounterTimer = 10;
}
export { updateTrailEncounters };
