'use strict';

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

    // Draw enemies
    for (const enemy of enemies) {
        if (enemy.hp <= 0) continue;
        drawEntity(enemy);
    }

    // Draw player
    drawEntity(player);

    // Draw floating texts
    drawFloatingTexts();

    // Draw minimap
    drawMinimap();

    // Vision fog when reduced
    if (player.visionReduction > 0) {
        drawVisionFog();
    }
}
