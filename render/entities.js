// ============================================================
//  ENTITY RENDERING (enemies, player, NPCs, chests, pickups, mounts)
// ============================================================
function drawNPCs() {
    for (const npc of npcs) {
        const sx = npc.x - camera.x, sy = npc.y - camera.y;
        // Glow effect for quest-givers
        const availQuests = QUESTS.filter(q => npc.quests.includes(q.id) && isQuestAvailable(q, player));
        const hasQuest = availQuests.length > 0;
        if (hasQuest || npc.isShop || npc.isDesertTraveler || npc.isSlotMachine || npc.isStylist) {
            let glowColor;
            if (npc.isDesertTraveler) glowColor = 'rgba(255,180,80,';
            else if (npc.isSlotMachine) glowColor = 'rgba(255,100,255,';
            else if (npc.isStylist) glowColor = 'rgba(170,136,255,';
            else if (npc.isShop) glowColor = 'rgba(255,215,0,';
            else glowColor = 'rgba(255,215,0,';
            const glowAlpha = 0.25 + Math.sin(performance.now() / 500) * 0.12;
            ctx.fillStyle = glowColor + glowAlpha + ')';
            ctx.beginPath(); ctx.arc(sx + npc.w/2, sy + npc.h/2, 26, 0, Math.PI * 2); ctx.fill();
        }
        ctx.fillStyle = 'rgba(0,0,0,0.45)';
        ctx.beginPath(); ctx.ellipse(sx + npc.w/2, sy + npc.h, npc.w/2 + 2, 6, 0, 0, Math.PI * 2); ctx.fill();

        // ── Draw human body shape ──
        const isShopNPC = npc.isShop;
        const bodySize = isShopNPC ? 1.6 : 1.0;
        const bx = sx + npc.w/2, by = sy + npc.h/2;
        // Legs
        ctx.fillStyle = '#4a3020';
        ctx.fillRect(bx - 4 * bodySize, by + 2 * bodySize, 3 * bodySize, 7 * bodySize);
        ctx.fillRect(bx + 1 * bodySize, by + 2 * bodySize, 3 * bodySize, 7 * bodySize);
        // Body
        ctx.fillStyle = isShopNPC ? '#886644' : '#5a4a8a';
        ctx.beginPath();
        ctx.roundRect(bx - 7 * bodySize, by - 2 * bodySize, 14 * bodySize, 10 * bodySize, 3);
        ctx.fill();
        // Arms
        ctx.fillStyle = '#d8c098';
        ctx.fillRect(bx - 10 * bodySize, by - 1 * bodySize, 4 * bodySize, 8 * bodySize);
        ctx.fillRect(bx + 6 * bodySize, by - 1 * bodySize, 4 * bodySize, 8 * bodySize);
        // Head
        ctx.fillStyle = '#f0d8b0';
        ctx.beginPath();
        ctx.arc(bx, by - 5 * bodySize, 6 * bodySize, 0, Math.PI * 2);
        ctx.fill();

        // Face icon on head
        ctx.font = `${bodySize * 18}px sans-serif`; ctx.textAlign = 'center';
        ctx.fillText(npc.icon, bx, by - 5 * bodySize);
        // Quest indicator
        if (hasQuest) {
            ctx.fillStyle = '#ffd700';
            ctx.font = 'bold 14px sans-serif';
            ctx.fillText('❗', sx + npc.w/2, sy - 4);
        }
        // Shop indicator
        if (npc.isShop) {
            ctx.fillStyle = '#ffd700';
            ctx.font = 'bold 12px sans-serif';
            ctx.fillText('💰', sx + npc.w/2, sy - 4);
        }
        // Desert traveler indicator
        if (npc.isDesertTraveler) {
            ctx.fillStyle = '#ffaa44';
            ctx.font = 'bold 12px sans-serif';
            ctx.fillText('🏜️', sx + npc.w/2, sy - 4);
        }
        // Slot machine indicator
        if (npc.isSlotMachine) {
            ctx.fillStyle = '#ff66ff';
            ctx.font = 'bold 12px sans-serif';
            ctx.fillText('🎰', sx + npc.w/2, sy - 4);
        }
        // Stylist indicator
        if (npc.isStylist) {
            ctx.fillStyle = '#aa88ff';
            ctx.font = 'bold 12px sans-serif';
            ctx.fillText('💈', sx + npc.w/2, sy - 4);
        }
        // Interaction hint
        const dist = distance(player.x + player.w/2, player.y + player.h/2, npc.x + npc.w/2, npc.y + npc.h/2);
        if (dist < 50) {
            ctx.fillStyle = '#fff';
            ctx.font = 'bold 10px sans-serif';
            ctx.fillText(npc.isShop ? '[E] 상점' : (npc.isSlotMachine ? '[E] 뽑기' : (npc.isStylist ? '[E] 외관변경' : (npc.isDesertTraveler ? '[E] 여행' : '[E] 대화'))), sx + npc.w/2, sy - 16);
        }
    }
}

// Classic wooden treasure chest: domed plank lid, iron bands with rivets, gold padlock.
// Scales to any cw/ch so both the small wooden and big iron chests share one look.
function drawChestSprite(x, y, w, h, isIron) {
    const out = '#3a2412';                                   // thick cartoon outline
    const band = '#7d8896', bandDk = '#515c6c';              // iron band
    const rivet = '#cfd9e6', rivetDk = '#2f3a49';            // studs
    const px = Math.max;                                     // floor helper

    const lidH = h * 0.5;
    const midY = y + lidH * 0.82;                            // lid/body seam (under middle band)
    const lidR = px(3, w * 0.16);

    // rivet row along a horizontal band
    const rivetsRow = (yy) => {
        const n = px(2, Math.round(w / 11));
        const rr = px(1.2, w * 0.035);
        for (let i = 0; i < n; i++) {
            const rxp = x + (i + 0.5) * (w / n);
            ctx.fillStyle = rivetDk; ctx.beginPath(); ctx.arc(rxp, yy, rr, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = rivet;   ctx.beginPath(); ctx.arc(rxp - rr * 0.25, yy - rr * 0.25, rr * 0.55, 0, Math.PI * 2); ctx.fill();
        }
    };

    // ground shadow
    ctx.fillStyle = 'rgba(0,0,0,0.28)';
    ctx.beginPath(); ctx.ellipse(x + w / 2, y + h + 2, w * 0.5, px(3, h * 0.1), 0, 0, Math.PI * 2); ctx.fill();

    // ===== BODY =====
    ctx.fillStyle = out;
    ctx.beginPath(); ctx.roundRect(x - 1, midY - 1, w + 2, (y + h) - midY + 1, px(3, w * 0.1)); ctx.fill();
    ctx.fillStyle = '#7a4f28';
    ctx.beginPath(); ctx.roundRect(x + 1, midY + 1, w - 2, (y + h) - midY - 2, px(2, w * 0.08)); ctx.fill();
    ctx.fillStyle = '#8a5d31';                               // plank highlight
    ctx.fillRect(x + 2, midY + 2, w - 4, px(2, h * 0.06));
    // wood grain (a couple of darker horizontal cracks)
    ctx.fillStyle = 'rgba(48,28,12,0.5)';
    ctx.fillRect(x + 3, midY + (y + h - midY) * 0.45, w - 6, px(1, h * 0.02));
    // bottom iron band + rivets
    const bbY = y + h - px(5, h * 0.16);
    ctx.fillStyle = bandDk; ctx.fillRect(x - 1, bbY, w + 2, px(4, h * 0.15));
    ctx.fillStyle = band;   ctx.fillRect(x - 1, bbY + 1, w + 2, px(2, h * 0.07));
    rivetsRow(bbY + px(2.5, h * 0.07));

    // ===== LID (domed) =====
    ctx.fillStyle = out;
    ctx.beginPath(); ctx.roundRect(x - 1, y - 1, w + 2, lidH + 2, lidR); ctx.fill();
    ctx.fillStyle = '#9c6730';
    ctx.beginPath(); ctx.roundRect(x + 1, y + 1, w - 2, lidH, lidR - 1); ctx.fill();
    ctx.fillStyle = '#b27c3c';                               // sunlit upper dome
    ctx.beginPath(); ctx.roundRect(x + 2, y + 2, w - 4, lidH * 0.55, lidR - 2); ctx.fill();
    ctx.fillStyle = '#d2a256';                               // top sheen band
    ctx.beginPath(); ctx.roundRect(x + 3, y + 2, w - 6, px(3, lidH * 0.22), lidR - 2); ctx.fill();
    // lid plank seams (vertical)
    ctx.strokeStyle = 'rgba(48,28,12,0.45)'; ctx.lineWidth = px(1, w * 0.02);
    for (let i = 1; i < 3; i++) {
        const lxp = x + (w * i / 3);
        ctx.beginPath(); ctx.moveTo(lxp, y + 2); ctx.lineTo(lxp, midY - 1); ctx.stroke();
    }
    // middle iron band (over the seam) + rivets
    const mbY = midY - px(3, h * 0.07);
    ctx.fillStyle = bandDk; ctx.fillRect(x - 1, mbY, w + 2, px(4, h * 0.14));
    ctx.fillStyle = band;   ctx.fillRect(x - 1, mbY + 1, w + 2, px(2, h * 0.07));
    rivetsRow(mbY + px(2.5, h * 0.07));
    // corner iron brackets on the two top corners of the lid
    [[x + px(4, w * 0.12), y + px(4, lidH * 0.3)], [x + w - px(4, w * 0.12), y + px(4, lidH * 0.3)]].forEach(([bx, by]) => {
        ctx.fillStyle = bandDk; ctx.beginPath(); ctx.arc(bx, by, px(2.5, w * 0.075), 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = band;   ctx.beginPath(); ctx.arc(bx, by, px(1.6, w * 0.05), 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = rivet;  ctx.beginPath(); ctx.arc(bx - 0.5, by - 0.5, px(0.7, w * 0.02), 0, Math.PI * 2); ctx.fill();
    });

    // ===== GOLD PADLOCK (center, over the middle band) =====
    const lx = x + w / 2;
    const lockW = px(8, w * 0.28), lockH = px(8, h * 0.3);
    const lockY = mbY + px(1, h * 0.01);
    // shackle arch
    ctx.lineWidth = px(2, w * 0.06); ctx.strokeStyle = '#b8860b';
    ctx.beginPath(); ctx.arc(lx, lockY, lockW * 0.3, Math.PI, 0); ctx.stroke();
    ctx.lineWidth = px(1, w * 0.025); ctx.strokeStyle = '#ffe070';
    ctx.beginPath(); ctx.arc(lx, lockY, lockW * 0.3, Math.PI, 0); ctx.stroke();
    // lock body
    ctx.fillStyle = '#8a6608'; ctx.beginPath(); ctx.roundRect(lx - lockW / 2, lockY, lockW, lockH, px(2, w * 0.05)); ctx.fill();
    ctx.fillStyle = '#f0c83a'; ctx.beginPath(); ctx.roundRect(lx - lockW / 2 + 1, lockY + 1, lockW - 2, lockH - 2, px(1.5, w * 0.04)); ctx.fill();
    ctx.fillStyle = '#ffe478'; ctx.beginPath(); ctx.roundRect(lx - lockW / 2 + 2, lockY + 2, px(2, lockW * 0.32), lockH - 4, px(1, w * 0.03)); ctx.fill();
    // keyhole
    ctx.fillStyle = '#6e5208';
    ctx.beginPath(); ctx.arc(lx, lockY + lockH * 0.42, px(1.3, lockW * 0.14), 0, Math.PI * 2); ctx.fill();
    ctx.fillRect(lx - px(0.7, lockW * 0.06), lockY + lockH * 0.42, px(1.4, lockW * 0.12), lockH * 0.34);
}

function drawChests() {
    for (const c of chests) {
        if (c.opened) continue;
        const sx = c.x - camera.x, sy = c.y - camera.y;
        const cw = c.w, ch = c.h;
        const isIron = c.chestData && c.chestData.id === 'iron';

        // Rare (iron) chest gets a soft golden glow aura.
        if (isIron) {
            const t = performance.now() / 1000;
            ctx.fillStyle = `rgba(255,215,0,${0.12 + Math.sin(t * 2) * 0.05})`;
            ctx.beginPath(); ctx.roundRect(sx - 8, sy - 8, cw + 16, ch + 16, 12); ctx.fill();
        }

        drawChestSprite(sx, sy, cw, ch, isIron);

        // HP bar when damaged
        if (c.hp < c.maxHp) {
            const barW = cw, barH = 4;
            ctx.fillStyle = '#333';
            ctx.fillRect(sx, sy - 9, barW, barH);
            ctx.fillStyle = isIron ? '#ffd700' : '#d2a256';
            ctx.fillRect(sx, sy - 9, barW * (c.hp / c.maxHp), barH);
        }
    }
}

function drawEntity(entity) {
    const screenX = entity.x - camera.x;
    const screenY = entity.y - camera.y;

    // Skip if off screen
    if (screenX + entity.w < -50 || screenX > canvas.width + 50 ||
        screenY + entity.h < -50 || screenY > canvas.height + 50) return;

    ctx.save();

    // Hurt flash
    if (entity.hurtTimer > 0 && entity.hurtTimer % 0.1 < 0.05) {
        ctx.globalAlpha = 0.5;
    }

    // Invincibility flash (player)
    if (entity === player && player.invincible > 0 && Math.floor(player.invincible * 10) % 2 === 0) {
        ctx.globalAlpha = 0.4;
    }

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.beginPath();
    ctx.ellipse(screenX + entity.w / 2, screenY + entity.h - 3, entity.w / 2, 4, 0, 0, Math.PI * 2);
    ctx.fill();

    const cx = screenX + entity.w / 2;
    const cy = screenY + entity.h / 2;
    const isPlayer = entity === player;

    if (isPlayer) {
        drawPlayerShape(cx, cy, entity);
    } else {
        drawEnemyShape(cx, cy, entity);
    }

    // HP bar (enemies)
    if (!isPlayer && entity.maxHp > 0 && entity.hp < entity.maxHp) {
        const barW = entity.w + 4;
        const barH = 4;
        const barX = screenX - 2;
        const barY = screenY - 8;
        ctx.fillStyle = '#333';
        ctx.fillRect(barX, barY, barW, barH);
        const ratio = entity.hp / entity.maxHp;
        ctx.fillStyle = entity.isBoss ? '#ff4444' : '#ff6666';
        ctx.fillRect(barX, barY, barW * ratio, barH);
    }

    // Boss crown
    if (entity.isBoss) {
        ctx.fillStyle = '#ffd700';
        ctx.font = '16px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('👑', cx, screenY - 14);
    }

    // Name tag with level (red for enemies)
    ctx.fillStyle = isPlayer ? '#fff' : '#ff5555';
    ctx.font = 'bold 11px sans-serif';
    ctx.textAlign = 'center';
    const levelText = entity.level ? ` Lv${entity.level}` : '';
    ctx.fillText((entity.name || '') + levelText, cx, screenY - (entity.isBoss ? 28 : 12));

    ctx.restore();
}
function drawPlayerShape(cx, cy, p) {
    const bob = p.animFrame > 0 ? Math.sin(p.animTimer * 10) * 2 : 0;
    const mount = p.mount;

    // Draw mount if mounted
    if (mount) {
        const mw = mount.w, mh = mount.h;
        // Mount shadow
        ctx.fillStyle = 'rgba(0,0,0,0.3)';
        ctx.beginPath();
        ctx.ellipse(cx, cy + mh/2, mw/2 - 4, 5, 0, 0, Math.PI * 2);
        ctx.fill();
        // Mount body
        ctx.fillStyle = mount.color;
        if (mount.id === 'bicycle' || mount.id === 'motor') {
            // Bike frame
            ctx.strokeStyle = mount.color; ctx.lineWidth = 3;
            ctx.beginPath(); ctx.arc(cx, cy - 5, 10, 0, Math.PI * 2); ctx.stroke();
            ctx.beginPath(); ctx.arc(cx + 8, cy + 8, 8, 0, Math.PI * 2); ctx.stroke();
            ctx.beginPath(); ctx.moveTo(cx, cy - 5); ctx.lineTo(cx + 8, cy - 10); ctx.stroke();
        } else if (mount.id === 'boat') {
            ctx.fillStyle = '#8B6914';
            ctx.beginPath();
            ctx.moveTo(cx - mw/3, cy + mh/3);
            ctx.lineTo(cx - mw/3, cy - mh/4);
            ctx.quadraticCurveTo(cx, cy - mh/2, cx + mw/3, cy - mh/4);
            ctx.lineTo(cx + mw/3, cy + mh/3);
            ctx.closePath(); ctx.fill();
        } else {
            // Horse body
            ctx.fillStyle = mount.color;
            ctx.beginPath();
            ctx.ellipse(cx, cy, mw/2 - 5, mh/2 - 5, 0, 0, Math.PI * 2);
            ctx.fill();
            // Horse head
            ctx.fillStyle = '#6b4c20';
            ctx.beginPath();
            ctx.arc(cx - mw/3, cy - mh/4, mw/6, 0, Math.PI * 2);
            ctx.fill();
        }
        // Mount icon
        ctx.fillStyle = '#fff';
        ctx.font = '14px sans-serif'; ctx.textAlign = 'center';
        ctx.fillText(mount.icon, cx, cy - 6);
    }

    // ── ZELDA-STYLE CHARACTER ──
    // Green tunic body
    const tunicGreen = '#30a840';
    const tunicDark = '#208030';
    const tunicLight = '#40c050';

    // Legs / boots
    ctx.fillStyle = '#5a3a20';
    ctx.fillRect(cx - 5, cy + 4 + bob, 4, 8);
    ctx.fillRect(cx + 1, cy + 4 + bob, 4, 8);
    // Boots
    ctx.fillStyle = '#3a2010';
    ctx.fillRect(cx - 6, cy + 10 + bob, 5, 4);
    ctx.fillRect(cx + 1, cy + 10 + bob, 5, 4);

    // Tunic body - trapezoid shape
    ctx.fillStyle = tunicDark;
    ctx.beginPath();
    ctx.moveTo(cx - 8, cy - 4 + bob);
    ctx.lineTo(cx - 11, cy + 6 + bob);
    ctx.lineTo(cx + 11, cy + 6 + bob);
    ctx.lineTo(cx + 8, cy - 4 + bob);
    ctx.closePath(); ctx.fill();

    ctx.fillStyle = tunicGreen;
    ctx.beginPath();
    ctx.moveTo(cx - 6, cy - 3 + bob);
    ctx.lineTo(cx - 9, cy + 4 + bob);
    ctx.lineTo(cx + 9, cy + 4 + bob);
    ctx.lineTo(cx + 6, cy - 3 + bob);
    ctx.closePath(); ctx.fill();

    // Brown belt across middle
    ctx.fillStyle = '#5a3820';
    ctx.fillRect(cx - 9, cy - 1 + bob, 18, 4);
    // Gold buckle
    ctx.fillStyle = '#d4a020';
    ctx.fillRect(cx - 3, cy - 1 + bob, 6, 4);

    // Tunic highlight
    ctx.fillStyle = tunicLight;
    ctx.fillRect(cx - 4, cy - 3 + bob, 3, 3);

    // Arms (skin color)
    ctx.fillStyle = '#f0c898';
    // Left arm
    ctx.fillRect(cx - 12, cy - 4 + bob, 4, 8);
    // Right arm
    ctx.fillRect(cx + 8, cy - 4 + bob, 4, 8);

    // Shield on left arm (facing direction)
    ctx.fillStyle = '#3355aa';
    ctx.strokeStyle = '#8899cc'; ctx.lineWidth = 2;
    let shieldX = cx - 13, shieldY = cy - 6 + bob;
    switch (p.dir) {
        case 0: shieldX = cx - 14; shieldY = cy - 6 + bob; break;
        case 1: shieldX = cx - 2; shieldY = cy - 14 + bob; break;
        case 2: shieldX = cx - 14; shieldY = cy - 6 + bob; break;
        case 3: shieldX = cx + 4; shieldY = cy - 6 + bob; break;
    }
    ctx.beginPath();
    ctx.roundRect(shieldX, shieldY, 10, 12, 3);
    ctx.fill();
    ctx.stroke();
    // Shield cross emblem
    ctx.strokeStyle = '#ffd700'; ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(shieldX + 5, shieldY + 2);
    ctx.lineTo(shieldX + 5, shieldY + 10);
    ctx.moveTo(shieldX + 2, shieldY + 6);
    ctx.lineTo(shieldX + 8, shieldY + 6);
    ctx.stroke();

    // Head
    ctx.fillStyle = '#f0c898';
    ctx.beginPath();
    ctx.arc(cx, cy - 13 + bob, 8, 0, Math.PI * 2);
    ctx.fill();

    // Green cap (Link style)
    ctx.fillStyle = tunicGreen;
    ctx.beginPath();
    ctx.arc(cx, cy - 15 + bob, 7, Math.PI, Math.PI * 2);
    ctx.fill();
    // Cap back (trailing part)
    ctx.fillStyle = tunicDark;
    ctx.beginPath();
    ctx.moveTo(cx + 6, cy - 16 + bob);
    ctx.lineTo(cx + 14, cy - 18 + bob);
    ctx.lineTo(cx + 10, cy - 13 + bob);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = tunicGreen;
    ctx.beginPath();
    ctx.moveTo(cx + 5, cy - 15 + bob);
    ctx.lineTo(cx + 12, cy - 17 + bob);
    ctx.lineTo(cx + 9, cy - 14 + bob);
    ctx.closePath(); ctx.fill();

    // Eyes (direction based)
    ctx.fillStyle = '#222';
    let eyeOffX = 0, eyeOffY = 0;
    switch (p.dir) {
        case 0: eyeOffY = 2; break;
        case 1: eyeOffX = -2; break;
        case 2: eyeOffY = -2; break;
        case 3: eyeOffX = 2; break;
    }
    ctx.beginPath();
    ctx.arc(cx - 3 + eyeOffX, cy - 14 + bob + eyeOffY, 1.8, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(cx + 3 + eyeOffX, cy - 14 + bob + eyeOffY, 1.8, 0, Math.PI * 2);
    ctx.fill();

    // Sword on back/right side
    const weapon = player.weapon;
    let swordX = cx + 10, swordY = cy - 8 + bob;
    let swordAngle = 0.3;
    switch (p.dir) {
        case 0: swordX = cx + 11; swordY = cy - 8 + bob; swordAngle = 0.3; break;
        case 1: swordX = cx + 4; swordY = cy - 16 + bob; swordAngle = -0.8; break;
        case 2: swordX = cx + 11; swordY = cy - 8 + bob; swordAngle = 0.3; break;
        case 3: swordX = cx + 11; swordY = cy - 8 + bob; swordAngle = 0.3; break;
    }
    // Sword blade
    ctx.save();
    ctx.translate(swordX, swordY);
    ctx.rotate(swordAngle);
    ctx.fillStyle = '#c0c0d0';
    ctx.fillRect(-1.5, -10, 3, 14);
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(-0.5, -9, 1, 3);
    // Sword hilt
    ctx.fillStyle = '#8B4513';
    ctx.fillRect(-3, 2, 6, 3);
    // Sword gem
    ctx.fillStyle = weapon.color;
    ctx.beginPath(); ctx.arc(0, -8, 2.5, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

    // Attack swing effect - varies by weapon ability, more vivid
    const ability = weapon.ability || 'basic';
    if (p.attackTimer > (weapon.cooldown || p.attackCooldown) - 0.16) {
        const progress = ((weapon.cooldown || p.attackCooldown) - p.attackTimer) / 0.16;
        const fa = facingAngle(p.dir);

        if (ability === 'ranged') {
            // Magic circle at origin - larger and brighter
            ctx.strokeStyle = weapon.color;
            ctx.lineWidth = 4;
            ctx.shadowColor = weapon.color;
            ctx.shadowBlur = 12;
            ctx.beginPath();
            const origin = { x: cx, y: cy };
            switch (p.dir) {
                case 0: origin.y = cy + p.h / 2 + 6; break;
                case 1: origin.x = cx - p.w / 2 - 6; break;
                case 2: origin.y = cy - p.h / 2 - 6; break;
                case 3: origin.x = cx + p.w / 2 + 6; break;
            }
            ctx.arc(origin.x, origin.y, 12 + progress * 20, 0, Math.PI * 2);
            ctx.stroke();
            ctx.shadowBlur = 0;
        } else if (ability === 'fire' || ability === 'legend') {
            // Fire/legend arc - thicker and glowing
            ctx.strokeStyle = weapon.color;
            ctx.lineWidth = 5;
            ctx.shadowColor = weapon.color;
            ctx.shadowBlur = 15;
            ctx.beginPath();
            ctx.arc(cx, cy, 24 + progress * 35,
                fa - 0.8 - progress * 0.4,
                fa + 0.8 + progress * 0.4);
            ctx.stroke();
            ctx.shadowBlur = 0;
        } else if (ability === 'wide' || ability === 'combo_wide') {
            // Wide slash - thicker
            ctx.strokeStyle = weapon.color;
            ctx.lineWidth = 4;
            ctx.shadowColor = weapon.color;
            ctx.shadowBlur = 10;
            ctx.beginPath();
            const wideAngle = weapon.wideAngle || 0.5;
            ctx.arc(cx, cy, 24 + progress * 28,
                fa - wideAngle - progress * 0.25,
                fa + wideAngle + progress * 0.25);
            ctx.stroke();
            ctx.shadowBlur = 0;
        } else if (ability === 'push') {
            // Push wind arc
            ctx.strokeStyle = '#aaddff';
            ctx.lineWidth = 3;
            ctx.shadowColor = '#88ccff';
            ctx.shadowBlur = 15;
            ctx.beginPath();
            ctx.arc(cx, cy, 20 + progress * 50,
                fa - 0.6, fa + 0.6);
            ctx.stroke();
            ctx.shadowBlur = 0;
        } else if (ability === 'slam') {
            // Slam ground ring
            ctx.strokeStyle = '#ddcc88';
            ctx.lineWidth = 5;
            ctx.shadowColor = '#cc9944';
            ctx.shadowBlur = 20;
            ctx.beginPath();
            ctx.arc(cx, cy, 15 + progress * 40, 0, Math.PI * 2);
            ctx.stroke();
            ctx.shadowBlur = 0;
        } else {
            // Standard slash - thicker
            ctx.strokeStyle = weapon.color;
            ctx.lineWidth = 3.5;
            ctx.shadowColor = weapon.color;
            ctx.shadowBlur = 8;
            ctx.beginPath();
            ctx.arc(cx, cy, 20 + progress * 24,
                fa - 0.4 - progress * 0.4,
                fa + 0.4 + progress * 0.4);
            ctx.stroke();
            ctx.shadowBlur = 0;
        }
    }

    // Combo indicator
    if (p.comboHits > 0) {
        const comboMax = weapon.comboMax || 5;
        ctx.fillStyle = '#ffd700';
        ctx.font = 'bold 10px sans-serif';
        ctx.textAlign = 'center';
        for (let i = 0; i < comboMax; i++) {
            const filled = i < p.comboHits;
            ctx.fillText(filled ? '◆' : '◇', cx - (comboMax - 1) * 5 + i * 10, cy - 28);
        }
    }

    // Shield indicator
    if (p.shieldActive > 0) {
        const shieldAlpha = 0.3 + Math.sin(performance.now() / 200) * 0.1;
        ctx.strokeStyle = `rgba(100,100,255,${shieldAlpha + 0.3})`;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(cx, cy, 22, 0, Math.PI * 2);
        ctx.stroke();
    }
}

function drawEnemyShape(cx, cy, e) {
    const bob = Math.sin(e.animTimer * 3) * 2;
    const sz = e.w * 0.4;

    // Frozen tint
    if (e.frozen > 0) {
        ctx.fillStyle = 'rgba(100,180,255,0.5)';
        ctx.beginPath();
        ctx.arc(cx, cy, sz * 1.8, 0, Math.PI * 2);
        ctx.fill();
    }

    const name = e.name;
    const color = e.color;

    if (name === '슬라임' || name === '거대 슬라임') {
        // Dark pulsating slime
        const squish = 1 + Math.sin(e.animTimer * 4) * 0.08;
        ctx.fillStyle = '#3a2020';
        ctx.beginPath();
        ctx.ellipse(cx, cy + 4, sz * squish + 2, sz * 0.85, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.ellipse(cx, cy + 2 + bob, sz * squish, sz * 0.8 / squish, 0, 0, Math.PI * 2);
        ctx.fill();
        // Glowing red eyes
        ctx.fillStyle = '#ff2222';
        ctx.shadowColor = '#ff0000'; ctx.shadowBlur = 4;
        ctx.beginPath(); ctx.arc(cx - sz * 0.3, cy - sz * 0.1 + bob, sz * 0.22, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + sz * 0.3, cy - sz * 0.1 + bob, sz * 0.22, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
        // Sharp teeth
        ctx.fillStyle = '#fff';
        for (let i = -1; i <= 1; i += 2) {
            ctx.beginPath();
            ctx.moveTo(cx + i * sz * 0.3 - 2, cy + sz * 0.2);
            ctx.lineTo(cx + i * sz * 0.3, cy + sz * 0.4);
            ctx.lineTo(cx + i * sz * 0.3 + 2, cy + sz * 0.2);
            ctx.fill();
        }
    } else if (name === '늑대') {
        // Fierce wolf
        const s = sz;
        ctx.fillStyle = '#1a1a1a';
        ctx.beginPath(); ctx.ellipse(cx, cy + 3, s + 2, s * 0.7, 0, 0, Math.PI * 2); ctx.fill();
        // Body
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.ellipse(cx, cy + bob, s, s * 0.7, 0, 0, Math.PI * 2);
        ctx.fill();
        // Head
        ctx.fillStyle = '#504840';
        ctx.beginPath();
        ctx.arc(cx - s * 0.7, cy - s * 0.3 + bob, s * 0.55, 0, Math.PI * 2);
        ctx.fill();
        // Snout
        ctx.fillStyle = '#3a3028';
        ctx.beginPath();
        ctx.ellipse(cx - s * 1.2, cy - s * 0.2 + bob, s * 0.4, s * 0.25, 0, 0, Math.PI * 2);
        ctx.fill();
        // Red eyes
        ctx.fillStyle = '#ff2222';
        ctx.shadowColor = '#ff0000'; ctx.shadowBlur = 3;
        ctx.beginPath(); ctx.arc(cx - s * 0.75, cy - s * 0.5 + bob, s * 0.12, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
        // Teeth
        ctx.fillStyle = '#fff';
        ctx.beginPath();
        ctx.moveTo(cx - s * 1.3, cy - s * 0.05 + bob);
        ctx.lineTo(cx - s * 1.5, cy + s * 0.05 + bob);
        ctx.lineTo(cx - s * 1.1, cy + s * 0.05 + bob);
        ctx.fill();
        // Tail
        ctx.strokeStyle = color; ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(cx + s * 0.8, cy - s * 0.1 + bob);
        ctx.quadraticCurveTo(cx + s * 1.3, cy - s * 0.8, cx + s * 1.0, cy - s * 1.1);
        ctx.stroke();
    } else if (name === '해골 전사') {
        const s = sz;
        // Shadow
        ctx.fillStyle = 'rgba(0,0,0,0.3)';
        ctx.beginPath(); ctx.ellipse(cx, cy + s * 1.2, s * 0.7, 3, 0, 0, Math.PI * 2); ctx.fill();
        // Body (armor)
        ctx.fillStyle = '#3a3a40';
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.7, cy - s * 0.1 + bob, s * 1.4, s * 1.5, 3);
        ctx.fill();
        // Shoulder pads
        ctx.fillStyle = '#4a4a50';
        ctx.beginPath(); ctx.arc(cx - s * 0.8, cy - s * 0.1 + bob, s * 0.3, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + s * 0.8, cy - s * 0.1 + bob, s * 0.3, 0, Math.PI * 2); ctx.fill();
        // Skull
        ctx.fillStyle = '#d0d0d0';
        ctx.beginPath();
        ctx.arc(cx, cy - s * 0.7 + bob, s * 0.55, 0, Math.PI * 2);
        ctx.fill();
        // Skull detail (jaw)
        ctx.fillStyle = '#b0b0b0';
        ctx.fillRect(cx - s * 0.35, cy - s * 0.4 + bob, s * 0.7, s * 0.25);
        // Red eye sockets
        ctx.fillStyle = '#ff1111';
        ctx.shadowColor = '#ff0000'; ctx.shadowBlur = 4;
        ctx.beginPath(); ctx.arc(cx - s * 0.2, cy - s * 0.8 + bob, s * 0.13, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + s * 0.2, cy - s * 0.8 + bob, s * 0.13, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
        // Sword
        ctx.fillStyle = '#c0c0d0';
        ctx.fillRect(cx + s * 0.5, cy - s * 0.5 + bob, 3, s * 1.2);
        ctx.fillStyle = '#ffd700';
        ctx.fillRect(cx + s * 0.4, cy - s * 0.5 + bob, 5, 3);
    } else if (name === '다크 메이지') {
        const s = sz;
        // Shadow
        ctx.fillStyle = 'rgba(0,0,0,0.3)';
        ctx.beginPath(); ctx.ellipse(cx, cy + s * 1.2, s * 0.5, 3, 0, 0, Math.PI * 2); ctx.fill();
        // Robe
        ctx.fillStyle = '#1a1028';
        ctx.beginPath();
        ctx.moveTo(cx - s * 0.8, cy - s * 0.2 + bob);
        ctx.lineTo(cx - s * 0.5, cy + s * 0.9);
        ctx.lineTo(cx + s * 0.5, cy + s * 0.9);
        ctx.lineTo(cx + s * 0.8, cy - s * 0.2 + bob);
        ctx.closePath(); ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.moveTo(cx - s * 0.6, cy - s * 0.2 + bob);
        ctx.lineTo(cx - s * 0.3, cy + s * 0.7);
        ctx.lineTo(cx + s * 0.3, cy + s * 0.7);
        ctx.lineTo(cx + s * 0.6, cy - s * 0.2 + bob);
        ctx.closePath(); ctx.fill();
        // Hood
        ctx.fillStyle = '#1a1028';
        ctx.beginPath();
        ctx.arc(cx, cy - s * 0.6 + bob, s * 0.65, Math.PI, Math.PI * 2);
        ctx.fill();
        ctx.fillRect(cx - s * 0.65, cy - s * 0.6 + bob, s * 1.3, s * 0.3);
        // Face (hidden in shadow)
        ctx.fillStyle = '#0a0a10';
        ctx.beginPath();
        ctx.arc(cx, cy - s * 0.3 + bob, s * 0.35, 0, Math.PI * 2);
        ctx.fill();
        // Glowing eyes
        ctx.fillStyle = '#ff44ff';
        ctx.shadowColor = '#ff00ff'; ctx.shadowBlur = 6;
        ctx.beginPath(); ctx.arc(cx - s * 0.12, cy - s * 0.4 + bob, s * 0.08, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + s * 0.12, cy - s * 0.4 + bob, s * 0.08, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
        // Staff
        ctx.strokeStyle = '#6a4a2a'; ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(cx + s * 0.5, cy - s * 0.3 + bob);
        ctx.lineTo(cx + s * 0.6, cy + s * 0.8);
        ctx.stroke();
        ctx.fillStyle = '#ff44ff';
        ctx.shadowColor = '#ff00ff'; ctx.shadowBlur = 8;
        ctx.beginPath(); ctx.arc(cx + s * 0.5, cy - s * 0.4 + bob, s * 0.2, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
    } else if (name === '악당 보스') {
        const s = sz;
        // Shadow + dark aura
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        ctx.beginPath(); ctx.ellipse(cx, cy + s * 1.4, s * 1.2, 6, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = 'rgba(200,0,0,0.15)';
        ctx.beginPath(); ctx.arc(cx, cy, s * 1.8, 0, Math.PI * 2); ctx.fill();
        // Body
        ctx.fillStyle = '#1a0a0a';
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.9, cy - s * 0.2 + bob, s * 1.8, s * 1.8, 5);
        ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.7, cy + bob, s * 1.4, s * 1.6, 4);
        ctx.fill();
        // Spiky shoulders
        ctx.fillStyle = '#2a0a0a';
        [-1, 1].forEach(side => {
            ctx.beginPath();
            ctx.moveTo(cx + side * s * 0.6, cy - s * 0.2 + bob);
            ctx.lineTo(cx + side * s * 1.2, cy - s * 0.8 + bob);
            ctx.lineTo(cx + side * s * 0.6, cy + s * 0.1 + bob);
            ctx.fill();
        });
        // Head
        ctx.fillStyle = '#3a1515';
        ctx.beginPath();
        ctx.arc(cx, cy - s * 0.8 + bob, s * 0.7, 0, Math.PI * 2);
        ctx.fill();
        // Horns
        ctx.fillStyle = '#1a0a0a';
        [-1, 1].forEach(side => {
            ctx.beginPath();
            ctx.moveTo(cx + side * s * 0.3, cy - s * 1.2 + bob);
            ctx.lineTo(cx + side * s * 0.5, cy - s * 1.9 + bob);
            ctx.lineTo(cx + side * s * 0.7, cy - s * 1.1 + bob);
            ctx.fill();
        });
        // Fiery eyes
        ctx.fillStyle = '#ff4400';
        ctx.shadowColor = '#ff2200'; ctx.shadowBlur = 8;
        ctx.beginPath(); ctx.arc(cx - s * 0.2, cy - s * 0.9 + bob, s * 0.14, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + s * 0.2, cy - s * 0.9 + bob, s * 0.14, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
        // Large sword
        ctx.fillStyle = '#888';
        ctx.fillRect(cx + s * 0.6, cy - s * 1.0 + bob, 4, s * 2.0);
        ctx.fillStyle = '#ff4444';
        ctx.fillRect(cx + s * 0.5, cy - s * 1.2 + bob, 6, s * 0.4);
    } else if (name === '트롤') {
        const s = sz;
        ctx.fillStyle = 'rgba(0,0,0,0.4)';
        ctx.beginPath(); ctx.ellipse(cx, cy + s * 1.3, s * 1.0, 5, 0, 0, Math.PI * 2); ctx.fill();
        // Body
        ctx.fillStyle = '#3a2820';
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.8, cy - s * 0.2 + bob, s * 1.6, s * 1.6, 4);
        ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.65, cy + bob, s * 1.3, s * 1.4, 4);
        ctx.fill();
        // Head
        ctx.fillStyle = '#4a3528';
        ctx.beginPath();
        ctx.arc(cx, cy - s * 0.75 + bob, s * 0.6, 0, Math.PI * 2);
        ctx.fill();
        // Underbite jaw
        ctx.fillStyle = '#3a2820';
        ctx.beginPath();
        ctx.ellipse(cx, cy - s * 0.4 + bob, s * 0.5, s * 0.2, 0, 0, Math.PI * 2);
        ctx.fill();
        // Teeth
        ctx.fillStyle = '#ddd';
        ctx.fillRect(cx - s * 0.4, cy - s * 0.45 + bob, s * 0.8, s * 0.15);
        ctx.fillStyle = '#555';
        for (let i = 0; i < 4; i++) {
            ctx.fillRect(cx - s * 0.35 + i * s * 0.2, cy - s * 0.45 + bob, s * 0.08, s * 0.15);
        }
        // Red eyes
        ctx.fillStyle = '#ff2200';
        ctx.shadowColor = '#ff0000'; ctx.shadowBlur = 5;
        ctx.beginPath(); ctx.arc(cx - s * 0.2, cy - s * 0.9 + bob, s * 0.12, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + s * 0.2, cy - s * 0.9 + bob, s * 0.12, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
        // Club
        ctx.fillStyle = '#5a3a20';
        ctx.fillRect(cx + s * 0.5, cy - s * 0.5 + bob, s * 0.5, s * 0.25);
        ctx.fillRect(cx + s * 0.6, cy - s * 0.2 + bob, 5, s * 1.0);
    } else if (name === '고대 골렘') {
        const s = sz;
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        ctx.beginPath(); ctx.ellipse(cx, cy + s * 1.4, s * 1.1, 6, 0, 0, Math.PI * 2); ctx.fill();
        // Body (blocky)
        ctx.fillStyle = '#383838';
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.9, cy - s * 0.3 + bob, s * 1.8, s * 1.8, 2);
        ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.7, cy - s * 0.1 + bob, s * 1.4, s * 1.5, 2);
        ctx.fill();
        // Crack lines
        ctx.strokeStyle = '#282828'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(cx - s * 0.2, cy + s * 0.2 + bob); ctx.lineTo(cx + s * 0.3, cy + s * 0.6 + bob); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(cx + s * 0.1, cy - s * 0.1 + bob); ctx.lineTo(cx + s * 0.5, cy + s * 0.3 + bob); ctx.stroke();
        // Head (square)
        ctx.fillStyle = '#484848';
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.55, cy - s * 1.0 + bob, s * 1.1, s * 0.9, 3);
        ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.45, cy - s * 0.9 + bob, s * 0.9, s * 0.7, 3);
        ctx.fill();
        // Glowing rune eyes
        ctx.fillStyle = '#00ffaa';
        ctx.shadowColor = '#00ff88'; ctx.shadowBlur = 8;
        ctx.beginPath(); ctx.arc(cx - s * 0.18, cy - s * 0.65 + bob, s * 0.1, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + s * 0.18, cy - s * 0.65 + bob, s * 0.1, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
        // Rune on chest
        ctx.fillStyle = '#00ffaa';
        ctx.shadowColor = '#00ff88'; ctx.shadowBlur = 6;
        ctx.font = `${s * 0.4}px sans-serif`; ctx.textAlign = 'center';
        ctx.fillText('⬡', cx, cy + s * 0.3 + bob);
        ctx.shadowBlur = 0;
    } else if (name === '독수리') {
        // Flying eagle - fast, sweeps down
        const s = sz;
        // Shadow on ground
        ctx.fillStyle = 'rgba(0,0,0,0.2)';
        ctx.beginPath(); ctx.ellipse(cx, cy + s * 0.8, s * 0.7, 3, 0, 0, Math.PI * 2); ctx.fill();
        // Body
        ctx.fillStyle = '#4a3020';
        ctx.beginPath();
        ctx.ellipse(cx, cy - s * 0.1 + bob, s * 0.6, s * 0.35, 0, 0, Math.PI * 2);
        ctx.fill();
        // Wings spread
        ctx.fillStyle = '#3a2018';
        ctx.beginPath();
        ctx.moveTo(cx - s * 0.3, cy - s * 0.1 + bob);
        ctx.quadraticCurveTo(cx - s * 1.5, cy - s * 0.8 + bob, cx - s * 1.2, cy - s * 0.3 + bob);
        ctx.quadraticCurveTo(cx - s * 0.6, cy + s * 0.1 + bob, cx - s * 0.3, cy - s * 0.1 + bob);
        ctx.fill();
        ctx.beginPath();
        ctx.moveTo(cx + s * 0.3, cy - s * 0.1 + bob);
        ctx.quadraticCurveTo(cx + s * 1.5, cy - s * 0.8 + bob, cx + s * 1.2, cy - s * 0.3 + bob);
        ctx.quadraticCurveTo(cx + s * 0.6, cy + s * 0.1 + bob, cx + s * 0.3, cy - s * 0.1 + bob);
        ctx.fill();
        // Wing flap animation
        const flap = Math.sin(e.animTimer * 8) * 0.2;
        // Head
        ctx.fillStyle = '#5a3a2a';
        ctx.beginPath();
        ctx.arc(cx + s * 0.4, cy - s * 0.3 + bob + flap, s * 0.25, 0, Math.PI * 2);
        ctx.fill();
        // Beak
        ctx.fillStyle = '#cc8800';
        ctx.beginPath();
        ctx.moveTo(cx + s * 0.6, cy - s * 0.35 + bob + flap);
        ctx.lineTo(cx + s * 0.85, cy - s * 0.3 + bob + flap);
        ctx.lineTo(cx + s * 0.6, cy - s * 0.2 + bob + flap);
        ctx.fill();
        // Eye
        ctx.fillStyle = '#ff2200';
        ctx.shadowColor = '#ff0000'; ctx.shadowBlur = 3;
        ctx.beginPath(); ctx.arc(cx + s * 0.5, cy - s * 0.35 + bob + flap, s * 0.06, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
        // Talons
        ctx.fillStyle = '#cc8800';
        [-1, 1].forEach(side => {
            ctx.beginPath();
            ctx.moveTo(cx + side * s * 0.15, cy + s * 0.2 + bob);
            ctx.lineTo(cx + side * s * 0.25, cy + s * 0.4 + bob);
            ctx.lineTo(cx + side * s * 0.05, cy + s * 0.25 + bob);
            ctx.fill();
        });
    } else if (e.megaBoss) {
        // Mega boss - uses boss color/size
        const s = sz;
        const auraAlpha = 0.1 + Math.sin(e.animTimer * 2) * 0.05;
        ctx.fillStyle = `rgba(180,0,0,${auraAlpha})`;
        ctx.beginPath(); ctx.arc(cx, cy, s * 2.2, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = 'rgba(0,0,0,0.6)';
        ctx.beginPath(); ctx.ellipse(cx, cy + s * 1.5, s * 1.3, 10, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#1a0505';
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.9, cy - s * 0.3 + bob, s * 1.8, s * 2.0, 8);
        ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.7, cy - s * 0.1 + bob, s * 1.4, s * 1.7, 6);
        ctx.fill();
        [-1, 1].forEach(side => {
            ctx.fillStyle = '#2a0808';
            ctx.beginPath();
            ctx.moveTo(cx + side * s * 0.7, cy - s * 0.3 + bob);
            ctx.lineTo(cx + side * s * 1.4, cy - s * 1.0 + bob);
            ctx.lineTo(cx + side * s * 0.7, cy + s * 0.2 + bob);
            ctx.fill();
        });
        ctx.fillStyle = '#2a0808';
        ctx.beginPath();
        ctx.arc(cx, cy - s * 0.9 + bob, s * 0.8, 0, Math.PI * 2);
        ctx.fill();
        [-1, 1].forEach(side => {
            ctx.beginPath();
            ctx.moveTo(cx + side * s * 0.4, cy - s * 1.4 + bob);
            ctx.lineTo(cx + side * s * 0.8, cy - s * 2.5 + bob);
            ctx.lineTo(cx + side * s * 0.9, cy - s * 1.2 + bob);
            ctx.fill();
        });
        ctx.fillStyle = '#ff4400';
        ctx.shadowColor = '#ff2200'; ctx.shadowBlur = 15;
        ctx.beginPath(); ctx.arc(cx - s * 0.25, cy - s * 1.05 + bob, s * 0.15, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + s * 0.25, cy - s * 1.05 + bob, s * 0.15, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
    } else {
        // Default humanoid (goblin etc)
        const s = sz;
        ctx.fillStyle = 'rgba(0,0,0,0.3)';
        ctx.beginPath(); ctx.ellipse(cx, cy + s * 1.2, s * 0.6, 3, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.roundRect(cx - s * 0.75, cy - s * 0.1 + bob, s * 1.5, s * 1.4, 4);
        ctx.fill();
        ctx.fillStyle = '#3a2820';
        ctx.beginPath();
        ctx.arc(cx, cy - s * 0.6 + bob, s * 0.55, 0, Math.PI * 2);
        ctx.fill();
        // Pointy ears
        ctx.fillStyle = '#4a3520';
        [-1, 1].forEach(side => {
            ctx.beginPath();
            ctx.moveTo(cx + side * s * 0.4, cy - s * 0.7 + bob);
            ctx.lineTo(cx + side * s * 0.8, cy - s * 1.0 + bob);
            ctx.lineTo(cx + side * s * 0.5, cy - s * 0.5 + bob);
            ctx.fill();
        });
        // Red eyes
        ctx.fillStyle = '#ff2200';
        ctx.shadowColor = '#ff0000'; ctx.shadowBlur = 3;
        ctx.beginPath(); ctx.arc(cx - s * 0.15, cy - s * 0.7 + bob, s * 0.1, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + s * 0.15, cy - s * 0.7 + bob, s * 0.1, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0;
    }
}

