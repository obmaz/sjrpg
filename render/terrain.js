// ============================================================
//  TERRAIN RENDERING
// ============================================================
function drawTerrain() {
    const startTX = Math.max(0, Math.floor(camera.x / TILE_SIZE) - 1);
    const startTY = Math.max(0, Math.floor(camera.y / TILE_SIZE) - 1);
    const endTX = Math.min(MAP_W, Math.ceil((camera.x + canvas.width) / TILE_SIZE) + 1);
    const endTY = Math.min(MAP_H, Math.ceil((camera.y + canvas.height) / TILE_SIZE) + 1);
    const time = performance.now() / 1000;

    for (let ty = startTY; ty < endTY; ty++) {
        for (let tx = startTX; tx < endTX; tx++) {
            const tileKey = TILE_KEYS[getTile(tx, ty)];
            const tile = TILE[tileKey];
            const screenX = tx * TILE_SIZE - camera.x;
            const screenY = ty * TILE_SIZE - camera.y;
            const seed = tx * 374761393 + ty * 668265263;

            // --- SHORELINE / EDGE DETECTION for solid tiles ---
            const solid = TILE[tileKey].solid;
            const nTop = getTile(tx, ty - 1); const nBot = getTile(tx, ty + 1);
            const nLef = getTile(tx - 1, ty); const nRig = getTile(tx + 1, ty);
            const topWalk = !TILE[TILE_KEYS[nTop]].solid;
            const botWalk = !TILE[TILE_KEYS[nBot]].solid;
            const lefWalk = !TILE[TILE_KEYS[nLef]].solid;
            const rigWalk = !TILE[TILE_KEYS[nRig]].solid;
            const hasWalkNeighbor = solid && (topWalk || botWalk || lefWalk || rigWalk);

            if (tileKey === 'GRASS' || tileKey === 'GRASS_TALL') {
                const isTall = tileKey === 'GRASS_TALL';
                ctx.fillStyle = isTall ? '#58b038' : '#78c858';
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);
                ctx.fillStyle = isTall ? '#489830' : '#68b048';
                ctx.fillRect(screenX, screenY, TILE_SIZE - 2, TILE_SIZE - 2);
                ctx.fillStyle = isTall ? '#58b038' : '#78c858';
                ctx.fillRect(screenX + 2, screenY + 2, TILE_SIZE - 4, TILE_SIZE - 4);
                ctx.fillStyle = isTall ? 'rgba(0,0,0,0.12)' : 'rgba(0,0,0,0.07)';
                for (let i = 0; i < 4; i++) {
                    const gx = screenX + 4 + ((seed + i * 137) % 24);
                    const gy = screenY + 6 + ((seed >> (i * 3 + 1)) & 0xF);
                    ctx.fillRect(gx, gy, 2, 5);
                    ctx.fillRect(gx + 2, gy - 1, 1, 4);
                }
                if ((seed & 7) === 0) {
                    ctx.fillStyle = isTall ? 'rgba(255,255,255,0.04)' : 'rgba(255,255,255,0.06)';
                    ctx.fillRect(screenX + (seed & 0xF), screenY + ((seed >> 4) & 0xF), 8, 8);
                }
            } else if (tileKey === 'DIRT' || tileKey === 'PATH') {
                ctx.fillStyle = tileKey === 'PATH' ? '#d4c080' : '#c8a870';
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);
                ctx.fillStyle = tileKey === 'PATH' ? '#c4b068' : '#b89858';
                ctx.fillRect(screenX + 1, screenY + 1, TILE_SIZE - 2, TILE_SIZE - 2);
                ctx.fillStyle = tileKey === 'PATH' ? '#d4c080' : '#c8a870';
                ctx.fillRect(screenX + 2, screenY + 2, TILE_SIZE - 4, TILE_SIZE - 4);
                ctx.fillStyle = 'rgba(0,0,0,0.08)';
                if ((seed & 3) === 0) {
                    ctx.fillRect(screenX + 6 + (seed % 16), screenY + 10 + ((seed >> 4) % 12), 3, 2);
                }
            } else if (tileKey === 'SAND') {
                ctx.fillStyle = '#e8d5a0';
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);
                ctx.fillStyle = '#dcc890';
                ctx.fillRect(screenX + 1, screenY + 1, TILE_SIZE - 2, TILE_SIZE - 2);
                ctx.fillStyle = '#e8d5a0';
                ctx.fillRect(screenX + 2, screenY + 2, TILE_SIZE - 4, TILE_SIZE - 4);
                if ((seed & 3) === 0) {
                    ctx.fillStyle = 'rgba(255,255,255,0.1)';
                    ctx.fillRect(screenX + (seed % 20), screenY + ((seed >> 4) % 20), 3, 3);
                }
            } else if (tileKey === 'WATER' || tileKey === 'WATER_DEEP') {
                const isDeep = tileKey === 'WATER_DEEP';
                const nTopK = TILE_KEYS[getTile(tx, ty - 1)];
                const nBotK = TILE_KEYS[getTile(tx, ty + 1)];
                const nLefK = TILE_KEYS[getTile(tx - 1, ty)];
                const nRigK = TILE_KEYS[getTile(tx + 1, ty)];
                const topWater = nTopK === 'WATER' || nTopK === 'WATER_DEEP';
                const botWater = nBotK === 'WATER' || nBotK === 'WATER_DEEP';
                const lefWater = nLefK === 'WATER' || nLefK === 'WATER_DEEP';
                const rigWater = nRigK === 'WATER' || nRigK === 'WATER_DEEP';
                const allWater = topWater && botWater && lefWater && rigWater;

                // Core water color fills the whole tile
                const coreColor = isDeep ? '#185888' : '#2878b8';
                ctx.fillStyle = coreColor;
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);

                // Only draw darker edges where water meets land
                if (!allWater) {
                    const edgeColor = isDeep ? '#0d3868' : '#185898';
                    ctx.fillStyle = edgeColor;
                    if (!topWater) ctx.fillRect(screenX, screenY, TILE_SIZE, 3);
                    if (!botWater) ctx.fillRect(screenX, screenY + TILE_SIZE - 3, TILE_SIZE, 3);
                    if (!lefWater) ctx.fillRect(screenX, screenY, 3, TILE_SIZE);
                    if (!rigWater) ctx.fillRect(screenX + TILE_SIZE - 3, screenY, 3, TILE_SIZE);
                }

                // Water shimmer
                const shimmer = Math.sin(time * 3 + tx * 0.5 + ty * 0.5) * 0.5 + 0.5;
                ctx.fillStyle = `rgba(255,255,255,${0.06 + shimmer * 0.08})`;
                ctx.fillRect(screenX + 4, screenY + 8, TILE_SIZE - 8, 2);
                ctx.fillRect(screenX + 6, screenY + 18, TILE_SIZE - 12, 2);

                // Shoreline foam edges
                if (hasWalkNeighbor) {
                    const foamAlpha = 0.25 + Math.sin(time * 4 + tx + ty) * 0.08;
                    ctx.fillStyle = `rgba(255,255,255,${foamAlpha})`;
                    if (topWalk) ctx.fillRect(screenX + 3, screenY, TILE_SIZE - 6, 4);
                    if (botWalk) ctx.fillRect(screenX + 3, screenY + TILE_SIZE - 4, TILE_SIZE - 6, 4);
                    if (lefWalk) ctx.fillRect(screenX, screenY + 3, 4, TILE_SIZE - 6);
                    if (rigWalk) ctx.fillRect(screenX + TILE_SIZE - 4, screenY + 3, 4, TILE_SIZE - 6);
                }
            } else if (tileKey === 'WALL') {
                // Stone wall - distinctly solid
                ctx.fillStyle = '#585850';
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);
                ctx.fillStyle = '#686860';
                ctx.fillRect(screenX + 1, screenY + 1, TILE_SIZE - 2, TILE_SIZE - 2);
                // Brick pattern
                for (let by = 0; by < 3; by++) {
                    const off = (by % 2) * 6;
                    for (let bx = 0; bx < 3; bx++) {
                        ctx.fillStyle = '#505048';
                        ctx.fillRect(screenX + 3 + bx * 10 + off, screenY + 4 + by * 10, 8, 8);
                        ctx.fillStyle = '#606058';
                        ctx.fillRect(screenX + 4 + bx * 10 + off, screenY + 5 + by * 10, 6, 6);
                    }
                }
                // Mortar lines
                ctx.fillStyle = '#484840';
                for (let by = 1; by < 3; by++) {
                    ctx.fillRect(screenX + 2, screenY + 3 + by * 10 - 2, TILE_SIZE - 4, 2);
                }
            } else if (tileKey === 'TREE') {
                // Grass base
                ctx.fillStyle = '#78c858';
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);
                const tcx = screenX + 16;
                const sway = (seed % 5) - 2; // -2..2px crown variation per tile

                // Shadow under tree
                ctx.fillStyle = 'rgba(0,0,0,0.22)';
                ctx.beginPath();
                ctx.ellipse(tcx, screenY + 28, 12, 4, 0, 0, Math.PI * 2);
                ctx.fill();

                // Tapered trunk (wider at the base)
                ctx.fillStyle = '#5a3a22';
                ctx.beginPath();
                ctx.moveTo(screenX + 12, screenY + 29);
                ctx.lineTo(screenX + 14, screenY + 15);
                ctx.lineTo(screenX + 18, screenY + 15);
                ctx.lineTo(screenX + 20, screenY + 29);
                ctx.closePath();
                ctx.fill();
                // a small forked branch + bark highlight
                ctx.strokeStyle = '#5a3a22'; ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(tcx, screenY + 18); ctx.lineTo(screenX + 21, screenY + 13);
                ctx.moveTo(tcx, screenY + 20); ctx.lineTo(screenX + 11, screenY + 15);
                ctx.stroke();
                ctx.fillStyle = '#714c2c';
                ctx.fillRect(screenX + 15, screenY + 16, 2, 13);

                // Lumpy canopy: overlapping lobes → bushy, wider-than-tall crown
                const lobes = [
                    [tcx + sway,     screenY + 10, 8],
                    [tcx - 7,        screenY + 12, 5.5],
                    [tcx + 7,        screenY + 12, 5.5],
                    [tcx - 4 + sway, screenY + 6,  5.5],
                    [tcx + 4 + sway, screenY + 6,  5],
                    [tcx + sway,     screenY + 3,  4],
                ];
                ctx.fillStyle = '#1d5418'; // dark base / outline
                for (const [lx, ly, r] of lobes) { ctx.beginPath(); ctx.arc(lx, ly, r + 1, 0, Math.PI * 2); ctx.fill(); }
                ctx.fillStyle = '#2f7a26'; // mid foliage
                for (const [lx, ly, r] of lobes) { ctx.beginPath(); ctx.arc(lx, ly, r, 0, Math.PI * 2); ctx.fill(); }
                ctx.fillStyle = '#46a834'; // sunlit highlights (upper-left of each lobe)
                for (const [lx, ly, r] of lobes) { ctx.beginPath(); ctx.arc(lx - r * 0.35, ly - r * 0.4, r * 0.5, 0, Math.PI * 2); ctx.fill(); }
                // a couple of bright leaf dabs for texture
                ctx.fillStyle = '#64c44a';
                ctx.beginPath(); ctx.arc(tcx - 3 + sway, screenY + 5, 1.6, 0, Math.PI * 2); ctx.fill();
                ctx.beginPath(); ctx.arc(tcx + 4 + sway, screenY + 9, 1.4, 0, Math.PI * 2); ctx.fill();
            } else if (tileKey === 'BUSH') {
                ctx.fillStyle = '#78c858';
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);
                // Shadow
                ctx.fillStyle = 'rgba(0,0,0,0.2)';
                ctx.beginPath();
                ctx.ellipse(screenX + 16, screenY + 24, 10, 4, 0, 0, Math.PI * 2);
                ctx.fill();
                // Dark outline
                ctx.fillStyle = '#205018';
                ctx.beginPath();
                ctx.arc(screenX + 16, screenY + 15, 13, 0, Math.PI * 2);
                ctx.fill();
                // Bush body
                ctx.fillStyle = '#307820';
                ctx.beginPath();
                ctx.arc(screenX + 16, screenY + 15, 11, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = '#409028';
                ctx.beginPath();
                ctx.arc(screenX + 13, screenY + 13, 7, 0, Math.PI * 2);
                ctx.fill();
            } else if (tileKey === 'ROCK') {
                ctx.fillStyle = '#78c858';
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);
                // Shadow
                ctx.fillStyle = 'rgba(0,0,0,0.25)';
                const rx = screenX + 8 + (seed % 8);
                const ry = screenY + 14 + ((seed >> 4) % 6);
                const rr = 9 + ((seed >> 8) % 5);
                ctx.beginPath();
                ctx.ellipse(rx + 1, ry + rr, rr - 1, 3, 0, 0, Math.PI * 2);
                ctx.fill();
                // Dark outline
                ctx.fillStyle = '#484848';
                ctx.beginPath();
                ctx.arc(rx, ry, rr + 1, 0, Math.PI * 2);
                ctx.fill();
                // Rock body
                ctx.fillStyle = '#707870';
                ctx.beginPath();
                ctx.arc(rx, ry, rr, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = '#889088';
                ctx.beginPath();
                ctx.arc(rx - 2, ry - 2, rr * 0.45, 0, Math.PI * 2);
                ctx.fill();
            } else if (tileKey === 'FLOWER') {
                ctx.fillStyle = '#78c858';
                ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);
                ctx.fillStyle = '#58b038';
                ctx.fillRect(screenX + 14, screenY + 18, 2, 10);
                ctx.fillStyle = '#e85078';
                ctx.beginPath();
                ctx.arc(screenX + 15, screenY + 16, 5, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = '#ff7098';
                ctx.beginPath();
                ctx.arc(screenX + 15, screenY + 16, 3, 0, Math.PI * 2);
                ctx.fill();
            }

            // Subtle tile grid (skip water for seamless look)
            if (tileKey !== 'WATER' && tileKey !== 'WATER_DEEP') {
                ctx.strokeStyle = 'rgba(0,0,0,0.05)';
                ctx.strokeRect(screenX + 0.5, screenY + 0.5, TILE_SIZE - 1, TILE_SIZE - 1);
            }
        }
    }
}

// ============================================================
//  FOUNTAIN RENDERING
// ============================================================

function drawFountain() {
    const sx = FOUNTAIN_CX - camera.x;
    const sy = FOUNTAIN_CY - camera.y;

    if (sx < -120 || sx > canvas.width + 120 || sy < -120 || sy > canvas.height + 120) return;

    const time = performance.now() / 1000;

    // Large fountain base (stone ring) - enlarged
    ctx.fillStyle = '#7d7d8a';
    ctx.beginPath();
    ctx.ellipse(sx, sy + 14, 52, 18, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#90909a';
    ctx.beginPath();
    ctx.ellipse(sx, sy + 11, 46, 15, 0, 0, Math.PI * 2);
    ctx.fill();

    // Water in basin - larger
    ctx.fillStyle = '#4db6e8';
    ctx.beginPath();
    ctx.ellipse(sx, sy + 8, 40, 13, 0, 0, Math.PI * 2);
    ctx.fill();

    // Water shimmer
    ctx.fillStyle = 'rgba(255,255,255,0.15)';
    ctx.beginPath();
    ctx.ellipse(sx - 10, sy + 5, 10, 4, 0, 0, Math.PI * 2);
    ctx.fill();

    // Central pillar - larger
    ctx.fillStyle = '#a0a0aa';
    ctx.fillRect(sx - 8, sy - 22, 16, 32);
    ctx.fillStyle = '#b0b0ba';
    ctx.fillRect(sx - 5, sy - 20, 10, 28);

    // Top basin - larger
    ctx.fillStyle = '#90909a';
    ctx.beginPath();
    ctx.ellipse(sx, sy - 24, 18, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#4db6e8';
    ctx.beginPath();
    ctx.ellipse(sx, sy - 26, 14, 5, 0, 0, Math.PI * 2);
    ctx.fill();

    // Water streams (animated) - more streams
    for (let i = 0; i < 6; i++) {
        const a = (i / 6) * Math.PI * 2 + time * 0.5;
        const rx = 14 + Math.sin(time * 2 + i) * 3;
        ctx.strokeStyle = 'rgba(100,200,255,0.6)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(sx + Math.cos(a) * 6, sy - 19);
        ctx.quadraticCurveTo(
            sx + Math.cos(a) * rx, sy - 8,
            sx + Math.cos(a + 0.2) * 24, sy + 4
        );
        ctx.stroke();
    }

    // Splash particles at base
    if (Math.random() < 0.7) {
        const splashCount = 2 + Math.floor(Math.random() * 3);
        for (let i = 0; i < splashCount; i++) {
            const a = Math.random() * Math.PI * 2;
            const r = 30 + Math.random() * 30;
            particles.push({
                x: FOUNTAIN_CX + Math.cos(a) * r,
                y: FOUNTAIN_CY + 10,
                vx: Math.cos(a) * (10 + Math.random() * 30),
                vy: -20 - Math.random() * 40,
                life: 0.3 + Math.random() * 0.2,
                maxLife: 0.5,
                color: '#88ccff',
                size: 1.5 + Math.random() * 3,
            });
        }
    }

    // Heal glow when player nearby (costs gold)
    const dist = distance(player.x + player.w / 2, player.y + player.h / 2, FOUNTAIN_CX, FOUNTAIN_CY);
    if (dist < 180 && player.hp < player.maxHp && player.gold > 0) {
        const glowAlpha = 0.15 + Math.sin(time * 3) * 0.05;
        ctx.fillStyle = `rgba(255,180,100,${glowAlpha})`;
        ctx.beginPath();
        ctx.arc(sx, sy, 50, 0, Math.PI * 2);
        ctx.fill();

        // Cost particles
        if (Math.random() < 0.5) {
            particles.push({
                x: player.x + player.w / 2 + (Math.random() - 0.5) * 20,
                y: player.y - 5,
                vx: (Math.random() - 0.5) * 20,
                vy: -20 - Math.random() * 30,
                life: 0.4 + Math.random() * 0.3,
                maxLife: 0.7,
                color: '#ffaa66',
                size: 2 + Math.random() * 3,
            });
        }
    } else if (dist < 180 && player.hp < player.maxHp && player.gold <= 0) {
        // No gold - show red indicator
        if (Math.floor(time * 2) % 2 === 0) {
            ctx.fillStyle = '#fff';
            ctx.font = 'bold 11px sans-serif'; ctx.textAlign = 'center';
            ctx.fillText('💰 부족!', sx, sy - 40);
        }
    }
}

// ============================================================
//  PORTAL RENDERING
// ============================================================
function drawPortals() {
    for (const p of portals) {
        const sx = p.x - camera.x;
        const sy = p.y - camera.y;
        if (sx < -80 || sx > canvas.width + 80 || sy < -80 || sy > canvas.height + 80) continue;

        const time = p.animTimer;
        const pulse = 1 + Math.sin(time * 3) * 0.15;

        // Outer glow ring
        ctx.save();
        ctx.globalAlpha = 0.3 + Math.sin(time * 2) * 0.1;
        const outerGrad = ctx.createRadialGradient(sx + p.w/2, sy + p.h/2, 10, sx + p.w/2, sy + p.h/2, 45 * pulse);
        outerGrad.addColorStop(0, '#8844ff');
        outerGrad.addColorStop(0.5, '#6644cc');
        outerGrad.addColorStop(1, 'transparent');
        ctx.fillStyle = outerGrad;
        ctx.beginPath();
        ctx.arc(sx + p.w/2, sy + p.h/2, 45 * pulse, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();

        // Portal vortex (rotating rings)
        for (let i = 0; i < 3; i++) {
            const r = 15 + i * 8;
            const rot = time * (1.5 + i * 0.5) + i * 2;
            ctx.save();
            ctx.globalAlpha = 0.5 - i * 0.12;
            ctx.strokeStyle = i === 0 ? '#aa77ff' : (i === 1 ? '#8855dd' : '#6644bb');
            ctx.lineWidth = 3 - i * 0.5;
            ctx.beginPath();
            ctx.ellipse(sx + p.w/2, sy + p.h/2, r * pulse, r * 0.5 * pulse, rot, 0, Math.PI * 2);
            ctx.stroke();
            ctx.restore();
        }

        // Center bright core
        const coreGrad = ctx.createRadialGradient(sx + p.w/2, sy + p.h/2, 1, sx + p.w/2, sy + p.h/2, 10 * pulse);
        coreGrad.addColorStop(0, '#ffffff');
        coreGrad.addColorStop(0.3, '#ddaaff');
        coreGrad.addColorStop(1, 'transparent');
        ctx.fillStyle = coreGrad;
        ctx.beginPath();
        ctx.arc(sx + p.w/2, sy + p.h/2, 10 * pulse, 0, Math.PI * 2);
        ctx.fill();

        // Sparkle particles
        for (let i = 0; i < 5; i++) {
            const a = time * 3 + i * Math.PI * 2 / 5;
            const r = 12 + Math.sin(time * 4 + i) * 5;
            const px = sx + p.w/2 + Math.cos(a) * r;
            const py = sy + p.h/2 + Math.sin(a) * r * 0.4;
            ctx.fillStyle = '#ffffff';
            ctx.globalAlpha = 0.6 + Math.sin(time * 6 + i) * 0.3;
            ctx.beginPath();
            ctx.arc(px, py, 2, 0, Math.PI * 2);
            ctx.fill();
        }

        // Label
        ctx.fillStyle = '#ddaaff';
        ctx.font = 'bold 12px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('🌀 사막 포탈 [E]', sx + p.w/2, sy - 12);
    }
}

// ============================================================
//  FIRE ZONE RENDERING
// ============================================================
