import { visibleLandscapeProps, drawLandscapeProp } from './landscape.js';
import { camera, canvas, ctx } from '../core/canvas.js';
import { chests, enemies, mounts, npcs, player } from '../core/state.js';
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

    drawScarecrows();

    // Sort presentation records, never the simulation arrays. Props and people share depth.
    const actors = [
        ...visibleLandscapeProps(camera, canvas).map((entity) => ({ entity, kind: 'landscape' })),
        ...chests.filter((entity) => !entity.opened).map((entity) => ({ entity, kind: 'chest' })),
        ...mounts.map((entity) => ({ entity, kind: 'mount' })),
        ...npcs.map((entity) => ({ entity, kind: 'npc' })),
        ...enemies.filter((entity) => entity.hp > 0).map((entity) => ({ entity, kind: 'actor' })),
        { entity: player, kind: 'actor' },
    ];
    actors.sort(
        (first, second) => first.entity.y + first.entity.h - second.entity.y - second.entity.h,
    );
    for (const { entity, kind } of actors) {
        if (kind === 'landscape') drawLandscapeProp(ctx, camera, entity);
        else if (kind === 'chest') drawChests([entity]);
        else if (kind === 'mount') drawMounts([entity]);
        else if (kind === 'npc') drawNpcs([entity]);
        else drawEntity(entity);
    }

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
