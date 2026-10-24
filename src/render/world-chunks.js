import { CHUNK_SIZE, CHUNK_ORIGIN_X, CHUNK_ORIGIN_Y, chunkVariant } from '../data/world-chunks.js';
import { createPaintedPanel } from './painted-panel.js';
import { player, session } from '../core/state.js';
const panels = {};
const MARGIN = 40;
if (typeof Image === 'function')
    for (const region of ['forest', 'desert']) {
        const image = new Image();
        image.onload = () => {
            const cell = image.naturalWidth / 2;
            panels[region] = Array.from({ length: 4 }, (_, variant) =>
                createPaintedPanel(
                    image,
                    (variant % 2) * cell + 3,
                    Math.floor(variant / 2) * cell + 3,
                    cell - 6,
                    cell - 6,
                    CHUNK_SIZE,
                    CHUNK_SIZE,
                    MARGIN,
                ),
            );
        };
        image.src = new URL(`../../assets/chunks-${region}.webp`, import.meta.url).href;
    }
function drawWorldChunks(context, camera, canvas) {
    if (
        session.chunkMap !== session.tileMap ||
        session.chunkRegion !== player.currentRegion ||
        !panels[player.currentRegion]
    )
        return false;
    const firstX = Math.floor((camera.x - MARGIN - CHUNK_ORIGIN_X) / CHUNK_SIZE),
        lastX = Math.floor((camera.x + canvas.width + MARGIN - CHUNK_ORIGIN_X) / CHUNK_SIZE);
    const firstY = Math.floor((camera.y - MARGIN - CHUNK_ORIGIN_Y) / CHUNK_SIZE),
        lastY = Math.floor((camera.y + canvas.height + MARGIN - CHUNK_ORIGIN_Y) / CHUNK_SIZE);
    for (let row = firstY; row <= lastY; row++)
        for (let column = firstX; column <= lastX; column++) {
            const variant = chunkVariant(session.chunkSeed, column, row);
            context.drawImage(
                panels[player.currentRegion][variant],
                CHUNK_ORIGIN_X + column * CHUNK_SIZE - camera.x - MARGIN,
                CHUNK_ORIGIN_Y + row * CHUNK_SIZE - camera.y - MARGIN,
            );
        }
    return true;
}
export { drawWorldChunks };
