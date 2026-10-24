import {
    CHUNK_SIZE,
    CHUNK_ORIGIN_X,
    CHUNK_ORIGIN_Y,
    chunkAppearance,
} from '../data/world-chunks.js';
import { createPaintedPanel } from './painted-panel.js';
import { player, session } from '../core/state.js';
const panels = {};
const MARGIN = 40;
if (typeof Image === 'function')
    for (const region of ['forest', 'desert'])
        for (const extra of [false, true]) {
            const image = new Image();
            image.onload = () => {
                const cell = image.naturalWidth / 2;
                if (!panels[region]) panels[region] = [];
                for (let variant = 0; variant < 4; variant++)
                    panels[region][variant + (extra ? 4 : 0)] = createPaintedPanel(
                        image,
                        (variant % 2) * cell + 3,
                        Math.floor(variant / 2) * cell + 3,
                        cell - 6,
                        cell - 6,
                        CHUNK_SIZE,
                        CHUNK_SIZE,
                        MARGIN,
                    );
            };
            image.src = new URL(
                `../../assets/chunks-${region}${extra ? '-paths' : ''}.webp`,
                import.meta.url,
            ).href;
        }
function drawWorldChunks(context, camera, canvas) {
    if (
        session.chunkMap !== session.tileMap ||
        session.chunkRegion !== player.currentRegion ||
        !panels[player.currentRegion] ||
        panels[player.currentRegion].filter(Boolean).length !== 8
    )
        return false;
    const firstX = Math.floor((camera.x - MARGIN - CHUNK_ORIGIN_X) / CHUNK_SIZE),
        lastX = Math.floor((camera.x + canvas.width + MARGIN - CHUNK_ORIGIN_X) / CHUNK_SIZE);
    const firstY = Math.floor((camera.y - MARGIN - CHUNK_ORIGIN_Y) / CHUNK_SIZE),
        lastY = Math.floor((camera.y + canvas.height + MARGIN - CHUNK_ORIGIN_Y) / CHUNK_SIZE);
    for (let row = firstY; row <= lastY; row++)
        for (let column = firstX; column <= lastX; column++) {
            const appearance = chunkAppearance(
                session.chunkSeed,
                column,
                row,
                player.currentRegion,
            );
            const panel = panels[player.currentRegion][appearance.variant];
            if (!panel) continue;
            const x = CHUNK_ORIGIN_X + column * CHUNK_SIZE - camera.x,
                y = CHUNK_ORIGIN_Y + row * CHUNK_SIZE - camera.y;
            context.save();
            context.translate(
                appearance.mirrored ? x + CHUNK_SIZE + MARGIN : x - MARGIN,
                y - MARGIN,
            );
            if (appearance.mirrored) context.scale(-1, 1);
            context.drawImage(panel, 0, 0);
            context.restore();
            if (appearance.light !== 0) {
                const light = context.createRadialGradient(
                    x + CHUNK_SIZE * 0.5,
                    y + CHUNK_SIZE * 0.5,
                    0,
                    x + CHUNK_SIZE * 0.5,
                    y + CHUNK_SIZE * 0.5,
                    CHUNK_SIZE * 0.65,
                );
                light.addColorStop(0, appearance.light === 1 ? '#f6c96810' : '#8bb8ae10');
                light.addColorStop(1, '#0000');
                context.fillStyle = light;
                context.fillRect(x, y, CHUNK_SIZE, CHUNK_SIZE);
            }
        }
    return true;
}
export { drawWorldChunks };
