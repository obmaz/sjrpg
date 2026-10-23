import { camera, canvas } from '../core/canvas.js';
import { FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y, MAX_FRAME_DELTA } from '../core/constants.js';
import { canAct, clamp, distance } from '../core/helpers.js';
import { particles, player } from '../core/state.js';

// Keep the original 60 Hz effect density independent of rendering frequency.
const EMISSION_INTERVAL = 1 / 60;
let emissionAccumulator = 0;

function emitFountainParticles() {
    const sx = FOUNTAIN_CENTER_X - camera.x;
    const sy = FOUNTAIN_CENTER_Y - camera.y;
    if (sx < -120 || sx > canvas.width + 120 || sy < -120 || sy > canvas.height + 120) return;

    // Splash particles at base
    if (Math.random() < 0.7) {
        const splashCount = 2 + Math.floor(Math.random() * 3);
        for (let i = 0; i < splashCount; i++) {
            const a = Math.random() * Math.PI * 2;
            const r = 30 + Math.random() * 30;
            particles.push({
                x: FOUNTAIN_CENTER_X + Math.cos(a) * r,
                y: FOUNTAIN_CENTER_Y + 10,
                vx: Math.cos(a) * (10 + Math.random() * 30),
                vy: -20 - Math.random() * 40,
                life: 0.3 + Math.random() * 0.2,
                maxLife: 0.5,
                color: '#88ccff',
                size: 1.5 + Math.random() * 3,
            });
        }
    }

    const dist = distance(
        player.x + player.w / 2,
        player.y + player.h / 2,
        FOUNTAIN_CENTER_X,
        FOUNTAIN_CENTER_Y,
    );
    if (dist < 180 && player.hp < player.maxHp && player.gold > 0) {
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
    }
}

function emitFogParticles() {
    const radius = Math.min(canvas.width, canvas.height) * 0.28;
    // Fog edge particles
    if (Math.random() < 0.5) {
        const a = Math.random() * Math.PI * 2;
        const r = radius * (0.75 + Math.random() * 0.25);
        particles.push({
            x: player.x + player.w / 2 + Math.cos(a) * r,
            y: player.y + player.h / 2 + Math.sin(a) * r,
            vx: Math.cos(a) * 10,
            vy: Math.sin(a) * 10,
            life: 1.5,
            maxLife: 1.5,
            color: '#334466',
            size: 2 + Math.random() * 3,
        });
    }
}

function emitEnvironmentalParticles(deltaTime) {
    if (!canAct()) return;
    emissionAccumulator += clamp(deltaTime, 0, MAX_FRAME_DELTA);
    const ticks = Math.floor((emissionAccumulator + Number.EPSILON) / EMISSION_INTERVAL);
    emissionAccumulator = Math.max(0, emissionAccumulator - ticks * EMISSION_INTERVAL);
    for (let i = 0; i < ticks; i++) {
        emitFountainParticles();
        if (player.visionReduction > 0) emitFogParticles();
    }
}

export { emitEnvironmentalParticles };
