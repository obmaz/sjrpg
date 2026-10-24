// Fixed painted opening: coordinates are shared by collision, rendering and encounters.
const VILLAGE = Object.freeze({ x: 960, y: 704, width: 640, height: 960 });
function inVillage(x, y) {
    return (
        x >= VILLAGE.x &&
        y >= VILLAGE.y &&
        x < VILLAGE.x + VILLAGE.width &&
        y < VILLAGE.y + VILLAGE.height
    );
}
function villageTile(u, v) {
    if (((u - 0.5) / 0.19) ** 2 + ((v - 0.245) / 0.115) ** 2 < 1) return 'ROCK';
    if (u > 0.74 && v > 0.15 && v < 0.36) return 'ROCK';
    if (u < 0.25 && v > 0.4 && v < 0.67) return 'ROCK';
    if (u > 0.77 && v > 0.64) return 'ROCK';
    if ((u < 0.19 && !(v > 0.32 && v < 0.43)) || (u > 0.88 && v < 0.64)) return 'TREE';
    if (v > 0.91 && u < 0.46) return 'TREE';
    if (v < 0.08 && (u < 0.39 || u > 0.61)) return 'TREE';
    return 'DIRT';
}
export { VILLAGE, inVillage, villageTile };
