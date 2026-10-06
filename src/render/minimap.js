'use strict';

// ============================================================
//  MINIMAP RENDERING
// ============================================================
function drawMinimap() {
    const mm = document.getElementById('minimap');
    const mmCtx = mm.getContext('2d');
    const mmW = mm.width;
    const mmH = mm.height;
    const scaleX = mmW / (MAP_WIDTH * TILE_SIZE);
    const scaleY = mmH / (MAP_HEIGHT * TILE_SIZE);

    mmCtx.fillStyle = 'rgba(10,10,30,0.85)';
    mmCtx.fillRect(0, 0, mmW, mmH);

    // Draw terrain
    for (let y = 0; y < MAP_HEIGHT; y += 2) {
        for (let x = 0; x < MAP_WIDTH; x += 2) {
            const tileKey = TILE_KEYS[getTile(x, y)];
            mmCtx.fillStyle = TILE_TYPES[tileKey].color;
            mmCtx.fillRect(
                x * TILE_SIZE * scaleX,
                y * TILE_SIZE * scaleY,
                2 * TILE_SIZE * scaleX + 1,
                2 * TILE_SIZE * scaleY + 1,
            );
        }
    }

    // Draw enemies
    for (const e of enemies) {
        if (e.hp <= 0) continue;
        mmCtx.fillStyle = e.isBoss ? '#ff0000' : '#ff6644';
        mmCtx.fillRect(e.x * scaleX - 1, e.y * scaleY - 1, 3, 3);
    }

    // Draw NPCs with quests/shops
    for (const npc of npcs) {
        const availQuests = getAvailableQuests(npc);
        if (availQuests.length === 0 && !npc.isShop && !npc.isDesertTraveler && !npc.isSlotMachine)
            continue;
        const nx = (npc.x + npc.w / 2) * scaleX;
        const ny = (npc.y + npc.h / 2) * scaleY;
        const s = 3.75; // 3/4 of the original marker size
        // Black background square with thick border
        mmCtx.fillStyle = '#000000';
        mmCtx.fillRect(nx - s - 0.75, ny - s - 0.75, s * 2 + 2.25, s * 2 + 2.25);
        mmCtx.strokeStyle = '#ffd700';
        mmCtx.lineWidth = 1.9;
        mmCtx.strokeRect(nx - s - 0.75, ny - s - 0.75, s * 2 + 2.25, s * 2 + 2.25);
        // Bold marker text
        mmCtx.font = `bold 8px sans-serif`;
        mmCtx.textAlign = 'center';
        mmCtx.textBaseline = 'middle';
        if (npc.isShop) {
            mmCtx.fillStyle = '#ffd700';
            mmCtx.fillText('$', nx, ny);
        } else if (npc.isDesertTraveler) {
            mmCtx.fillStyle = '#ffaa44';
            mmCtx.fillText('🐪', nx, ny);
        } else if (npc.isSlotMachine) {
            mmCtx.fillStyle = '#ff66ff';
            mmCtx.fillText('🎰', nx, ny);
        } else {
            mmCtx.fillStyle = '#ffd700';
            mmCtx.fillText('!', nx, ny);
        }
    }

    // Draw player
    mmCtx.fillStyle = '#4fc3f7';
    mmCtx.fillRect(player.x * scaleX - 2, player.y * scaleY - 2, 5, 5);

    // Draw fountain
    mmCtx.fillStyle = '#4db6e8';
    mmCtx.fillRect(FOUNTAIN_CENTER_X * scaleX - 2, FOUNTAIN_CENTER_Y * scaleY - 2, 5, 5);

    // View rect
    mmCtx.strokeStyle = 'rgba(255,255,255,0.4)';
    mmCtx.lineWidth = 1;
    mmCtx.strokeRect(
        camera.x * scaleX,
        camera.y * scaleY,
        canvas.width * scaleX,
        canvas.height * scaleY,
    );
}

// ============================================================
//  INVENTORY UI
