import { player, session } from '../core/state.js';
import { SECTOR_SIZE, landscapeHash, waterAt } from '../data/landscape.js';
import { drawWorldSprite } from './world-art.js';

const patterns = [];
const cache = new Map();
let cachedLandscape = null;
let bridgeImage = null;
let warming = false;
let previousView = null;
const COLORS = ['#829550', '#253f35', '#d8b66b', '#a59064', '#237f90', '#bba06a'];
if (typeof Image === 'function') {
    bridgeImage = new Image();
    bridgeImage.onload = () => cache.clear();
    bridgeImage.src = new URL('../../assets/landscape-bridge.webp', import.meta.url).href;
    const image = new Image();
    image.onload = () => {
        for (let i = 0; i < 6; i++) {
            const stamp = document.createElement('canvas');
            stamp.width = 512;
            stamp.height = 512;
            const paint = stamp.getContext('2d'),
                sw = image.naturalWidth / 3,
                sh = image.naturalHeight / 2;
            paint.drawImage(
                image,
                (i % 3) * sw + 2,
                Math.floor(i / 3) * sh + 2,
                sw - 4,
                sh - 4,
                0,
                0,
                512,
                512,
            );
            paint.globalCompositeOperation = 'destination-in';
            for (const vertical of [false, true]) {
                const fade = paint.createLinearGradient(
                    0,
                    0,
                    vertical ? 0 : 512,
                    vertical ? 512 : 0,
                );
                fade.addColorStop(0, '#0000');
                fade.addColorStop(48 / 512, '#000');
                fade.addColorStop(464 / 512, '#000');
                fade.addColorStop(1, '#0000');
                paint.fillStyle = fade;
                paint.fillRect(0, 0, 512, 512);
            }
            const patch = document.createElement('canvas');
            patch.width = 464;
            patch.height = 464;
            const p = patch.getContext('2d');
            p.fillStyle = COLORS[i];
            p.fillRect(0, 0, 464, 464);
            for (let row = -1; row <= 1; row++)
                for (let col = -1; col <= 1; col++)
                    p.drawImage(stamp, col * 464 - 24, row * 464 - 24);
            patterns[i] = p.createPattern(patch, 'repeat');
        }
        cache.clear();
    };
    image.src = new URL('../../assets/landscape-materials.webp', import.meta.url).href;
}
function trace(p, points, closed = true) {
    p.beginPath();
    points.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y)));
    if (closed) p.closePath();
}
function intersects(b, x, y, size) {
    return b.right >= x && b.bottom >= y && b.left <= x + size && b.top <= y + size;
}
function material(i) {
    return patterns[i] || COLORS[i];
}
function sector(landscape, col, row) {
    const key = `${col}:${row}`;
    if (cache.has(key)) {
        const result = cache.get(key);
        cache.delete(key);
        cache.set(key, result);
        return result;
    }
    const result = document.createElement('canvas');
    result.width = SECTOR_SIZE;
    result.height = SECTOR_SIZE;
    const p = result.getContext('2d'),
        x = col * SECTOR_SIZE,
        y = row * SECTOR_SIZE;
    p.translate(-x, -y);
    p.fillStyle = material(landscape.region === 'desert' ? 2 : 0);
    p.fillRect(x, y, SECTOR_SIZE, SECTOR_SIZE);
    for (const zone of landscape.zones) {
        if (!intersects(zone.bounds, x, y, SECTOR_SIZE)) continue;
        trace(p, zone.points);
        p.fillStyle = material(zone.material);
        p.fill();
        // Soft, irregular edge around biome transitions; no room-shaped frame.
        p.strokeStyle =
            zone.material === 1 ? '#3c593d38' : zone.material === 2 ? '#d6bb7740' : '#9c915340';
        for (const width of [84, 48, 20]) {
            p.lineWidth = width;
            p.stroke();
        }
    }
    // Broad variation hides the frequency of the material sheet without grid seams.
    for (let gy = row * 4 - 1; gy <= row * 4 + 4; gy++)
        for (let gx = col * 4 - 1; gx <= col * 4 + 4; gx++) {
            const h = landscapeHash(landscape.seed, gx, gy),
                cx = gx * 128 + h * 100,
                cy = gy * 128 + landscapeHash(landscape.seed + 5, gx, gy) * 100;
            const gradient = p.createRadialGradient(cx, cy, 0, cx, cy, 160 + h * 120);
            gradient.addColorStop(0, h > 0.5 ? '#f0d78917' : '#102d3218');
            gradient.addColorStop(1, '#0000');
            p.fillStyle = gradient;
            p.fillRect(cx - 280, cy - 280, 560, 560);
        }
    for (const lake of landscape.lakes) {
        if (!intersects(lake.bounds, x - 60, y - 60, SECTOR_SIZE + 120)) continue;
        trace(p, lake.points);
        p.lineJoin = 'round';
        p.strokeStyle = '#827a5350';
        p.lineWidth = 68;
        p.stroke();
        p.strokeStyle = '#c1b47c';
        p.lineWidth = 32;
        p.stroke();
        p.fillStyle = material(4);
        p.fill();
        p.strokeStyle = '#b7dfc073';
        p.lineWidth = 9;
        p.stroke();
    }
    // Paint every border before every interior, so junctions have no internal outline.
    for (const pass of [0, 1, 2])
        for (const road of landscape.roads) {
            if (!intersects(road.bounds, x, y, SECTOR_SIZE)) continue;
            trace(p, road.points, false);
            p.lineCap = 'round';
            p.lineJoin = 'round';
            p.strokeStyle = pass === 0 ? '#ab95652b' : pass === 1 ? '#bca36e66' : material(5);
            p.lineWidth = road.width + (pass === 0 ? 48 : pass === 1 ? 20 : 0);
            p.stroke();
        }
    for (const bridge of landscape.bridges) {
        const left = bridge.x - bridge.w / 2,
            top = bridge.y - bridge.h / 2;
        if (
            left > x + SECTOR_SIZE ||
            left + bridge.w < x ||
            top > y + SECTOR_SIZE ||
            top + bridge.h < y
        )
            continue;
        if (bridgeImage?.complete && bridgeImage.naturalWidth) {
            // Measured opaque deck, keeping transparent generated-sheet margins out of geometry.
            p.drawImage(bridgeImage, 50, 112, 1880, 540, left, top, bridge.w, bridge.h);
            continue;
        }
        p.fillStyle = '#322d2380';
        p.fillRect(left, top + 14, bridge.w, bridge.h);
        p.fillStyle = '#826342';
        p.fillRect(left, top, bridge.w, bridge.h);
        for (let dx = 0; dx < bridge.w; dx += 20) {
            p.fillStyle = dx % 40 === 0 ? '#b49462' : '#a88857';
            p.fillRect(left + dx + 1, top + 6, 18, bridge.h - 12);
            p.fillStyle = '#d2b67a60';
            p.fillRect(left + dx + 3, top + 12, 2, bridge.h - 24);
        }
        p.fillStyle = '#5c4731';
        p.fillRect(left, top, bridge.w, 7);
        p.fillRect(left, top + bridge.h - 7, bridge.w, 7);
    }
    cache.set(key, result);
    // Bounded 24 MB of terrain pixels; moving never retains the whole world in canvases.
    if (cache.size > 24) cache.delete(cache.keys().next().value);
    return result;
}
function landscapeActive() {
    return (
        !!session.landscape &&
        session.landscapeMap === session.tileMap &&
        session.landscape.region === player.currentRegion
    );
}
function warmAhead(landscape, camera, firstX, lastX, firstY, lastY) {
    const dx = previousView ? camera.x - previousView.x : 0,
        dy = previousView ? camera.y - previousView.y : 1;
    previousView = { x: camera.x, y: camera.y };
    if (warming || typeof requestIdleCallback !== 'function') return;
    const candidates = [];
    if (Math.abs(dx) > Math.abs(dy))
        for (let row = firstY; row <= lastY; row++)
            candidates.push([dx > 0 ? lastX + 1 : firstX - 1, row]);
    else
        for (let col = firstX; col <= lastX; col++)
            candidates.push([col, dy < 0 ? firstY - 1 : lastY + 1]);
    const target = candidates.find(([col, row]) => !cache.has(`${col}:${row}`));
    if (!target) return;
    warming = true;
    requestIdleCallback(
        () => {
            warming = false;
            if (cachedLandscape === landscape) sector(landscape, ...target);
        },
        { timeout: 250 },
    );
}
function drawLandscape(context, camera, canvas) {
    if (!landscapeActive()) return false;
    if (cachedLandscape !== session.landscape) {
        cache.clear();
        cachedLandscape = session.landscape;
    }
    const firstX = Math.floor(camera.x / SECTOR_SIZE),
        lastX = Math.floor((camera.x + canvas.width) / SECTOR_SIZE),
        firstY = Math.floor(camera.y / SECTOR_SIZE),
        lastY = Math.floor((camera.y + canvas.height) / SECTOR_SIZE);
    for (let row = firstY; row <= lastY; row++)
        for (let col = firstX; col <= lastX; col++)
            context.drawImage(
                sector(session.landscape, col, row),
                col * SECTOR_SIZE - camera.x,
                row * SECTOR_SIZE - camera.y,
            );
    warmAhead(session.landscape, camera, firstX, lastX, firstY, lastY);
    // Sparse translucent wave highlights animate without redrawing the lake texture.
    const t = performance.now() / 1000;
    context.strokeStyle = '#d6f4d72c';
    context.lineWidth = 1;
    for (let y = Math.floor(camera.y / 180) * 180; y < camera.y + canvas.height; y += 180)
        for (let x = Math.floor(camera.x / 210) * 210; x < camera.x + canvas.width; x += 210) {
            if (
                !waterAt(session.landscape, x, y) ||
                session.landscape.bridges.some(
                    (b) => Math.abs(x - b.x) < b.w / 2 && Math.abs(y - b.y) < b.h / 2,
                )
            )
                continue;
            const offset = Math.sin(t * 1.4 + x * 0.01) * 8;
            context.beginPath();
            context.ellipse(x - camera.x, y - camera.y + offset, 24, 3, 0, 0, Math.PI);
            context.stroke();
        }
    return true;
}
function visibleLandscapeProps(camera, canvas) {
    if (!landscapeActive()) return [];
    const props = new Set();
    for (
        let row = Math.floor(camera.y / SECTOR_SIZE);
        row <= Math.floor((camera.y + canvas.height) / SECTOR_SIZE);
        row++
    )
        for (
            let col = Math.floor(camera.x / SECTOR_SIZE);
            col <= Math.floor((camera.x + canvas.width) / SECTOR_SIZE);
            col++
        ) {
            for (const prop of session.landscape.buckets.get(`${col}:${row}`) || [])
                if (
                    prop.x + prop.width > camera.x &&
                    prop.x - prop.width < camera.x + canvas.width &&
                    prop.y + prop.height > camera.y &&
                    prop.y - prop.height < camera.y + canvas.height
                )
                    props.add(prop);
        }
    return [...props];
}
function drawLandscapeProp(context, camera, prop) {
    const x = prop.x + prop.w / 2 - camera.x,
        feet = prop.y + prop.h - camera.y;
    context.fillStyle = '#10251f40';
    context.beginPath();
    context.ellipse(x + 12, feet - 2, prop.width * 0.32, prop.h * 0.42, 0, 0, Math.PI * 2);
    context.fill();
    const obscuresHero =
        (prop.key === 'tree' || prop.key === 'palm') &&
        prop.y + prop.h > player.y + player.h &&
        prop.y + prop.h - prop.height < player.y + player.h &&
        Math.abs(prop.x + prop.w / 2 - player.x - player.w / 2) < prop.width * 0.38;
    context.save();
    if (obscuresHero) context.globalAlpha = 0.42;
    drawWorldSprite(context, prop.key, x, feet, prop.width, prop.height);
    context.restore();
}
export { drawLandscape, visibleLandscapeProps, drawLandscapeProp };
