import { canvas, ctx } from '../core/canvas.js';
import { enemies, player } from '../core/state.js';
import {
    drawEnemyProjectiles,
    drawFireZones,
    drawFloatingTexts,
    drawGoldPickups,
    drawMounts,
    drawParticles,
    drawProjectiles,
    drawVisionFog,
    drawWeaponPickups,
} from './effects.js';
import { drawChests, drawEntity, drawNpcs, drawScarecrows } from './entities.js';
import { drawMinimap } from './minimap.js';
import { drawFountain, drawPortals, drawTerrain } from './terrain.js';
import { drawWorldFrame } from './presentation.js';

// ============================================================
//  RENDERING
// ============================================================
function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw terrain
    drawTerrain();

    // Draw fountain
    drawFountain();

    // Draw portals
    drawPortals();

    // Draw fire zones (under entities)
    drawFireZones();

    // Draw particles (under entities)
    drawParticles();

    // Draw projectiles
    drawProjectiles();

    // Draw enemy projectiles
    drawEnemyProjectiles();

    // Draw gold pickups
    drawGoldPickups();

    // Draw weapon pickups
    drawWeaponPickups();

    // Draw chests
    drawChests();

    // Draw mounts
    drawMounts();

    // Draw NPCs
    drawNpcs();

    // Draw scarecrows
    drawScarecrows();

    // Sort a copy so foreground bodies cover background bodies without reordering simulation state.
    const actors = [...enemies.filter((enemy) => enemy.hp > 0), player];
    actors.sort((first, second) => first.y + first.h - second.y - second.h);
    for (const actor of actors) drawEntity(actor);

    drawWorldFrame();

    // Draw floating texts
    drawFloatingTexts();

    // Draw minimap
    drawMinimap();

    // Vision fog when reduced
    if (player.visionReduction > 0) {
        drawVisionFog();
    }
}

export { draw };
