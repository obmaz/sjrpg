import { canvas, ctx } from '../core/canvas.js';
import { getActorAngle } from '../core/facing.js';
import { player } from '../core/state.js';

const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
function visualMotionAllowed() {
    return !motionPreference.matches;
}

function drawWorldFrame() {
    ctx.save();
    const desert = player.currentRegion === 'desert';
    const radius = Math.max(canvas.width, canvas.height) * 0.75;
    const light = ctx.createRadialGradient(
        canvas.width / 2,
        canvas.height * 0.43,
        50,
        canvas.width / 2,
        canvas.height * 0.43,
        radius,
    );
    light.addColorStop(0, 'rgba(0,0,0,0)');
    light.addColorStop(0.65, desert ? 'rgba(72,39,19,0.02)' : 'rgba(5,35,30,0.04)');
    light.addColorStop(1, desert ? 'rgba(55,29,20,0.24)' : 'rgba(3,19,24,0.3)');
    ctx.fillStyle = light;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    if (player.hp > 0 && player.hp / player.maxHp < 0.25) {
        const danger = ctx.createRadialGradient(
            canvas.width / 2,
            canvas.height / 2,
            Math.min(canvas.width, canvas.height) * 0.3,
            canvas.width / 2,
            canvas.height / 2,
            radius,
        );
        danger.addColorStop(0, 'rgba(150,26,23,0)');
        danger.addColorStop(1, 'rgba(150,26,23,0.32)');
        ctx.fillStyle = danger;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
    ctx.restore();
}

function drawPlayerMarker(cx, cy, entity) {
    const size = entity.mount ? entity.mount.w : entity.w;
    const radius = Math.max(17, size * 0.62);
    const angle = getActorAngle(entity);
    const y = cy + entity.h / 2;
    ctx.save();
    ctx.strokeStyle = '#8de4d4cc';
    ctx.fillStyle = '#143c4660';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(cx, y, radius, radius * 0.43, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.translate(cx + Math.cos(angle) * (radius + 5), y + Math.sin(angle) * (radius * 0.65 + 4));
    ctx.rotate(angle);
    ctx.fillStyle = '#d1f7e8';
    ctx.beginPath();
    ctx.moveTo(5, 0);
    ctx.lineTo(-3, -3);
    ctx.lineTo(-3, 3);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
}

export { drawWorldFrame, drawPlayerMarker, visualMotionAllowed };
