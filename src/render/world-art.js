// All frames use the same painted direction, padding and foot anchor.
import { WORLD_FRAMES } from '../data/art.js';
const sheets = {};
if (typeof Image === 'function') {
    for (const name of ['forest', 'desert']) {
        const sheet = new Image();
        sheet.src = new URL(`../../assets/world-${name}.webp`, import.meta.url).href;
        sheets[name] = sheet;
    }
}

// x is the body centre; feetY remains tied to the existing collision footprint.
function drawWorldSprite(ctx, key, x, feetY, width, height = width) {
    const frame = WORLD_FRAMES[key];
    if (!frame) return false;
    const sheet = sheets[frame[0]];
    if (!sheet?.complete || !sheet.naturalWidth) return false;
    const cell = sheet.naturalWidth / 4;
    ctx.drawImage(
        sheet,
        (frame[1] % 4) * cell,
        Math.floor(frame[1] / 4) * cell,
        cell,
        cell,
        x - width / 2,
        feetY - height * 0.88,
        width,
        height,
    );
    return true;
}

export { drawWorldSprite };
