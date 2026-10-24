const CHUNK_SIZE = 640;
const CHUNK_ORIGIN_X = -320;
const CHUNK_ORIGIN_Y = 64;
function chunkVariant(seed, column, row) {
    let hash =
        Math.imul((seed | 0) ^ Math.imul(column + 17, 73856093), 19349663) ^
        Math.imul(row + 29, 83492791);
    hash = Math.imul(hash ^ (hash >>> 16), 2246822519);
    return (hash >>> 0) % 4;
}
function chunkCoordinates(x, y) {
    const column = Math.floor((x - CHUNK_ORIGIN_X) / CHUNK_SIZE),
        row = Math.floor((y - CHUNK_ORIGIN_Y) / CHUNK_SIZE);
    return {
        column,
        row,
        u: (x - CHUNK_ORIGIN_X - column * CHUNK_SIZE) / CHUNK_SIZE,
        v: (y - CHUNK_ORIGIN_Y - row * CHUNK_SIZE) / CHUNK_SIZE,
    };
}
function chunkTile(variant, u, v, region) {
    if (variant === 1 && ((u - 0.235) / 0.205) ** 2 + ((v - 0.235) / 0.205) ** 2 < 1)
        return 'WATER';
    const dx = Math.abs(u - 0.5),
        dy = Math.abs(v - 0.5);
    if (dx <= 0.14 || dy <= 0.14 || dx * dx + dy * dy < 0.26 * 0.26)
        return region === 'desert' ? 'SAND' : 'DIRT';
    return region === 'desert' || variant === 2 ? 'ROCK' : 'TREE';
}
export { CHUNK_SIZE, CHUNK_ORIGIN_X, CHUNK_ORIGIN_Y, chunkVariant, chunkCoordinates, chunkTile };
