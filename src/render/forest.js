import { MAP_WIDTH, MAP_HEIGHT, TILE_KEYS, TILE_SIZE } from '../core/constants.js';
import { player, session } from '../core/state.js';
import { getTile } from '../systems/world.js';

let texture = null;
let crowns = null;
let cachedMap = null;
let cachedRevision = -1;
let density = new Uint8Array(MAP_WIDTH * MAP_HEIGHT);
let dense = new Uint8Array(MAP_WIDTH * MAP_HEIGHT);
const canopyTiles = new Map();
const TREE = TILE_KEYS.indexOf('TREE');
const BUSH = TILE_KEYS.indexOf('BUSH');

if (typeof Image === 'function') {
    const treetops = new Image();
    treetops.onload = () => {
        crowns = treetops;
        canopyTiles.clear();
    };
    treetops.src = new URL('../../assets/world-forest.webp', import.meta.url).href;
    const source = new Image();
    source.onload = () => {
        const sheet = document.createElement('canvas');
        sheet.width = sheet.height = 1024;
        const paint = sheet.getContext('2d');
        const cell = source.naturalWidth / 2;
        // Mirror each 256px swatch into a continuous 512px material.
        for (let material = 0; material < 4; material++)
            for (let row = 0; row < 2; row++)
                for (let col = 0; col < 2; col++) {
                    paint.save();
                    paint.translate(
                        (material % 2) * 512 + col * 512,
                        Math.floor(material / 2) * 512 + row * 512,
                    );
                    paint.scale(col ? -1 : 1, row ? -1 : 1);
                    paint.drawImage(
                        source,
                        (material % 2) * cell,
                        Math.floor(material / 2) * cell,
                        cell,
                        cell,
                        0,
                        0,
                        256,
                        256,
                    );
                    paint.restore();
                }
        texture = sheet;
        canopyTiles.clear();
    };
    source.src = new URL('../../assets/forest.webp', import.meta.url).href;
}

function refreshForest() {
    if (cachedMap === session.tileMap && cachedRevision === session.terrainRevision) return;
    cachedMap = session.tileMap;
    cachedRevision = session.terrainRevision;
    density = new Uint8Array(MAP_WIDTH * MAP_HEIGHT);
    dense = new Uint8Array(MAP_WIDTH * MAP_HEIGHT);
    for (let y = 0; y < MAP_HEIGHT; y++)
        for (let x = 0; x < MAP_WIDTH; x++) {
            let trees = 0,
                nearWood = 0;
            for (let dy = -2; dy <= 2; dy++)
                for (let dx = -2; dx <= 2; dx++) {
                    const tile = getTile(x + dx, y + dy);
                    if (tile === TREE) trees++;
                    if (Math.abs(dx) <= 1 && Math.abs(dy) <= 1 && (tile === TREE || tile === BUSH))
                        nearWood++;
                }
            const index = y * MAP_WIDTH + x,
                tile = getTile(x, y);
            density[index] = trees;
            dense[index] = Number((tile === TREE || tile === BUSH) && trees >= 3 && nearWood >= 4);
        }
}

function getForestTile(x, y) {
    refreshForest();
    if (x < 0 || y < 0 || x >= MAP_WIDTH || y >= MAP_HEIGHT)
        return { density: 0, dense: false, mask: 0 };
    const index = y * MAP_WIDTH + x;
    const joined = (px, py) =>
        px >= 0 && py >= 0 && px < MAP_WIDTH && py < MAP_HEIGHT && dense[py * MAP_WIDTH + px];
    const mask =
        (joined(x, y - 1) ? 1 : 0) |
        (joined(x + 1, y) ? 2 : 0) |
        (joined(x, y + 1) ? 4 : 0) |
        (joined(x - 1, y) ? 8 : 0);
    return { density: density[index], dense: !!dense[index], mask };
}

function paintMaterial(context, material, x, y, tx, ty) {
    context.drawImage(
        texture,
        (material % 2) * 512 + (tx % 16) * 32,
        Math.floor(material / 2) * 512 + (ty % 16) * 32,
        32,
        32,
        x,
        y,
        TILE_SIZE,
        TILE_SIZE,
    );
}

function drawForestFloor(context, key, x, y, tx, ty) {
    if (
        player.currentRegion !== 'forest' ||
        !texture ||
        !['GRASS', 'GRASS_TALL', 'DIRT', 'FLOWER'].includes(key)
    )
        return;
    const cover = getForestTile(tx, ty).density;
    if (cover < 3) return;
    context.save();
    context.globalAlpha = Math.min(0.85, (cover - 2) * 0.12);
    paintMaterial(context, 3, x, y, tx, ty);
    if (cover > 5) {
        context.globalAlpha = Math.min(0.85, (cover - 5) * 0.12);
        paintMaterial(context, 2, x, y, tx, ty);
    }
    context.globalAlpha = Math.min(0.22, cover * 0.012);
    context.fillStyle = '#061e1c';
    context.fillRect(x, y, TILE_SIZE, TILE_SIZE);
    context.restore();
}

function traceCanopy(context, x, y, width, height, radii) {
    const [tl, tr, br, bl] = radii;
    context.beginPath();
    context.moveTo(x + tl, y);
    context.lineTo(x + width - tr, y);
    context.quadraticCurveTo(x + width, y, x + width, y + tr);
    context.lineTo(x + width, y + height - br);
    context.quadraticCurveTo(x + width, y + height, x + width - br, y + height);
    context.lineTo(x + bl, y + height);
    context.quadraticCurveTo(x, y + height, x, y + height - bl);
    context.lineTo(x, y + tl);
    context.quadraticCurveTo(x, y, x + tl, y);
    context.closePath();
}

function drawForestGround(context, x, y, tx, ty) {
    if (player.currentRegion !== 'forest' || !texture || !crowns || !getForestTile(tx, ty).dense)
        return false;
    paintMaterial(context, 2, x, y, tx, ty);
    return true;
}

function paintCrowns(context, tx, ty) {
    const cell = crowns.naturalWidth / 4;
    for (let ay = Math.floor(ty / 2) - 1; ay <= Math.floor(ty / 2) + 1; ay++) {
        for (let ax = Math.floor(tx / 2) - 1; ax <= Math.floor(tx / 2) + 1; ax++) {
            const px = ((ax % 8) + 8) % 8,
                py = ((ay % 8) + 8) % 8;
            const hash = px * 17 + py * 31;
            const width = 96 + (hash % 3) * 8,
                height = width * 0.8;
            const cx = ax * 64 + 32 + (hash % 13) - 6;
            const cy = ay * 64 + 32 + ((hash >> 2) % 11) - 5;
            context.drawImage(
                crowns,
                0,
                cell * 2,
                cell,
                cell * 0.74,
                cx - tx * 32 - width / 2,
                cy - ty * 32 - height / 2,
                width,
                height,
            );
        }
    }
}

function drawForestCanopy(context, x, y, tx, ty) {
    if (player.currentRegion !== 'forest' || !texture || !crowns) return false;
    const forest = getForestTile(tx, ty);
    if (!forest.dense) return false;
    const { mask } = forest;
    const key = `${tx % 16}:${ty % 16}:${mask}`;
    let tile = canopyTiles.get(key);
    if (!tile) {
        tile = document.createElement('canvas');
        tile.width = tile.height = 40;
        const paint = tile.getContext('2d');
        paint.translate(4, 4);
        const jitter = (tx * 17 + ty * 29) & 3;
        const top = mask & 1 ? -4 : -3 + jitter / 2,
            right = mask & 2 ? 36 : 35 - jitter / 2;
        const trunk = !(mask & 4) && ((tx % 16) + (ty % 16) * 3) % 3 === 0;
        const bottom = mask & 4 ? 36 : trunk ? 27 : 34 - jitter / 2,
            left = mask & 8 ? -4 : -3 + jitter / 2;
        const radii = [
            !(mask & 1) && !(mask & 8) ? 12 : 3,
            !(mask & 1) && !(mask & 2) ? 12 : 3,
            !(mask & 4) && !(mask & 2) ? 12 : 3,
            !(mask & 4) && !(mask & 8) ? 12 : 3,
        ];
        paint.fillStyle = '#031b1955';
        traceCanopy(paint, left + 1, top + 3, right - left, bottom - top, radii);
        paint.fill();
        if (trunk) {
            paint.fillStyle = '#382e22';
            paint.fillRect(14, 20, 5, 12);
            paint.fillStyle = '#6d5030';
            paint.fillRect(15, 21, 2, 10);
        }
        paint.save();
        traceCanopy(
            paint,
            left,
            top,
            right - left,
            bottom - top,
            mask === 15 ? [0, 0, 0, 0] : radii,
        );
        paint.clip();
        paintMaterial(paint, 0, 0, 0, tx, ty);
        paintCrowns(paint, tx, ty);
        paint.globalCompositeOperation = 'source-atop';
        paint.fillStyle = mask === 15 ? '#06291f22' : '#1039290a';
        paint.fillRect(-4, -4, 40, 40);
        paint.restore();
        if (canopyTiles.size >= 1024) canopyTiles.delete(canopyTiles.keys().next().value);
        canopyTiles.set(key, tile);
    }
    context.drawImage(tile, x - 4, y - 4);
    return true;
}

// A sparse tall treeline gives the joined roof height without repeating a trunk per tile.
function drawForestEdgeTrees(context, camera, canvas) {
    if (player.currentRegion !== 'forest' || !texture || !crowns) return;
    const startX = Math.max(0, Math.floor(camera.x / 32) - 2),
        endX = Math.min(MAP_WIDTH, Math.ceil((camera.x + canvas.width) / 32) + 2);
    const startY = Math.max(0, Math.floor(camera.y / 32) - 1),
        endY = Math.min(MAP_HEIGHT, Math.ceil((camera.y + canvas.height) / 32) + 4);
    const cell = crowns.naturalWidth / 4;
    for (let y = startY; y < endY; y++)
        for (let x = startX; x < endX; x++) {
            const kind = getTile(x, y);
            if (kind !== TREE && kind !== BUSH) continue;
            const forest = getForestTile(x, y);
            if (!forest.dense) continue;
            const front = !(forest.mask & 4) && x % 3 === 0;
            const side = (!(forest.mask & 8) || !(forest.mask & 2)) && y % 4 === 0;
            if (!front && !side) continue;
            const hash = (x * 17 + y * 29) >>> 0;
            const width = 82 + (hash % 3) * 6,
                height = 106 + (hash % 4) * 4;
            const cx = x * 32 + 16 - camera.x,
                feet = y * 32 + 30 - camera.y;
            context.drawImage(
                crowns,
                0,
                cell * 2,
                cell,
                cell,
                cx - width / 2,
                feet - height * 0.88,
                width,
                height,
            );
        }
}

export { getForestTile, drawForestFloor, drawForestGround, drawForestCanopy, drawForestEdgeTrees };
