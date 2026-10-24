let atlas = null;
if (typeof Image === 'function') {
    atlas = new Image();
    atlas.src = new URL('../../assets/atlas.webp', import.meta.url).href;
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

export { drawArtToken };
