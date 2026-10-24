import { MAP_WIDTH, MAP_HEIGHT, TILE_SIZE } from '../core/constants.js';
import { VILLAGE, inVillage } from './village.js';

const WORLD_W = MAP_WIDTH * TILE_SIZE;
const WORLD_H = MAP_HEIGHT * TILE_SIZE;
const SECTOR_SIZE = 512;
function landscapeHash(seed, x, y) {
    let h =
        Math.imul((seed | 0) ^ Math.imul(x + 71, 73856093), 19349663) ^
        Math.imul(y + 137, 83492791);
    h = Math.imul(h ^ (h >>> 16), 2246822519);
    return (h >>> 0) / 4294967296;
}
function featureBounds(points, padding = 0) {
    return {
        left: Math.min(...points.map((p) => p[0])) - padding,
        top: Math.min(...points.map((p) => p[1])) - padding,
        right: Math.max(...points.map((p) => p[0])) + padding,
        bottom: Math.max(...points.map((p) => p[1])) + padding,
    };
}
function organicShape(cx, cy, rx, ry, phase, material) {
    const points = Array.from({ length: 96 }, (_, i) => {
        const a = (i / 96) * Math.PI * 2;
        const r = 1 + 0.055 * Math.sin(a * 3 + phase) + 0.035 * Math.cos(a * 7 - phase);
        return [cx + Math.cos(a) * rx * r, cy + Math.sin(a) * ry * r];
    });
    return { points, bounds: featureBounds(points), material };
}
function insideShape(x, y, shape) {
    const b = shape.bounds;
    if (x < b.left || x > b.right || y < b.top || y > b.bottom) return false;
    let inside = false;
    const points = shape.points;
    for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
        const [ax, ay] = points[i],
            [bx, by] = points[j];
        if (ay > y !== by > y && x < ((bx - ax) * (y - ay)) / (by - ay) + ax) inside = !inside;
    }
    return inside;
}
function roadDistance(x, y, road) {
    const b = road.bounds;
    if (x < b.left || x > b.right || y < b.top || y > b.bottom) return Infinity;
    let distance = Infinity;
    for (let i = 1; i < road.points.length; i++) {
        const [ax, ay] = road.points[i - 1],
            [bx, by] = road.points[i];
        const dx = bx - ax,
            dy = by - ay;
        const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)));
        distance = Math.min(distance, Math.hypot(x - ax - t * dx, y - ay - t * dy));
    }
    return distance;
}
function curvedRoad(anchors, width = 152) {
    const points = [];
    for (let i = 0; i < anchors.length - 1; i++) {
        const a = anchors[Math.max(0, i - 1)],
            b = anchors[i],
            c = anchors[i + 1],
            d = anchors[Math.min(anchors.length - 1, i + 2)];
        const steps = Math.max(2, Math.ceil(Math.hypot(c[0] - b[0], c[1] - b[1]) / 80));
        for (let s = 0; s < steps; s++) {
            const t = s / steps,
                t2 = t * t,
                t3 = t2 * t;
            points.push(
                [0, 1].map(
                    (k) =>
                        0.5 *
                        (2 * b[k] +
                            (-a[k] + c[k]) * t +
                            (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * t2 +
                            (-a[k] + 3 * b[k] - 3 * c[k] + d[k]) * t3),
                ),
            );
        }
    }
    points.push(anchors.at(-1));
    return { points, width, bounds: featureBounds(points, width / 2 + 70) };
}
function riverX(y, phase) {
    return 5320 + Math.sin(y / 620 + phase) * 290 + Math.sin(y / 1570) * 150;
}
function createLandscape(seed, region) {
    const phase = landscapeHash(seed, 0, 0) * Math.PI * 2;
    const desert = region === 'desert';
    const zones = desert
        ? [
              organicShape(2050, 1600, 1450, 1050, phase, 3),
              organicShape(5750, 4400, 1250, 980, phase + 1, 3),
              organicShape(5700, 1450, 1030, 850, phase + 2, 0),
          ]
        : [
              organicShape(1800, 2800, 1550, 1900, phase, 1),
              organicShape(3850, 950, 1900, 1000, phase + 1, 1),
              organicShape(6600, 3600, 850, 1600, phase + 2, 1),
              organicShape(6500, 5350, 1500, 750, phase + 3, 2),
          ];
    const lakes = desert
        ? [
              organicShape(5700, 1450, 620, 450, phase, 4),
              organicShape(1900, 4700, 470, 340, phase + 2, 4),
          ]
        : [
              organicShape(5750, 1700, 840, 650, phase, 4),
              organicShape(1850, 1100, 690, 450, phase + 2, 4),
          ];
    if (!desert) {
        const left = [],
            right = [];
        for (let y = -160; y <= WORLD_H + 160; y += 80) {
            const x = riverX(y, phase),
                w = 148 + 24 * Math.sin(y / 330);
            left.push([x - w, y]);
            right.push([x + w, y]);
        }
        const points = [...left, ...right.reverse()];
        lakes.push({ points, bounds: featureBounds(points), material: 4 });
    }
    const roads = [
        curvedRoad(
            [
                [3840, 3500],
                [4180, 3850],
                [4600, 4200],
                [4900, 4200],
                [5700, 4200],
                [6200, 4200],
                [6780, 4660],
                [7440, 4900],
            ],
            176,
        ),
        curvedRoad(
            [
                [3570, 2992],
                [3410, 2992],
                [3100, 3270],
                [2680, 3750],
                [1780, 3970],
                [950, 4470],
                [250, 4700],
            ],
            152,
        ),
        curvedRoad(
            [
                [3840, 2670],
                [4000, 2280],
                [3730, 1770],
                [4200, 1050],
                [4650, 420],
            ],
            152,
        ),
        curvedRoad(
            [
                [3100, 3270],
                [2840, 2600],
                [3100, 1890],
                [2800, 1440],
                [2600, 700],
            ],
            136,
        ),
        curvedRoad(
            [
                [4180, 3850],
                [3900, 4480],
                [3250, 4740],
                [2990, 5430],
            ],
            140,
        ),
    ];
    const bridges = desert ? [] : [{ x: riverX(4200, phase), y: 4200, w: 620, h: 176 }];
    const landscape = { seed, region, zones, lakes, roads, bridges, props: [], buckets: new Map() };
    // Jittered candidates are clustered by biome, never used as visible room boundaries.
    for (let row = 1; row < Math.ceil(WORLD_H / 88) - 1; row++)
        for (let col = 1; col < Math.ceil(WORLD_W / 88) - 1; col++) {
            const roll = landscapeHash(seed, col, row);
            const cx = col * 88 + landscapeHash(seed + 1, col, row) * 68,
                cy = row * 88 + landscapeHash(seed + 2, col, row) * 68;
            if (
                cx > VILLAGE.x - 110 &&
                cx < VILLAGE.x + VILLAGE.width + 110 &&
                cy > VILLAGE.y - 180 &&
                cy < VILLAGE.y + VILLAGE.height + 150
            )
                continue;
            const material = landscapeMaterial(landscape, cx, cy),
                woodland = !desert && material === 1;
            const density = woodland ? 0.72 : desert ? 0.045 : 0.055;
            if (
                roll > density ||
                waterAt(landscape, cx, cy) ||
                roads.some((r) => roadDistance(cx, cy, r) < r.width / 2 + 112)
            )
                continue;
            if (
                lakes.some(
                    (l) =>
                        insideShape(cx - 64, cy, l) ||
                        insideShape(cx + 64, cy, l) ||
                        insideShape(cx, cy - 64, l) ||
                        insideShape(cx, cy + 64, l),
                )
            )
                continue;
            const tree = woodland || (!desert && roll < 0.022),
                key = desert
                    ? material === 0
                        ? 'palm'
                        : roll < 0.018
                          ? 'cactus'
                          : 'sandstone'
                    : tree
                      ? 'tree'
                      : 'rock';
            const size = tree ? 32 : key === 'sandstone' ? 64 : 32;
            const x = Math.floor(cx / TILE_SIZE) * TILE_SIZE,
                y = Math.floor(cy / TILE_SIZE) * TILE_SIZE;
            const prop = {
                x,
                y,
                w: size,
                h: size,
                key,
                width: tree ? 142 + roll * 55 : key === 'palm' ? 130 : size * 2,
                height: tree ? 185 + roll * 65 : key === 'palm' ? 165 : size * 1.8,
            };
            landscape.props.push(prop);
            const b = {
                left: x - prop.width,
                top: y - prop.height,
                right: x + prop.width,
                bottom: y + prop.height,
            };
            for (
                let by = Math.floor(b.top / SECTOR_SIZE);
                by <= Math.floor(b.bottom / SECTOR_SIZE);
                by++
            )
                for (
                    let bx = Math.floor(b.left / SECTOR_SIZE);
                    bx <= Math.floor(b.right / SECTOR_SIZE);
                    bx++
                ) {
                    const id = `${bx}:${by}`;
                    if (!landscape.buckets.has(id)) landscape.buckets.set(id, []);
                    landscape.buckets.get(id).push(prop);
                }
        }
    return landscape;
}
function landscapeMaterial(landscape, x, y) {
    for (let i = landscape.zones.length - 1; i >= 0; i--)
        if (insideShape(x, y, landscape.zones[i])) return landscape.zones[i].material;
    return landscape.region === 'desert' ? 2 : 0;
}
function waterAt(landscape, x, y) {
    return landscape.lakes.some((l) => insideShape(x, y, l));
}
function landscapeTile(landscape, x, y) {
    if (landscape.region === 'forest' && inVillage(x, y)) return null;
    const road = landscape.roads.some((r) => roadDistance(x, y, r) <= r.width / 2);
    if (road) return landscape.region === 'desert' ? 'DIRT' : 'PATH';
    if (waterAt(landscape, x, y)) return 'WATER';
    const material = landscapeMaterial(landscape, x, y);
    return material === 1 ? 'GRASS_TALL' : material === 2 || material === 3 ? 'SAND' : 'GRASS';
}
export {
    SECTOR_SIZE,
    landscapeHash,
    createLandscape,
    landscapeMaterial,
    landscapeTile,
    insideShape,
    roadDistance,
    waterAt,
};
