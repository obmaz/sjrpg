let atlas = null;
let groundSheet = null;
if (typeof Image === 'function') {
    atlas = new Image();
    atlas.src = new URL('../../assets/atlas.webp', import.meta.url).href;
    const ground = new Image();
    ground.onload = () => {
        const sheet = document.createElement('canvas');
        sheet.width = 512;
        sheet.height = 512;
        const paint = sheet.getContext('2d');
        const sourceSize = ground.naturalWidth / 2;
        // Mirror each material into a seamless 8×8-tile patch once at load time.
        for (let index = 0; index < 4; index++) {
            for (let row = 0; row < 2; row++) {
                for (let column = 0; column < 2; column++) {
                    paint.save();
                    paint.translate(
                        (index % 2) * 256 + column * 256,
                        Math.floor(index / 2) * 256 + row * 256,
                    );
                    paint.scale(column ? -1 : 1, row ? -1 : 1);
                    paint.drawImage(
                        ground,
                        (index % 2) * sourceSize,
                        Math.floor(index / 2) * sourceSize,
                        sourceSize,
                        sourceSize,
                        0,
                        0,
                        128,
                        128,
                    );
                    paint.restore();
                }
            }
        }
        groundSheet = sheet;
    };
    ground.src = new URL('../../assets/terrain.webp', import.meta.url).href;
}

const GROUND_MATERIALS = { GRASS: 0, GRASS_TALL: 0, DIRT: 1, SAND: 2, PATH: 3 };
function drawGroundMaterial(ctx, key, x, y, size, tileX, tileY) {
    const index = GROUND_MATERIALS[key];
    if (!groundSheet || index === undefined) return false;
    ctx.drawImage(
        groundSheet,
        (index % 2) * 256 + (tileX % 8) * 32,
        Math.floor(index / 2) * 256 + (tileY % 8) * 32,
        32,
        32,
        x,
        y,
        size,
        size,
    );
    if (key === 'GRASS_TALL') {
        ctx.fillStyle = '#092b2633';
        ctx.fillRect(x, y, size, size);
    }
    return true;
}

function drawArtToken(ctx, index, cx, cy, size) {
    if (!Number.isInteger(index) || !atlas?.complete || !atlas.naturalWidth) return false;
    const cell = atlas.naturalWidth / 4;
    ctx.drawImage(
        atlas,
        (index % 4) * cell,
        Math.floor(index / 4) * cell,
        cell,
        cell,
        cx - size / 2,
        cy - size / 2,
        size,
        size,
    );
    return true;
}

export { drawArtToken, drawGroundMaterial };
