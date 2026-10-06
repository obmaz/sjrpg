// ============================================================
//  EFFECTS RENDERING (projectiles, particles, fire zones, floating texts, vision fog)
// ============================================================
function drawFireZones() {
    for (const fz of fireZones) {
        const sx = fz.x - camera.x;
        const sy = fz.y - camera.y;
        const alpha = Math.min(1, fz.duration / fz.maxDuration);

        // Fire glow
        const gradient = ctx.createRadialGradient(sx, sy, 5, sx, sy, fz.radius);
        gradient.addColorStop(0, `rgba(255,100,20,${0.5 * alpha})`);
        gradient.addColorStop(0.6, `rgba(255,60,10,${0.3 * alpha})`);
        gradient.addColorStop(1, `rgba(255,20,0,0)`);
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.arc(sx, sy, fz.radius, 0, Math.PI * 2);
        ctx.fill();
    }
}

// ============================================================
//  PROJECTILE RENDERING
// ============================================================
function drawProjectiles() {
    for (const p of projectiles) {
        const sx = p.x - camera.x;
        const sy = p.y - camera.y;
        ctx.fillStyle = p.color.replace(')', ',0.4)').replace('rgb', 'rgba');
        if (p.color.startsWith('#')) { ctx.fillStyle = p.color + '66'; }
        ctx.beginPath(); ctx.arc(sx, sy, p.size + 4, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(sx, sy, p.size, 0, Math.PI * 2); ctx.fill();
        if (p.icon) {
            ctx.fillStyle = '#fff'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
            ctx.fillText(p.icon, sx, sy + 3);
        }
    }
}

function drawEnemyProjectiles() {
    for (const p of enemyProjectiles) {
        const sx = p.x - camera.x, sy = p.y - camera.y;
        ctx.fillStyle = p.color + '66';
        ctx.beginPath(); ctx.arc(sx, sy, p.size + 4, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(sx, sy, p.size, 0, Math.PI * 2); ctx.fill();
    }
}
function drawGoldPickups() {
    for (const g of goldPickups) {
        const sx = g.x - camera.x, sy = g.y - camera.y + Math.sin(g.bob + performance.now() / 500) * 3;
        // Outer bold ring
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        ctx.beginPath(); ctx.arc(sx, sy, 11, 0, Math.PI * 2); ctx.fill();
        // Glow
        ctx.fillStyle = 'rgba(255,215,0,0.5)';
        ctx.beginPath(); ctx.arc(sx, sy, 10, 0, Math.PI * 2); ctx.fill();
        // Bold border
        ctx.strokeStyle = '#664400'; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.arc(sx, sy, 8, 0, Math.PI * 2); ctx.stroke();
        // Coin body
        ctx.fillStyle = '#ffd700';
        ctx.beginPath(); ctx.arc(sx, sy, 7, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = '#cc9900'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(sx, sy, 7, 0, Math.PI * 2); ctx.stroke();
        // Shine
        ctx.fillStyle = '#ffee88';
        ctx.beginPath(); ctx.arc(sx - 2, sy - 2, 2.5, 0, Math.PI * 2); ctx.fill();
        // $ symbol
        ctx.fillStyle = '#553300';
        ctx.font = 'bold 9px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillText('$', sx, sy + 1);
    }
}

function drawWeaponPickups() {
    for (const wp of weaponPickups) {
        const sx = wp.x - camera.x, sy = wp.y - camera.y + Math.sin(wp.bob + performance.now() / 500) * 3;
        const w = wp.weapon;
        // Outer glow
        ctx.fillStyle = 'rgba(255,255,255,0.3)';
        ctx.beginPath(); ctx.arc(sx, sy, 14, 0, Math.PI * 2); ctx.fill();
        // Background disc
        ctx.fillStyle = 'rgba(20,20,40,0.85)';
        ctx.beginPath(); ctx.arc(sx, sy, 12, 0, Math.PI * 2); ctx.fill();
        // Colored border
        ctx.strokeStyle = w.color; ctx.lineWidth = 2.5;
        ctx.beginPath(); ctx.arc(sx, sy, 12, 0, Math.PI * 2); ctx.stroke();
        // Weapon icon
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 16px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillText(w.icon, sx, sy);
        // Name below
        ctx.fillStyle = '#ffcc88';
        ctx.font = 'bold 8px sans-serif'; ctx.textAlign = 'center';
        ctx.fillText(w.name, sx, sy + 16);
    }
}

function drawMounts() {
    for (const m of mounts) {
        const sx = m.x - camera.x, sy = m.y - camera.y;
        const time = performance.now() / 1000;
        // Shadow
        ctx.fillStyle = 'rgba(0,0,0,0.4)';
        ctx.beginPath(); ctx.ellipse(sx, sy + m.h/2, m.w/3 + 2, 7, 0, 0, Math.PI * 2); ctx.fill();
        // Mount icon - big and bright
        ctx.font = 'bold 36px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        // Text outline for visibility
        ctx.strokeStyle = '#000'; ctx.lineWidth = 4;
        ctx.strokeText(m.icon, sx, sy);
        ctx.fillStyle = '#ffffff';
        ctx.fillText(m.icon, sx, sy);
        // Name label below
        ctx.font = 'bold 12px sans-serif';
        ctx.fillStyle = '#ffd700';
        ctx.strokeStyle = '#000'; ctx.lineWidth = 3;
        ctx.strokeText(m.name, sx, sy + 24);
        ctx.fillText(m.name, sx, sy + 24);
    }
}


function drawParticles() {
    for (const p of particles) {
        const alpha = p.life / p.maxLife;
        ctx.fillStyle = p.color;
        ctx.globalAlpha = alpha;
        ctx.beginPath();
        ctx.arc(p.x - camera.x, p.y - camera.y, p.size * alpha, 0, Math.PI * 2);
        ctx.fill();
    }
    ctx.globalAlpha = 1;
}

function drawFloatingTexts() {
    for (const t of floatingTexts) {
        const alpha = Math.min(1, t.life * 2);
        ctx.fillStyle = t.color;
        ctx.globalAlpha = alpha;
        ctx.font = 'bold 16px sans-serif';
        ctx.textAlign = 'center';
        // Text shadow for visibility
        ctx.strokeStyle = '#000';
        ctx.lineWidth = 3;
        ctx.strokeText(t.text, t.x - camera.x, t.y - camera.y);
        ctx.fillText(t.text, t.x - camera.x, t.y - camera.y);
    }
    ctx.globalAlpha = 1;
}

// ============================================================
//  VISION FOG (slot machine effect)
// ============================================================
function drawVisionFog() {
    const px = player.x + player.w / 2 - camera.x;
    const py = player.y + player.h / 2 - camera.y;
    const radius = Math.min(canvas.width, canvas.height) * 0.28;

    // Draw dark overlay with radial gradient cutout
    const gradient = ctx.createRadialGradient(px, py, radius * 0.7, px, py, radius);
    gradient.addColorStop(0, 'rgba(0,0,0,0)');
    gradient.addColorStop(0.5, 'rgba(0,0,10,0.3)');
    gradient.addColorStop(0.8, 'rgba(0,0,10,0.75)');
    gradient.addColorStop(1, 'rgba(0,0,10,0.92)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Fog edge particles
    const time = performance.now() / 1000;
    if (Math.random() < 0.5) {
        const a = Math.random() * Math.PI * 2;
        const r = radius * (0.75 + Math.random() * 0.25);
        particles.push({
            x: player.x + player.w / 2 + Math.cos(a) * r,
            y: player.y + player.h / 2 + Math.sin(a) * r,
            vx: Math.cos(a) * 10, vy: Math.sin(a) * 10,
            life: 1.5, maxLife: 1.5,
            color: '#334466', size: 2 + Math.random() * 3,
        });
    }
}
