// World art keeps a foot anchor; directional mounts use measured content bounds.
import { WORLD_FRAMES, getMountArtFrame, MOUNT_SPRITE_BOUNDS } from '../data/art.js';
const sheets = {};
let ancientDragon = null;
if (typeof Image === 'function') {
    ancientDragon = new Image();
    ancientDragon.src = new URL('../../assets/ancient-dragon.webp', import.meta.url).href;
}
if (typeof Image === 'function') {
    for (const name of ['forest', 'desert', 'mounts']) {
        const sheet = new Image();
        sheet.src = new URL(`../../assets/world-${name}.webp`, import.meta.url).href;
        sheets[name] = sheet;
    }
}

// x is the body centre; feetY remains tied to the existing collision footprint.
function drawWorldSprite(ctx, key, x, feetY, width, height = width) {
    if (key === 'ancientDragon' && ancientDragon?.complete && ancientDragon.naturalWidth) {
        const drawHeight = (width * ancientDragon.naturalHeight) / ancientDragon.naturalWidth;
        ctx.drawImage(ancientDragon, x - width / 2, feetY - drawHeight, width, drawHeight);
        return true;
    }
    return drawSheetFrame(ctx, WORLD_FRAMES[key], x, feetY, width, height);
}

function drawSheetFrame(ctx, frame, x, feetY, width, height) {
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

function drawMountSprite(ctx, mount, x, feetY, direction = mount.dir ?? 0) {
    const sheet = sheets.mounts;
    const frame = getMountArtFrame(mount.id, direction);
    if (frame && sheet?.complete && sheet.naturalWidth) {
        const [sx, sy, sw, sh] = MOUNT_SPRITE_BOUNDS[frame[1]];
        const scale = (mount.w * 1.5) / Math.max(sw, sh);
        const width = sw * scale,
            height = sh * scale;
        ctx.drawImage(sheet, sx, sy, sw, sh, x - width / 2, feetY - height, width, height);
        return true;
    }
    return drawWorldSprite(ctx, mount.id, x, feetY, mount.w * 1.5, mount.h * 1.5);
}
function getWorldSpriteTop(key, feetY, width, height) {
    return (
        feetY -
        (key === 'ancientDragon' && ancientDragon?.naturalWidth
            ? (width * ancientDragon.naturalHeight) / ancientDragon.naturalWidth
            : height * 0.88)
    );
}
export { drawWorldSprite, drawMountSprite, getWorldSpriteTop };
