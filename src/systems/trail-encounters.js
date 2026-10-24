import { canAct } from '../core/helpers.js';
import { enemies, player, session } from '../core/state.js';
import { inVillage, VILLAGE } from '../data/village.js';
import {
    chunkCoordinates,
    CHUNK_SIZE,
    CHUNK_ORIGIN_X,
    CHUNK_ORIGIN_Y,
} from '../data/world-chunks.js';
import { ENEMY_TYPES, DESERT_ENEMY_TYPES } from '../data/enemies.js';
import { spawnEnemy } from './spawning.js';

function updateTrailEncounters(deltaTime) {
    if (!session.trailEncountersEnabled || !canAct()) return;
    const village = player.currentRegion === 'forest' && inVillage(player.x, player.y);
    if (village && player.y < VILLAGE.y + VILLAGE.height * 0.4) return;
    if (
        !village &&
        (session.chunkMap !== session.tileMap || session.chunkRegion !== player.currentRegion)
    )
        return;
    const current = chunkCoordinates(player.x, player.y);
    const sameArea = (e) => {
        if (village) return inVillage(e.x, e.y);
        const chunk = chunkCoordinates(e.x, e.y);
        return chunk.column === current.column && chunk.row === current.row;
    };
    session.trailEncounterTimer -= deltaTime;
    if (session.trailEncounterTimer > 0) return;
    const nearby = enemies.filter((e) => e.hp > 0 && sameArea(e)).length;
    if (nearby >= 9 || enemies.filter((e) => e.hp > 0 && !e.isBoss).length >= 40) {
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
        const ports = [
            [0.5, 0.75],
            [0.75, 0.5],
            [0.25, 0.5],
            [0.5, 0.25],
        ];
        let x = VILLAGE.x + VILLAGE.width * (0.5 + dx),
            y = VILLAGE.y + VILLAGE.height * v;
        if (!village) {
            const candidates = ports.map(([u, v]) => ({
                x: CHUNK_ORIGIN_X + current.column * CHUNK_SIZE + u * CHUNK_SIZE,
                y: CHUNK_ORIGIN_Y + current.row * CHUNK_SIZE + v * CHUNK_SIZE,
            }));
            const candidate = candidates[(i + player.stage) % candidates.length];
            x = candidate.x;
            y = candidate.y;
            if (Math.hypot(x - player.x, y - player.y) < 120) continue;
        }
        const pool = player.currentRegion === 'desert' ? DESERT_ENEMY_TYPES : ENEMY_TYPES;
        const enemy = spawnEnemy(pool[i % 3 === 2 ? 2 : 1], x, y, Math.max(1, player.stage), {
            randomizeSpeed: false,
        });
        if (enemy) enemy.trailGuard = true;
    }
    session.trailEncounterTimer = 10;
}
export { updateTrailEncounters };
