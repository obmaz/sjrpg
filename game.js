// ============================================================
//  2D RPG - 자연의 수호자
// ============================================================

// Polyfill for CanvasRenderingContext2D.roundRect
if (!CanvasRenderingContext2D.prototype.roundRect) {
    CanvasRenderingContext2D.prototype.roundRect = function (x, y, w, h, r) {
        if (typeof r === 'number') r = { tl: r, tr: r, br: r, bl: r };
        this.beginPath();
        this.moveTo(x + r.tl, y);
        this.lineTo(x + w - r.tr, y);
        this.quadraticCurveTo(x + w, y, x + w, y + r.tr);
        this.lineTo(x + w, y + h - r.br);
        this.quadraticCurveTo(x + w, y + h, x + w - r.br, y + h);
        this.lineTo(x + r.bl, y + h);
        this.quadraticCurveTo(x, y + h, x, y + h - r.bl);
        this.lineTo(x, y + r.tl);
        this.quadraticCurveTo(x, y, x + r.tl, y);
        this.closePath();
        return this;
    };
}

const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

// ----- Canvas setup -----
function resize() {
    const gameArea = document.getElementById('gameArea');
    if (gameArea) {
        canvas.width = gameArea.clientWidth;
        canvas.height = gameArea.clientHeight;
    } else {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }
}
window.addEventListener('resize', resize);
resize();

// ============================================================
//  SOUND SYSTEM (Web Audio API synthesized sounds)
// ============================================================
let audioCtx = null;
function getAudioCtx() {
    if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    return audioCtx;
}

function playSlashSound() {
    try {
        const ac = getAudioCtx();
        const t = ac.currentTime;
        // Noise burst for slash
        const bufferSize = ac.sampleRate * 0.08;
        const buf = ac.createBuffer(1, bufferSize, ac.sampleRate);
        const data = buf.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            const env = 1 - i / bufferSize;
            data[i] = (Math.random() * 2 - 1) * env * env * 0.4;
        }
        const noise = ac.createBufferSource(); noise.buffer = buf;
        const filter = ac.createBiquadFilter();
        filter.type = 'bandpass'; filter.frequency.value = 2500; filter.Q.value = 1.5;
        const gain = ac.createGain(); gain.gain.setValueAtTime(0.5, t); gain.gain.exponentialRampToValueAtTime(0.01, t + 0.1);
        noise.connect(filter); filter.connect(gain); gain.connect(ac.destination);
        noise.start(t); noise.stop(t + 0.1);
        // Low thump
        const osc = ac.createOscillator(); osc.type = 'triangle'; osc.frequency.setValueAtTime(200, t); osc.frequency.exponentialRampToValueAtTime(60, t + 0.06);
        const g2 = ac.createGain(); g2.gain.setValueAtTime(0.3, t); g2.gain.exponentialRampToValueAtTime(0.01, t + 0.08);
        osc.connect(g2); g2.connect(ac.destination);
        osc.start(t); osc.stop(t + 0.08);
    } catch(e) { /* audio not available */ }
}

function playHitSound() {
    try {
        const ac = getAudioCtx();
        const t = ac.currentTime;
        const osc = ac.createOscillator(); osc.type = 'square'; osc.frequency.setValueAtTime(300, t); osc.frequency.exponentialRampToValueAtTime(80, t + 0.07);
        const g = ac.createGain(); g.gain.setValueAtTime(0.25, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.1);
        osc.connect(g); g.connect(ac.destination);
        osc.start(t); osc.stop(t + 0.1);
    } catch(e) {}
}

function playCoinSound() {
    try {
        const ac = getAudioCtx();
        const t = ac.currentTime;
        [1200, 1800].forEach((freq, i) => {
            const osc = ac.createOscillator(); osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, t + i * 0.05);
            const g = ac.createGain();
            g.gain.setValueAtTime(0.2, t + i * 0.05);
            g.gain.exponentialRampToValueAtTime(0.01, t + i * 0.05 + 0.08);
            osc.connect(g); g.connect(ac.destination);
            osc.start(t + i * 0.05); osc.stop(t + i * 0.05 + 0.08);
        });
    } catch(e) {}
}

function playPlayerHurtSound() {
    try {
        const ac = getAudioCtx();
        const t = ac.currentTime;
        const osc = ac.createOscillator(); osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(200, t); osc.frequency.exponentialRampToValueAtTime(50, t + 0.15);
        const g = ac.createGain(); g.gain.setValueAtTime(0.3, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.2);
        osc.connect(g); g.connect(ac.destination);
        osc.start(t); osc.stop(t + 0.2);
    } catch(e) {}
}

function playChestBreak(isIron) {
    try {
        const ac = getAudioCtx();
        const t = ac.currentTime;
        if (isIron) {
            // Loud metal clang
            const osc = ac.createOscillator(); osc.type = 'triangle';
            osc.frequency.setValueAtTime(300, t); osc.frequency.exponentialRampToValueAtTime(60, t + 0.3);
            const g = ac.createGain(); g.gain.setValueAtTime(0.6, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.35);
            osc.connect(g); g.connect(ac.destination);
            osc.start(t); osc.stop(t + 0.35);
            // Metallic ring
            const osc2 = ac.createOscillator(); osc2.type = 'square';
            osc2.frequency.setValueAtTime(800, t); osc2.frequency.exponentialRampToValueAtTime(400, t + 0.25);
            const g2 = ac.createGain(); g2.gain.setValueAtTime(0.35, t); g2.gain.exponentialRampToValueAtTime(0.01, t + 0.25);
            osc2.connect(g2); g2.connect(ac.destination);
            osc2.start(t); osc2.stop(t + 0.25);
            // Low thump
            const osc3 = ac.createOscillator(); osc3.type = 'sine';
            osc3.frequency.setValueAtTime(80, t); osc3.frequency.exponentialRampToValueAtTime(20, t + 0.15);
            const g3 = ac.createGain(); g3.gain.setValueAtTime(0.5, t); g3.gain.exponentialRampToValueAtTime(0.01, t + 0.15);
            osc3.connect(g3); g3.connect(ac.destination);
            osc3.start(t); osc3.stop(t + 0.15);
        } else {
            // Wood crack - louder, longer
            const bufferSize = ac.sampleRate * 0.25;
            const buf = ac.createBuffer(1, bufferSize, ac.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / bufferSize, 1.5) * 0.8;
            }
            const noise = ac.createBufferSource(); noise.buffer = buf;
            const filter = ac.createBiquadFilter();
            filter.type = 'bandpass'; filter.frequency.value = 500; filter.Q.value = 1.2;
            const g = ac.createGain(); g.gain.setValueAtTime(0.7, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.3);
            noise.connect(filter); filter.connect(g); g.connect(ac.destination);
            noise.start(t); noise.stop(t + 0.3);
            // Wood thump
            const osc = ac.createOscillator(); osc.type = 'triangle';
            osc.frequency.setValueAtTime(120, t); osc.frequency.exponentialRampToValueAtTime(30, t + 0.2);
            const g2 = ac.createGain(); g2.gain.setValueAtTime(0.5, t); g2.gain.exponentialRampToValueAtTime(0.01, t + 0.2);
            osc.connect(g2); g2.connect(ac.destination);
            osc.start(t); osc.stop(t + 0.2);
        }
    } catch(e) {}
}

function playEnemyDeathSound(enemyName) {
    try {
        const ac = getAudioCtx();
        const t = ac.currentTime;
        const name = enemyName || '';
        if (name.includes('슬라임')) {
            const osc = ac.createOscillator(); osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(200, t); osc.frequency.exponentialRampToValueAtTime(40, t + 0.3);
            const g = ac.createGain(); g.gain.setValueAtTime(0.25, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.35);
            osc.connect(g); g.connect(ac.destination);
            osc.start(t); osc.stop(t + 0.35);
        } else if (name.includes('늑대')) {
            const osc = ac.createOscillator(); osc.type = 'sine';
            osc.frequency.setValueAtTime(400, t); osc.frequency.linearRampToValueAtTime(600, t + 0.15);
            osc.frequency.linearRampToValueAtTime(300, t + 0.3);
            const g = ac.createGain(); g.gain.setValueAtTime(0.2, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.35);
            osc.connect(g); g.connect(ac.destination);
            osc.start(t); osc.stop(t + 0.35);
        } else if (name.includes('해골')) {
            const bufferSize = ac.sampleRate * 0.2;
            const buf = ac.createBuffer(1, bufferSize, ac.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                const env = 1 - i / bufferSize;
                data[i] = (Math.random() * 2 - 1) * env * env * 0.3 * Math.sin(i * 0.1);
            }
            const noise = ac.createBufferSource(); noise.buffer = buf;
            const filter = ac.createBiquadFilter();
            filter.type = 'highpass'; filter.frequency.value = 1500;
            const g = ac.createGain(); g.gain.setValueAtTime(0.3, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.25);
            noise.connect(filter); filter.connect(g); g.connect(ac.destination);
            noise.start(t); noise.stop(t + 0.25);
        } else if (name.includes('메이지')) {
            const osc = ac.createOscillator(); osc.type = 'sine';
            osc.frequency.setValueAtTime(800, t); osc.frequency.exponentialRampToValueAtTime(200, t + 0.25);
            const g = ac.createGain(); g.gain.setValueAtTime(0.2, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.3);
            osc.connect(g); g.connect(ac.destination);
            osc.start(t); osc.stop(t + 0.3);
            const osc2 = ac.createOscillator(); osc2.type = 'sine';
            osc2.frequency.setValueAtTime(1000, t + 0.05); osc2.frequency.exponentialRampToValueAtTime(150, t + 0.3);
            const g2 = ac.createGain(); g2.gain.setValueAtTime(0.15, t + 0.05); g2.gain.exponentialRampToValueAtTime(0.01, t + 0.3);
            osc2.connect(g2); g2.connect(ac.destination);
            osc2.start(t + 0.05); osc2.stop(t + 0.3);
        } else if (name.includes('보스') || name.includes('트롤')) {
            const osc = ac.createOscillator(); osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(150, t); osc.frequency.linearRampToValueAtTime(300, t + 0.1);
            osc.frequency.exponentialRampToValueAtTime(30, t + 0.5);
            const g = ac.createGain(); g.gain.setValueAtTime(0.3, t); g.gain.linearRampToValueAtTime(0.4, t + 0.1);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.55);
            osc.connect(g); g.connect(ac.destination);
            osc.start(t); osc.stop(t + 0.55);
        } else if (name.includes('골렘')) {
            const bufferSize = ac.sampleRate * 0.3;
            const buf = ac.createBuffer(1, bufferSize, ac.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                const env = 1 - i / bufferSize;
                data[i] = (Math.random() * 2 - 1) * env * env * 0.35;
            }
            const noise = ac.createBufferSource(); noise.buffer = buf;
            const filter = ac.createBiquadFilter();
            filter.type = 'lowpass'; filter.frequency.value = 600;
            const g = ac.createGain(); g.gain.setValueAtTime(0.4, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.35);
            noise.connect(filter); filter.connect(g); g.connect(ac.destination);
            noise.start(t); noise.stop(t + 0.35);
        } else {
            const osc = ac.createOscillator(); osc.type = 'square';
            osc.frequency.setValueAtTime(250, t); osc.frequency.exponentialRampToValueAtTime(60, t + 0.2);
            const g = ac.createGain(); g.gain.setValueAtTime(0.2, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.25);
            osc.connect(g); g.connect(ac.destination);
            osc.start(t); osc.stop(t + 0.25);
        }
    } catch(e) {}
}

// ============================================================
//  BACKGROUND MUSIC (ambient)
// ============================================================
let bgMusicEl = null;
function startBgMusic() {
    if (!bgMusicEl) bgMusicEl = document.getElementById('bgMusic');
    if (!bgMusicEl) return;
    bgMusicEl.volume = 0.3;
    bgMusicEl.play().catch(() => {
        // Autoplay blocked — retry on next user interaction
        const tryPlay = () => {
            if (bgMusicEl) bgMusicEl.play().catch(() => {});
        };
        document.addEventListener('click', tryPlay, { once: true });
        document.addEventListener('keydown', tryPlay, { once: true });
    });
}

function stopBgMusic() {
    if (bgMusicEl) {
        bgMusicEl.pause();
        bgMusicEl.currentTime = 0;
    }
}

// ============================================================
//  SIMPLE VALUE NOISE for natural terrain
// ============================================================
class SimpleNoise {
    constructor(seed = 42) {
        this.perm = new Uint8Array(512);
        const p = new Uint8Array(256);
        for (let i = 0; i < 256; i++) p[i] = i;
        // Fisher-Yates shuffle with seed
        let s = seed;
        for (let i = 255; i > 0; i--) {
            s = (s * 16807 + 0) % 2147483647;
            const j = s % (i + 1);
            [p[i], p[j]] = [p[j], p[i]];
        }
        for (let i = 0; i < 512; i++) this.perm[i] = p[i & 255];
    }

    _fade(t) { return t * t * t * (t * (t * 6 - 15) + 10); }
    _lerp(a, b, t) { return a + t * (b - a); }
    _grad(hash, x, y) {
        const h = hash & 3;
        const u = h < 2 ? x : y;
        const v = h < 2 ? y : x;
        return ((h & 1) === 0 ? u : -u) + ((h & 2) === 0 ? v : -v);
    }

    noise2D(x, y) {
        const X = Math.floor(x) & 255;
        const Y = Math.floor(y) & 255;
        const xf = x - Math.floor(x);
        const yf = y - Math.floor(y);
        const u = this._fade(xf);
        const v = this._fade(yf);
        const p = this.perm;
        const aa = p[p[X] + Y];
        const ab = p[p[X] + Y + 1];
        const ba = p[p[X + 1] + Y];
        const bb = p[p[X + 1] + Y + 1];
        return this._lerp(
            this._lerp(this._grad(aa, xf, yf), this._grad(ba, xf - 1, yf), u),
            this._lerp(this._grad(ab, xf, yf - 1), this._grad(bb, xf - 1, yf - 1), u),
            v
        );
    }

    // Fractal / fbm noise for organic terrain
    fbm(x, y, octaves = 4, lacunarity = 2.0, gain = 0.5) {
        let value = 0;
        let amplitude = 1;
        let frequency = 1;
        let max = 0;
        for (let i = 0; i < octaves; i++) {
            value += amplitude * this.noise2D(x * frequency, y * frequency);
            max += amplitude;
            amplitude *= gain;
            frequency *= lacunarity;
        }
        return value / max;
    }
}

// ============================================================
//  TERRAIN GENERATION
// ============================================================
const TILE_SIZE = 32;
const MAP_W = 80;
const MAP_H = 60;
const FOUNTAIN_CX = MAP_W / 2 * TILE_SIZE;
const FOUNTAIN_CY = MAP_H / 2 * TILE_SIZE;

const TILE = {
    WATER_DEEP:  { char: '~', color: '#104878',  name: '깊은 물',   solid: true  },
    WATER:       { char: '≈', color: '#1868a0',  name: '물',        solid: true  },
    SAND:        { char: '·', color: '#d8c898',  name: '모래',      solid: false },
    GRASS:       { char: '∴', color: '#609840',  name: '풀밭',      solid: false },
    GRASS_TALL:  { char: '※', color: '#488030',  name: '긴 풀',     solid: false },
    DIRT:        { char: '∴', color: '#b89060',  name: '흙길',      solid: false },
    ROCK:        { char: '◆', color: '#788078',  name: '바위',      solid: true  },
    TREE:        { char: '♣', color: '#306828',  name: '나무',      solid: true  },
    FLOWER:      { char: '❀', color: '#d84068',  name: '꽃',        solid: false },
    BUSH:        { char: '♠', color: '#408030',  name: '덤불',      solid: true  },
    PATH:        { char: '·', color: '#c8b070',  name: '길',        solid: false },
    WALL:        { char: '▦', color: '#686868',  name: '돌담',      solid: true  },
};

let tileMap = [];       // tileMap[y][x] = index into TILE keys
const TILE_KEYS = Object.keys(TILE);

function generateMap(seed) {
    const noise = new SimpleNoise(seed);
    const moistureNoise = new SimpleNoise(seed + 9999);
    tileMap = [];

    for (let y = 0; y < MAP_H; y++) {
        tileMap[y] = [];
        for (let x = 0; x < MAP_W; x++) {
            // Scale for natural-looking terrain
            const nx = x / MAP_W;
            const ny = y / MAP_H;

            // Height: -1 to 1
            const h = noise.fbm(x * 0.03, y * 0.03, 5, 2.3, 0.55);
            // Moisture: -1 to 1
            const m = moistureNoise.fbm(x * 0.04, y * 0.04, 4, 2.1, 0.5);

            // Add some large-scale variation for continents
            const continent = noise.noise2D(x * 0.008, y * 0.008) * 0.6;

            const height = h + continent * 0.4;
            const moisture = m;

            let tile;
            if (height < -0.35) {
                tile = 'WATER_DEEP';
            } else if (height < -0.20) {
                tile = 'WATER';
            } else if (height < -0.08) {
                tile = 'SAND';
            } else if (height < -0.02) {
                tile = moisture > 0.1 ? 'GRASS_TALL' : 'GRASS';
            } else if (height < 0.15) {
                tile = moisture > 0.2 ? 'TREE' : (moisture > 0 ? 'GRASS_TALL' : 'GRASS');
            } else if (height < 0.30) {
                tile = moisture > 0.15 ? 'TREE' : (Math.random() < 0.3 ? 'BUSH' : 'ROCK');
            } else {
                tile = 'ROCK';
            }

            // Scatter flowers on grass
            if ((tile === 'GRASS' || tile === 'GRASS_TALL') && Math.abs(noise.noise2D(x * 1.7, y * 1.7)) > 0.6) {
                tile = 'FLOWER';
            }
            // Create paths between areas (Zelda-like dirt paths)
            if (tile === 'GRASS' || tile === 'GRASS_TALL') {
                const pathNoise = Math.abs(noise.noise2D(x * 0.06 + 50, y * 0.06 + 50));
                if (pathNoise < 0.08) tile = 'PATH';
            }

            tileMap[y][x] = TILE_KEYS.indexOf(tile);
        }
    }

    // Clear fountain area at center (make it larger plaza with village)
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    const plazaR = 7; // enlarged from 4
    for (let y = fcy - plazaR; y <= fcy + plazaR; y++) {
        for (let x = fcx - plazaR; x <= fcx + plazaR; x++) {
            if (y >= 0 && y < MAP_H && x >= 0 && x < MAP_W) {
                const dist = Math.sqrt((x - fcx) ** 2 + (y - fcy) ** 2);
                if (dist < 6.5) {
                    tileMap[y][x] = TILE_KEYS.indexOf('SAND');
                } else if (dist < 7.5) {
                    tileMap[y][x] = TILE_KEYS.indexOf('DIRT');
                }
            }
        }
    }
    // Place fountain tile marker
    tileMap[fcy][fcx] = TILE_KEYS.indexOf('GRASS');

    // Add decorative walls around fountain plaza (larger ring)
    const wallR = 6;
    for (let y = fcy - wallR; y <= fcy + wallR; y++) {
        for (let x = fcx - wallR; x <= fcx + wallR; x++) {
            if (y < 0 || y >= MAP_H || x < 0 || x >= MAP_W) continue;
            const dist = Math.sqrt((x - fcx) ** 2 + (y - fcy) ** 2);
            if (dist > 6.2 && dist < 7.0 && tileMap[y][x] !== TILE_KEYS.indexOf('WATER') && tileMap[y][x] !== TILE_KEYS.indexOf('WATER_DEEP')) {
                if (Math.abs(dist - 6.5) < 0.35 && (x + y) % 3 !== 0) {
                    tileMap[y][x] = TILE_KEYS.indexOf('WALL');
                }
            }
        }
    }

    // Clear village buildings around the plaza (wider ring)
    for (let y = fcy - 10; y <= fcy + 10; y++) {
        for (let x = fcx - 10; x <= fcx + 10; x++) {
            if (y < 0 || y >= MAP_H || x < 0 || x >= MAP_W) continue;
            const dist = Math.sqrt((x - fcx) ** 2 + (y - fcy) ** 2);
            if (dist > 7.5 && dist < 10.5 && tileMap[y][x] !== TILE_KEYS.indexOf('WATER') && tileMap[y][x] !== TILE_KEYS.indexOf('WATER_DEEP')) {
                // Create village paths and clearings
                if ((x + y) % 4 === 0 || (x - y) % 4 === 0) {
                    tileMap[y][x] = TILE_KEYS.indexOf('PATH');
                }
            }
        }
    }

    // Ensure map connectivity - fill isolated walkable areas
    ensureConnectivity();
}

function ensureConnectivity() {
    const visited = new Uint8Array(MAP_W * MAP_H);
    const queue = [];
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    queue.push(fcx, fcy);
    visited[fcy * MAP_W + fcx] = 1;

    const dirs = [[0, -1], [0, 1], [-1, 0], [1, 0]];
    while (queue.length > 0) {
        const cx = queue.shift();
        const cy = queue.shift();
        for (const [dx, dy] of dirs) {
            const nx = cx + dx, ny = cy + dy;
            if (nx < 0 || ny < 0 || nx >= MAP_W || ny >= MAP_H) continue;
            if (visited[ny * MAP_W + nx]) continue;
            if (!isSolid(nx, ny)) {
                visited[ny * MAP_W + nx] = 1;
                queue.push(nx, ny);
            }
        }
    }

    // Convert unreachable walkable tiles to deep water
    for (let y = 0; y < MAP_H; y++) {
        for (let x = 0; x < MAP_W; x++) {
            if (!visited[y * MAP_W + x] && !isSolid(x, y)) {
                tileMap[y][x] = TILE_KEYS.indexOf('WATER_DEEP');
            }
        }
    }
}

function getTile(x, y) {
    if (x < 0 || y < 0 || x >= MAP_W || y >= MAP_H) return TILE_KEYS.indexOf('WATER_DEEP');
    return tileMap[y]?.[x] ?? TILE_KEYS.indexOf('WATER_DEEP');
}

function isSolid(x, y) {
    const idx = getTile(x, y);
    return TILE[TILE_KEYS[idx]].solid;
}

function isWater(x, y) {
    const tileKey = TILE_KEYS[getTile(x, y)];
    return tileKey === 'WATER' || tileKey === 'WATER_DEEP';
}

// ============================================================
//  CAMERA
// ============================================================
const camera = { x: 0, y: 0 };

function updateCamera(targetX, targetY) {
    camera.x = targetX - canvas.width / 2;
    camera.y = targetY - canvas.height / 2;
    // Clamp
    camera.x = Math.max(0, Math.min(MAP_W * TILE_SIZE - canvas.width, camera.x));
    camera.y = Math.max(0, Math.min(MAP_H * TILE_SIZE - canvas.height, camera.y));
}

// ============================================================
//  INPUT
// ============================================================
const keys = {};
window.addEventListener('keydown', e => {
    keys[e.key.toLowerCase()] = true;
    keys[e.code] = true;
    // Prevent default for game keys only
    const k = e.key.toLowerCase();
    if (['arrowleft','arrowright','arrowup','arrowdown',' '].includes(k) ||
        ['KeyA','KeyD','KeyW','KeyS','KeyJ','KeyI','KeyN','KeyK','KeyU','KeyE','Space','Escape'].includes(e.code)) {
        e.preventDefault();
    }
    // Toggle inventory with I or Escape
    if (e.code === 'KeyI' || e.code === 'Escape') {
        keys[e.key.toLowerCase()] = false;
        keys[e.code] = false;
        if (compendiumOpen) {
            toggleCompendium();
        } else if (shopOpen) {
            closeShop();
        } else if (gamePaused) {
            const ap = document.getElementById('appearancePanel');
            if (ap && !ap.classList.contains('hidden')) {
                closeAppearancePanel();
            } else {
                closeDialog();
            }
        } else {
            toggleInventory();
        }
    }
    // Aux weapon with N or K
    if (e.code === 'KeyN' || e.code === 'KeyK') {
        keys[e.key.toLowerCase()] = false;
        keys[e.code] = false;
        useAuxWeapon();
    }
    // Cycle aux weapon with Q
    if (e.code === 'KeyQ') {
        keys[e.key.toLowerCase()] = false;
        keys[e.code] = false;
        cycleAuxWeapon();
    }
    // Dismount with U
    if (e.code === 'KeyU') {
        keys[e.key.toLowerCase()] = false;
        keys[e.code] = false;
        dismountPlayer();
    }
    // Use item with 1/2/3
    if (e.code === 'Digit1' || e.code === 'Digit2' || e.code === 'Digit3') {
        keys[e.key.toLowerCase()] = false;
        keys[e.code] = false;
        const idx = parseInt(e.code.replace('Digit', '')) - 1;
        useItem(idx);
    }
    // Compendium with C
    if (e.code === 'KeyC') {
        keys[e.key.toLowerCase()] = false;
        keys[e.code] = false;
        toggleCompendium();
    }
    // NPC interaction with E
    if (e.code === 'KeyE') {
        keys[e.key.toLowerCase()] = false;
        keys[e.code] = false;
        if (shopOpen) {
            closeShop();
        } else if (gamePaused) {
            // Check if appearance panel is open
            const ap = document.getElementById('appearancePanel');
            if (ap && !ap.classList.contains('hidden')) {
                closeAppearancePanel();
            } else {
                closeDialog();
            }
        } else {
            interactNPC();
        }
    }
    // Inventory keyboard navigation
    if (invOpen && (e.code === 'ArrowUp' || e.code === 'ArrowDown' || e.code === 'ArrowLeft' || e.code === 'ArrowRight')) {
        navigateInventory(e.code);
    }
    if (invOpen && e.code === 'Enter') {
        selectInventoryItem();
    }
});
window.addEventListener('keyup', e => {
    keys[e.key.toLowerCase()] = false;
    keys[e.code] = false;
});

// ============================================================
//  PLAYER
// ============================================================
const player = {
    x: MAP_W * TILE_SIZE / 2,
    y: MAP_H * TILE_SIZE / 2,
    w: 24,
    h: 28,
    speed: 225,       // pixels per second (1.25x)
    hp: 100,
    maxHp: 100,
    atk: 2,
    weapon: WEAPONS[0],   // 현재 장착 무기
    auxWeapon: null,
    auxWeapons: [],      // inventory of aux weapons
    auxCooldown: 0,
    dir: 0,           // 0=down, 1=left, 2=up, 3=right
    animTimer: 0,
    animFrame: 0,
    attackTimer: 0,
    attackCooldown: 0.4,  // seconds (overridden by weapon)
    invincible: 0,
    gold: 0,
    comboHits: 0,       // 연속 타격 횟수
    stage: 1,            // 현재 단계
    kills: 0,            // 처치 수
    damageDealt: 0,      // 누적 피해량
    shieldActive: 0,     // 방패 남은 시간
    mount: null,          // 현재 탄 탈것 (null = 도보)
    activeQuests: [],
    completedQuests: [],
    killsByName: {},
    items: [],           // consumable items (max 3)
    collection: { weapons: [], items: [], enemies: [] }, // 도감: 획득한 무기/아이템/적 ID
    currentRegion: 'forest', // 'forest' | 'desert'
    gameTime: 600,       // 10 minutes in seconds
    maxGameTime: 600,
    poisonTimer: 0,      // 남은 독 시간 (초)
    poisonTick: 0,       // 독 틱 타이머
    visionReduction: 0,  // 시야 감소 타이머 (초)
    speedBoost: 0,       // 스피드 포션 남은 시간 (초)
    bossKilled: false,   // 현재 스테이지 보스 처치 여부
    playerFace: '😊',    // 캐릭터 외관
    _comboTimer: 0,
    _desertUnlocked: false,
};

const inventory = [];   // array of weapon objects

// ============================================================
//  ENEMIES
// ============================================================
const enemies = [];

function spawnEnemy(type, x, y, level = null) {
    const t = { ...type };
    const stageMult = 1 + (player.stage - 1) * 0.25;
    const bossHpMult = t.isBoss ? 1.3 : 1.0; // 보스는 체력 1.3배
    enemies.push({
        x, y,
        w: t.size,
        h: t.size,
        hp: Math.floor(t.hp * stageMult * bossHpMult),
        maxHp: Math.floor(t.hp * stageMult * bossHpMult),
        atk: Math.floor(t.atk * stageMult),
        speed: (t.speed + (Math.random() - 0.5) * 30) * (1 + (player.stage - 1) * 0.05),
        name: t.name,
        icon: t.icon,
        color: t.color,
        dropRate: Math.min(1, t.dropRate + (player.stage - 1) * 0.03),
        dropPool: t.dropPool,
        isBoss: t.isBoss || false,
        megaBoss: t.megaBoss || false,
        ranged: t.ranged || false,
        flying: t.flying || false,
        rangeCooldown: t.rangeCooldown || 2,
        projSpeed: t.projSpeed || 250,
        level: level != null ? level : player.stage + Math.floor(Math.random() * 3),
        animTimer: Math.random() * Math.PI * 2,
        state: 'wander',
        stateTimer: 0,
        attackCooldown: 0,
        rangeAttackCd: 1,
        hurtTimer: 0,
        frozen: 0,
        _knockbackX: 0,
        _knockbackY: 0,
        dir: 0,
        wanderTarget: { x, y },
    });
}

// Spawn a non-boss enemy at tile (ex, ey) chosen by its distance from the fountain,
// using the per-map rules in data/spawns.js. Level scales with that distance.
function spawnByDistance(region, ex, ey) {
    const pool = region === 'desert' ? DESERT_ENEMY_TYPES : ENEMY_TYPES;
    const px = ex * TILE_SIZE + TILE_SIZE / 2;
    const py = ey * TILE_SIZE + TILE_SIZE / 2;
    const dist = distance(px, py, FOUNTAIN_CX, FOUNTAIN_CY);
    const { idx, tier } = pickSpawnType(region, dist);
    const type = pool[Math.min(idx, pool.length - 1)];
    if (!type || type.isBoss) return;
    spawnEnemy(type, px, py, spawnLevelForTier(tier));
}

function spawnBoss(bossData, x, y) {
    const t = { ...bossData };
    const stageMult = 1 + (player.stage - 1) * 0.25;
    const bossHpMult = 1.3; // 모든 보스 체력 1.3배
    enemies.push({
        x, y,
        w: t.size, h: t.size,
        hp: Math.floor(t.hp * stageMult * bossHpMult),
        maxHp: Math.floor(t.hp * stageMult * bossHpMult),
        atk: Math.floor(t.atk * stageMult),
        speed: t.speed,
        name: t.name,
        icon: '', color: t.color,
        dropRate: 1.0, dropPool: ['legend'],
        isBoss: true, megaBoss: true,
        ranged: t.ranged || false,
        rangeCooldown: t.rangeCooldown || 2,
        rangeDmg: t.rangeDmg || t.atk,
        projSpeed: t.projSpeed || 180,
        destroyTerrain: t.destroyTerrain || false,
        spawnMinions: t.spawnMinions || false,
        minionType: t.minionType || 3,
        spawnCooldown: t.spawnCooldown || 8,
        spawnCount: t.spawnCount || 2,
        _spawnTimer: t.spawnCooldown || 8,
        gold: t.gold || 500,
        flying: false,
        level: player.stage + 5,
        animTimer: Math.random() * Math.PI * 2,
        state: 'wander', stateTimer: 0,
        attackCooldown: 0, rangeAttackCd: 1,
        hurtTimer: 0, frozen: 0,
        _knockbackX: 0, _knockbackY: 0,
        dir: 0,
        wanderTarget: { x, y },
    });
    addMessage(`👹 ${t.name} 등장! ${t.desc}`, 'damage');
}

function spawnEnemies() {
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    const enemyCount = 20;
    for (let i = 0; i < enemyCount; i++) {
        const { x: ex, y: ey } = randomSpawnTile(4, (txi, tyi, x, y) =>
            !isSolid(txi, tyi) && !isWater(txi, tyi) &&
            distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 200 &&
            distance(x, y, fcx, fcy) >= 5);
        spawnByDistance('forest', ex, ey);
    }

    // Spawn random boss
    const bossData = getRandomBoss();
    const { x: bx, y: by } = randomSpawnTile(8, (txi, tyi, x, y) =>
        !isSolid(txi, tyi) && !isWater(txi, tyi) &&
        distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 600);
    spawnBoss(bossData, bx * TILE_SIZE + TILE_SIZE / 2, by * TILE_SIZE + TILE_SIZE / 2);
}

function spawnMoreEnemies() {
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    const count = 5 + player.stage * 2;
    const region = player.currentRegion === 'desert' ? 'desert' : 'forest';

    for (let i = 0; i < count; i++) {
        const { x: ex, y: ey } = randomSpawnTile(3, (txi, tyi, x, y) =>
            !isSolid(txi, tyi) && !isWater(txi, tyi) &&
            distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 180 &&
            distance(x, y, fcx, fcy) >= 5, 30);
        spawnByDistance(region, ex, ey);
    }
}

// Stage-gated NPC definitions
const STAGE_NPCS = {
    2: [{ icon: '🛡️', name: '경비대장', dialog: '해골 전사들을 처치해주게!', quests: ['hunt_skeletons'] }],
};

function spawnStageNPCs(oldStage, newStage) {
    for (let s = oldStage + 1; s <= newStage; s++) {
        const defs = STAGE_NPCS[s];
        if (!defs) continue;
        for (const def of defs) {
            let nx, ny;
            for (let tries = 0; tries < 50; tries++) {
                nx = 5 + Math.random() * (MAP_W - 10);
                ny = 5 + Math.random() * (MAP_H - 10);
                if (!isSolid(Math.floor(nx), Math.floor(ny)) && !isWater(Math.floor(nx), Math.floor(ny)) &&
                    distance(nx * TILE_SIZE, ny * TILE_SIZE, player.x, player.y) > 100) break;
            }
            npcs.push({
                x: nx * TILE_SIZE + TILE_SIZE / 2 - 12,
                y: ny * TILE_SIZE + TILE_SIZE / 2 - 14,
                w: 24, h: 28,
                icon: def.icon, name: def.name, dialog: def.dialog,
                quests: def.quests,
            });
            addMessage(`🆕 ${def.icon} ${def.name}이(가) 마을에 나타났다!`, 'loot');
        }
    }
}

function distance(x1, y1, x2, y2) {
    return Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
}

// Live enemies whose center is within `radius` of (cx, cy).
// Returns a snapshot array so callers can kill enemies mid-loop without skipping any.
function enemiesInRadius(cx, cy, radius) {
    return enemies.filter(e =>
        e.hp > 0 && distance(cx, cy, e.x + e.w / 2, e.y + e.h / 2) < radius + e.w / 2);
}

// Pick a random tile position (tile coords as floats), retrying until ok(txi, tyi, x, y)
// is true. Caps retries so world generation never hangs on a crowded/unlucky map; if no
// spot qualifies it returns the last candidate.
function randomSpawnTile(margin, ok, maxTries = 80) {
    let x = MAP_W / 2, y = MAP_H / 2;
    for (let i = 0; i < maxTries; i++) {
        x = margin + Math.random() * (MAP_W - margin * 2);
        y = margin + Math.random() * (MAP_H - margin * 2);
        if (ok(Math.floor(x), Math.floor(y), x, y)) break;
    }
    return { x, y };
}

// ============================================================
//  PARTICLES
// ============================================================
const particles = [];

function spawnParticles(x, y, color, count = 8) {
    for (let i = 0; i < count; i++) {
        const angle = Math.random() * Math.PI * 2;
        const speed = 60 + Math.random() * 140;
        particles.push({
            x, y,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life: 0.4 + Math.random() * 0.4,
            maxLife: 0.4 + Math.random() * 0.4,
            color,
            size: 2 + Math.random() * 3,
        });
    }
}

// ============================================================
//  PROJECTILES (for ranged weapons)
// ============================================================
const projectiles = [];

function spawnProjectile(x, y, dir, speed, dmg, color, icon, sizeMult = 1) {
    let vx = 0, vy = 0;
    switch (dir) {
        case 0: vy = speed; break;
        case 1: vx = -speed; break;
        case 2: vy = -speed; break;
        case 3: vx = speed; break;
    }
    const baseSize = 6 * sizeMult;
    projectiles.push({ x, y, vx, vy, dmg, color, icon, life: 0.8, size: baseSize });
}

// ============================================================
//  FIRE ZONES (for fire weapons)
// ============================================================
const fireZones = [];
const goldPickups = [];   // map gold
const chests = [];        // breakable chests
const npcs = [];          // NPCs on map
const weaponPickups = []; // weapon drops on ground
let gamePaused = false;   // pause for dialogs
const enemyProjectiles = []; // ranged enemy projectiles
const mounts = [];          // rideable mounts
const portals = [];         // stage portals
const scarecrows = [];      // training dummies (허수아비)

const MOUNT_TYPES = [
    { id: 'bicycle',  name: '자전거',   icon: '🚲', speed: 250, color: '#888888', waterOnly: false },
    { id: 'horse',    name: '말',       icon: '🐴', speed: 320, color: '#8B6914', waterOnly: false },
    { id: 'motor',    name: '오토바이', icon: '🏍️', speed: 400, color: '#cc3333', waterOnly: false },
    { id: 'boat',     name: '배',       icon: '🚤', speed: 180, color: '#d4a860', waterOnly: true },
];

// ============================================================
//  CONSUMABLE ITEMS
// ============================================================
const ITEMS = [
    { id: 'healpot',   name: '회복약',   icon: '🧪', price: 30, desc: 'HP 50 회복', use: 'heal', healAmount: 50 },
    { id: 'bomb',      name: '폭탄',     icon: '💣', price: 60, desc: '넓은 범위 폭발 (ATK 30)', use: 'bomb', bombDmg: 30, bombRange: 90 },
    { id: 'antidote',  name: '해독제',   icon: '🧴', price: 40, desc: '모든 이상상태 해제', use: 'antidote' },
    { id: 'speedpot',  name: '스피드 포션', icon: '⚡', price: 80, desc: '10초간 이동속도 1.5배', use: 'speed' },
    { id: 'returngem', name: '귀환 보석', icon: '💠', price: 500, desc: '분수로 순간이동', use: 'return' },
];

function spawnMount(mountType, x, y) {
    mounts.push({ ...mountType, x, y, w: TILE_SIZE * 1.5, h: TILE_SIZE * 1.2 });
}

function spawnGoldPickup(x, y, amount = 0) {
    if (!amount) amount = 3 + Math.floor(Math.random() * 12);
    goldPickups.push({ x, y, amount, life: 60, bob: Math.random() * Math.PI * 2 });
}

function spawnChest(x, y, chestTypeId) {
    // Random chest type: wooden(65%), iron(15%), trap(10%), mimic(10%)
    const r = Math.random();
    let ctype = 'normal';
    let ct = chestTypeId || 'wooden';
    if (!chestTypeId) {
        if (r < 0.10) ctype = 'trap';
        else if (r < 0.20) ctype = 'mimic';
        else if (r < 0.35) ct = 'iron';
    }
    const ctData = CHEST_TYPES.find(c => c.id === ct) || CHEST_TYPES[0];
    chests.push({
        x, y,
        w: ctData.w, h: ctData.h,
        hp: ctData.hp, maxHp: ctData.hp,
        type: ctype,
        chestData: ctData,
        opened: false,
    });
}

function spawnEnemyProjectile(x, y, vx, vy, dmg, color) {
    enemyProjectiles.push({ x, y, vx, vy, dmg, color, life: 2, size: 5 });
}

function spawnFireZone(x, y, duration, dmg, radius = 40) {
    fireZones.push({ x, y, duration, maxDuration: duration, dmg, radius, timer: 0 });
}

// ============================================================
//  FLOATING TEXT
// ============================================================
const floatingTexts = [];

function spawnFloatingText(x, y, text, color = '#fff') {
    floatingTexts.push({ x, y, text, color, life: 1.0 });
}

// ============================================================
//  MESSAGE LOG
// ============================================================
const msgLogEl = document.getElementById('messageLog');
function addMessage(text, cls = '') {
    const div = document.createElement('div');
    div.className = 'msg ' + cls;
    div.textContent = text;
    msgLogEl.appendChild(div);
    setTimeout(() => div.remove(), 2600);
    // Keep max 5 messages
    while (msgLogEl.children.length > 5) {
        msgLogEl.firstChild.remove();
    }
}

// ============================================================
//  COLLISION
// ============================================================
function collidesWithMap(x, y, w, h) {
    const margin = 4;
    const left = Math.floor((x + margin) / TILE_SIZE);
    const right = Math.floor((x + w - margin) / TILE_SIZE);
    const top = Math.floor((y + margin) / TILE_SIZE);
    const bottom = Math.floor((y + h - margin) / TILE_SIZE);
    for (let ty = top; ty <= bottom; ty++) {
        for (let tx = left; tx <= right; tx++) {
            if (isSolid(tx, ty)) return true;
        }
    }
    return false;
}

function collidesWithEntities(x, y, w, h, self) {
    if (self !== player) {
        if (aabb(x, y, w, h, player.x, player.y, player.w, player.h)) return true;
    }
    for (const e of enemies) {
        if (e === self || e.hp <= 0) continue;
        if (aabb(x, y, w, h, e.x, e.y, e.w, e.h)) return true;
    }
    // Chest collision
    for (const c of chests) {
        if (c.opened) continue;
        if (aabb(x, y, w, h, c.x, c.y, c.w, c.h)) return true;
    }
    return false;
}

function aabb(x1, y1, w1, h1, x2, y2, w2, h2) {
    return x1 < x2 + w2 && x1 + w1 > x2 && y1 < y2 + h2 && y1 + h1 > y2;
}

// ============================================================
//  GAME LOGIC
// ============================================================
let gameOver = false;
let gameVictory = false;
let lastTime = performance.now();

function update(dt) {
    if (!gameStarted || gameOver || gameVictory) return;
    if (gamePaused || invOpen) return;

    // Cap dt
    const dtClamped = Math.min(dt, 0.1);

    updatePlayer(dtClamped);
    updateEnemies(dtClamped);
    updateProjectiles(dtClamped);
    updateEnemyProjectiles(dtClamped);
    updateFireZones(dtClamped);
    updateGoldPickups(dtClamped);
    updateWeaponPickups(dtClamped);
    updateChests(dtClamped);
    updateParticles(dtClamped);
    updateFloatingTexts(dtClamped);
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);

    // Fountain HP regen (costs gold)
    const fountainCX = MAP_W / 2 * TILE_SIZE;
    const fountainCY = MAP_H / 2 * TILE_SIZE;
    const distToFountain = distance(player.x + player.w / 2, player.y + player.h / 2, fountainCX, fountainCY);
    player._fountainTimer = (player._fountainTimer || 0) + dtClamped;
    if (distToFountain < 180 && player.hp < player.maxHp && player.gold > 0 && player._fountainTimer >= 1.0) {
        player._fountainTimer -= 1.0;
        const healAmt = Math.min(3, player.maxHp - player.hp, player.gold);
        player.hp += healAmt;
        player.gold -= healAmt;
        updateUI();
        spawnFloatingText(player.x + player.w / 2, player.y - 16, `-${healAmt}💰`, '#ff8866');
        // Re-check portal condition when gold changes at fountain
        checkPortalSpawn();
    }
    if (distToFountain >= 180) player._fountainTimer = 0;

    // Game timer
    player.gameTime -= dtClamped;
    if (player.gameTime <= 0) {
        player.gameTime = 0;
        showGameOverScreen('⏱ 시간 초과');
        return;
    }

    // Poison timer
    if (player.poisonTimer > 0) {
        player.poisonTimer -= dtClamped;
        player.poisonTick -= dtClamped;
        if (player.poisonTick <= 0) {
            player.poisonTick += 10;
            player.hp -= 1;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#88ff44', 5);
            spawnFloatingText(player.x + player.w / 2, player.y - 8, '☠-1', '#88ff44');
            if (player.hp <= 0) {
                showGameOverScreen('☠️ 독으로 사망');
                return;
            }
        }
        if (player.poisonTimer <= 0) {
            player.poisonTimer = 0;
            player.poisonTick = 0;
            addMessage('☠️ 독이 해독되었습니다!', 'heal');
        }
    }

    // Vision reduction timer
    if (player.visionReduction > 0) {
        player.visionReduction -= dtClamped;
        if (player.visionReduction <= 0) {
            player.visionReduction = 0;
            addMessage('👁️ 시야가 정상으로 돌아왔습니다!', 'info');
        }
    }

    updateUI();

    // Check game over (death)
    if (player.hp <= 0) {
        showGameOverScreen('전투 중 사망');
    }

    // Update quest progress
    updateQuestProgress();

    // Update portals animation
    for (const p of portals) {
        p.animTimer += dtClamped;
    }

    // Update scarecrows
    for (const sc of scarecrows) {
        if (sc.hurtTimer > 0) sc.hurtTimer -= dtClamped;
    }

    // Draw
    draw();
}

function updatePlayer(dt) {
    // Movement - blocked when inventory is open
    let dx = 0, dy = 0;
    if (!invOpen) {
        if (keys['arrowleft'] || keys['a'] || keys['KeyA']) dx -= 1;
        if (keys['arrowright'] || keys['d'] || keys['KeyD']) dx += 1;
        if (keys['arrowup'] || keys['w'] || keys['KeyW']) dy -= 1;
        if (keys['arrowdown'] || keys['s'] || keys['KeyS']) dy += 1;
    }

    // Normalize diagonal
    if (dx !== 0 && dy !== 0) {
        dx *= 0.707;
        dy *= 0.707;
    }

    // Direction
    if (dy > 0.3) player.dir = 0;
    else if (dx < -0.3) player.dir = 1;
    else if (dy < -0.3) player.dir = 2;
    else if (dx > 0.3) player.dir = 3;

    const moving = dx !== 0 || dy !== 0;

    // Speed boost timer
    if (player.speedBoost > 0) {
        player.speedBoost -= dt;
        if (player.speedBoost <= 0) {
            player.speedBoost = 0;
            addMessage('⚡ 스피드 포션 효과가 끝났습니다.', 'info');
        }
    }

    // Collision resolution (separate axes)
    const mount = player.mount;
    const baseSpd = mount ? mount.speed : player.speed;
    const speedMult = player.speedBoost > 0 ? 1.5 : 1.0;
    const spd = baseSpd * speedMult * dt;
    const pw = mount ? mount.w : player.w;
    const ph = mount ? mount.h : player.h;
    const newX = player.x + dx * spd;
    const newY = player.y + dy * spd;

    // Boat: only move on water
    const canMove = (x, y) => {
        if (mount && mount.waterOnly) {
            const tileKey = TILE_KEYS[getTile(Math.floor(x / TILE_SIZE), Math.floor(y / TILE_SIZE))];
            return tileKey === 'WATER' || tileKey === 'WATER_DEEP';
        }
        return true;
    };

    // Boat: skip map collision (only checks water tiles)
    const skipMap = mount && mount.waterOnly;
    if ((skipMap || !collidesWithMap(newX, player.y, pw, ph)) && !collidesWithEntities(newX, player.y, pw, ph, player) && canMove(newX, player.y)) {
        player.x = newX;
    }
    if ((skipMap || !collidesWithMap(player.x, newY, pw, ph)) && !collidesWithEntities(player.x, newY, pw, ph, player) && canMove(player.x, newY)) {
        player.y = newY;
    }

    // Auto-mount: check nearby mounts
    if (!mount) {
        for (const m of mounts) {
            if (aabb(player.x, player.y, player.w, player.h, m.x - 5, m.y - 5, m.w + 10, m.h + 10)) {
                player.mount = m;
                mounts.splice(mounts.indexOf(m), 1);
                addMessage(`🐎 ${m.icon} ${m.name}에 탑승! (U: 내리기)`, 'loot');
                break;
            }
        }
    }

    // Clamp to map
    player.x = Math.max(0, Math.min(MAP_W * TILE_SIZE - (mount ? mount.w : player.w), player.x));
    player.y = Math.max(0, Math.min(MAP_H * TILE_SIZE - (mount ? mount.h : player.h), player.y));

    // Animation
    if (moving) {
        player.animTimer += dt;
        if (player.animTimer > 0.15) {
            player.animTimer = 0;
            player.animFrame = (player.animFrame + 1) % 4;
        }
    } else {
        player.animFrame = 0;
        player.animTimer = 0;
    }

    // Attack - blocked when inventory is open
    player.attackTimer -= dt;
    if (!invOpen && (keys[' '] || keys['Space'] || keys['j'] || keys['KeyJ']) && player.attackTimer <= 0) {
        playerAttack();
    }

    // Combo decay timer
    if (player.comboHits > 0) {
        // combo decays after 2.5 seconds of no hits
        player._comboTimer = (player._comboTimer || 0) + dt;
        if (player._comboTimer > 2.5) {
            player.comboHits = 0;
            player._comboTimer = 0;
        }
    }

    // Invincibility
    if (player.invincible > 0) player.invincible -= dt;
    // Shield timer
    if (player.shieldActive > 0) player.shieldActive -= dt;
    // Aux cooldown
    if (player.auxCooldown > 0) player.auxCooldown -= dt;
}

function playerAttack() {
    const w = player.weapon;
    const cd = w.cooldown || player.attackCooldown;
    player.attackTimer = cd;
    playSlashSound();

    // Check scarecrow hits
    const origin = getAttackOrigin();
    const range = w.range || 36;
    for (const sc of scarecrows) {
        const dist = distance(origin.x, origin.y, sc.x + sc.w/2, sc.y + sc.h/2);
        if (dist < range + sc.w/2) {
            const dmg = w.atk + Math.floor(Math.random() * 3);
            hitScarecrow(sc, dmg);
        }
    }

    // Weapon durability (limited uses)
    if (w.uses !== undefined && w.uses > 0) {
        w.uses--;
        if (w.uses <= 0) {
            addMessage(`💔 ${w.icon} ${w.name}이(가) 부서졌습니다!`, 'damage');
            // Switch back to fist
            player.weapon = WEAPONS[0];
            player.atk = WEAPONS[0].atk;
            player.comboHits = 0;
            player._comboTimer = 0;
            updateUI();
            return;
        }
        updateUI();
    }

    const ability = w.ability || 'basic';

    // Combo tracking
    let comboBonus = 0;
    if (ability === 'combo' || ability === 'combo_wide' || ability === 'legend') {
        player.comboHits++;
        const comboMax = w.comboMax || 5;
        if (player.comboHits >= comboMax) {
            comboBonus = w.comboMult || 2;
            player.comboHits = 0;
            spawnFloatingText(player.x + player.w / 2, player.y - 30, '💥 COMBO!', '#ffd700');
            addMessage(`💥 ${comboMax}연속 타격! ${comboBonus}배 피해!`, 'loot');
        }
    }

    switch (ability) {
        case 'combo':       meleeAttack(w, comboBonus); break;
        case 'wide':        wideAttack(w, 0); break;
        case 'combo_wide':  wideAttack(w, comboBonus); break;
        case 'ranged':      rangedAttack(w); break;
        case 'fire':        fireAttack(w); break;
        case 'legend':      legendAttack(w, comboBonus); break;
        case 'push':        pushAttack(w); break;
        case 'slam':        slamAttack(w); break;
        default:            meleeAttack(w, 0);
    }
}

function getAttackOrigin() {
    let ax = player.x + player.w / 2;
    let ay = player.y + player.h / 2;
    switch (player.dir) {
        case 0: ay += player.h / 2 + 6; break;
        case 1: ax -= player.w / 2 + 6; break;
        case 2: ay -= player.h / 2 + 6; break;
        case 3: ax += player.w / 2 + 6; break;
    }
    return { x: ax, y: ay };
}

// Move a point `dist` px along the player's facing direction (0=down,1=left,2=up,3=right)
function offsetByDir(x, y, dir, dist) {
    switch (dir) {
        case 0: return { x, y: y + dist };
        case 1: return { x: x - dist, y };
        case 2: return { x, y: y - dist };
        case 3: return { x: x + dist, y };
        default: return { x, y };
    }
}

// dir: 0=down, 1=left, 2=up, 3=right → screen-space angle (0=right, π/2=down, π=left, -π/2=up)
function facingAngle(dir) {
    switch (dir) {
        case 0: return Math.PI / 2;   // down
        case 1: return Math.PI;       // left
        case 2: return -Math.PI / 2;  // up
        case 3: return 0;             // right
    }
}

function hitEnemy(enemy, dmg, knockback = true) {
    enemy.hp -= dmg;
    player.damageDealt += dmg;
    playHitSound();
    enemy.hurtTimer = 0.25;
    enemy.state = 'hurt';
    enemy.stateTimer = 0.4;
    spawnFloatingText(enemy.x + enemy.w / 2, enemy.y - 8, `-${dmg}`, '#ff4444');
    // Knockback: push enemy away from player
    if (knockback) {
        const dx = (enemy.x + enemy.w / 2) - (player.x + player.w / 2);
        const dy = (enemy.y + enemy.h / 2) - (player.y + player.h / 2);
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const kbForce = 10 + dmg * 0.6;
        enemy._knockbackX = (dx / dist) * kbForce;
        enemy._knockbackY = (dy / dist) * kbForce;
    }
    // Reset combo decay timer on hit
    player._comboTimer = 0;
    if (enemy.hp <= 0) {
        killEnemy(enemy);
    }
}

function meleeAttack(w, comboBonus) {
    const origin = getAttackOrigin();
    const range = w.range || 36;
    spawnParticles(origin.x, origin.y, w.color, 16);
    // Extra slash trail particles
    const fa = facingAngle(player.dir);
    for (let i = 0; i < 6; i++) {
        const a = fa - 0.5 + Math.random();
        particles.push({
            x: origin.x + Math.cos(a) * 15,
            y: origin.y + Math.sin(a) * 15,
            vx: Math.cos(a) * (200 + Math.random() * 200),
            vy: Math.sin(a) * (200 + Math.random() * 200),
            life: 0.3, maxLife: 0.3, color: '#ffffff', size: 3 + Math.random() * 3,
        });
    }

    const baseDmg = w.atk + Math.floor(Math.random() * 3);
    const dmg = comboBonus > 0 ? Math.floor(baseDmg * comboBonus) : baseDmg;

    const targets = enemiesInRadius(origin.x, origin.y, range);
    for (const enemy of targets) {
        hitEnemy(enemy, dmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, w.color, 16);
    }
    if (targets.length === 0) {
        player.comboHits = 0;
        addMessage('헛스윙!', 'info');
    }
}

function wideAttack(w, comboBonus) {
    const origin = getAttackOrigin();
    const range = w.range || 48;
    const angle = w.wideAngle || 0.3;

    // Wide arc particle effect - more particles, bigger
    const fa = facingAngle(player.dir);
    for (let i = 0; i < 22; i++) {
        const a = fa - angle + (angle * 2 * i / 21);
        const r = range * 0.45;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 300,
            vy: Math.sin(a) * 300,
            life: 0.45,
            maxLife: 0.45,
            color: w.color,
            size: 4 + Math.random() * 3,
        });
    }
    // Extra bright core slash
    for (let i = 0; i < 8; i++) {
        const a = fa - angle * 0.5 + (angle * i / 7);
        const r = range * 0.2;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 400,
            vy: Math.sin(a) * 400,
            life: 0.25, maxLife: 0.25, color: '#ffffff', size: 3,
        });
    }

    const baseDmg = w.atk + Math.floor(Math.random() * 4);
    const dmg = comboBonus > 0 ? Math.floor(baseDmg * comboBonus) : baseDmg;

    const facing = facingAngle(player.dir);
    let hit = false;
    for (const enemy of enemiesInRadius(origin.x, origin.y, range)) {
        const dx = (enemy.x + enemy.w / 2) - origin.x;
        const dy = (enemy.y + enemy.h / 2) - origin.y;
        const dist = distance(origin.x, origin.y, enemy.x + enemy.w / 2, enemy.y + enemy.h / 2);
        let angleDiff = Math.abs(Math.atan2(dy, dx) - facing);
        if (angleDiff > Math.PI) angleDiff = Math.PI * 2 - angleDiff;
        // Hit if inside the arc, or very close (point-blank)
        if (angleDiff < angle + 0.3 || dist < range * 0.5) {
            hitEnemy(enemy, dmg);
            spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, w.color, 6);
            hit = true;
        }
    }
    if (!hit) {
        player.comboHits = 0;
        addMessage('헛스윙!', 'info');
    }
}

function rangedAttack(w) {
    const origin = getAttackOrigin();
    const dmg = w.atk + Math.floor(Math.random() * 3);

    // Magic particles at origin - more intense
    spawnParticles(origin.x, origin.y, w.color, 22);
    // Ring effect - larger
    for (let i = 0; i < 12; i++) {
        const a = Math.PI * 2 * i / 12;
        particles.push({
            x: origin.x, y: origin.y,
            vx: Math.cos(a) * 100, vy: Math.sin(a) * 100,
            life: 0.4, maxLife: 0.4, color: w.color, size: 5 + Math.random() * 3,
        });
    }
    // Second inner ring
    for (let i = 0; i < 8; i++) {
        const a = Math.PI * 2 * i / 8 + 0.2;
        particles.push({
            x: origin.x, y: origin.y,
            vx: Math.cos(a) * 50, vy: Math.sin(a) * 50,
            life: 0.25, maxLife: 0.25, color: '#ffffff', size: 3,
        });
    }

    const sizeMult = w.projectileSize || 1;
    spawnProjectile(origin.x, origin.y, player.dir, w.projectileSpeed || 350, dmg, w.color, w.icon, sizeMult);
}

function fireAttack(w) {
    const origin = getAttackOrigin();

    // Fire slash
    const baseDmg = w.atk + Math.floor(Math.random() * 3);
    const range = w.range || 42;

    // Fire particles - much more intense
    const fa = facingAngle(player.dir);
    for (let i = 0; i < 28; i++) {
        const a = fa - 0.6 + Math.random() * 1.2;
        const r = range * Math.random() * 0.8;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * (100 + Math.random() * 300),
            vy: Math.sin(a) * (100 + Math.random() * 300) - 40,
            life: 0.35 + Math.random() * 0.4,
            maxLife: 0.75,
            color: Math.random() > 0.5 ? '#ff4400' : '#ffaa00',
            size: 4 + Math.random() * 7,
        });
    }
    // Smoke/ember particles
    for (let i = 0; i < 10; i++) {
        particles.push({
            x: origin.x + (Math.random() - 0.5) * 30,
            y: origin.y + (Math.random() - 0.5) * 30,
            vx: (Math.random() - 0.5) * 60, vy: -60 - Math.random() * 80,
            life: 0.5 + Math.random() * 0.5, maxLife: 1.0,
            color: '#444444', size: 3 + Math.random() * 5,
        });
    }

    const targets = enemiesInRadius(origin.x, origin.y, range);
    for (const enemy of targets) {
        hitEnemy(enemy, baseDmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ff4400', 18);
    }

    // Create fire zone on ground in front
    const fz = offsetByDir(player.x + player.w / 2, player.y + player.h / 2, player.dir, 50);
    spawnFireZone(fz.x, fz.y, w.fireDuration || 2, w.fireDmg || 4, 45);

    if (targets.length === 0) {
        player.comboHits = 0;
        addMessage('🔥 불꽃이 땅을 태웠다!', 'info');
    }
}

function legendAttack(w, comboBonus) {
    const origin = getAttackOrigin();
    const range = w.range || 60;

    // Golden explosion
    for (let i = 0; i < 40; i++) {
        const a = Math.random() * Math.PI * 2;
        const r = range * Math.random();
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 350,
            vy: Math.sin(a) * 350,
            life: 0.35 + Math.random() * 0.5,
            maxLife: 0.85,
            color: Math.random() > 0.25 ? '#ffd700' : '#ffffff',
            size: 4 + Math.random() * 8,
        });
    }
    // Inner bright flash
    for (let i = 0; i < 15; i++) {
        const a = Math.random() * Math.PI * 2;
        particles.push({
            x: origin.x + Math.cos(a) * 10,
            y: origin.y + Math.sin(a) * 10,
            vx: Math.cos(a) * 500, vy: Math.sin(a) * 500,
            life: 0.2, maxLife: 0.2, color: '#ffffff', size: 5,
        });
    }

    const baseDmg = w.atk + Math.floor(Math.random() * 5);
    const dmg = comboBonus > 0 ? Math.floor(baseDmg * comboBonus) : baseDmg;

    for (const enemy of enemiesInRadius(origin.x, origin.y, range)) {
        hitEnemy(enemy, dmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ffd700', 12);
    }

    // Fire zone
    spawnFireZone(origin.x, origin.y, w.fireDuration || 1.5, w.fireDmg || 6, 55);

    // Projectile
    spawnProjectile(origin.x, origin.y, player.dir, w.projectileSpeed || 400, Math.floor(baseDmg * 0.7), '#ffd700', '✨', w.projectileSize || 1);
}

function pushAttack(w) {
    const origin = getAttackOrigin();
    const range = w.range || 100;
    const pushForce = w.pushForce || 350;
    const pushAngle = w.pushAngle || 0.6;
    const fa = facingAngle(player.dir);

    // Wind particle effect - more intense
    for (let i = 0; i < 35; i++) {
        const a = fa - pushAngle + Math.random() * pushAngle * 2;
        const r = range * Math.random() * 0.9;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 400,
            vy: Math.sin(a) * 400,
            life: 0.35 + Math.random() * 0.35,
            maxLife: 0.7,
            color: Math.random() > 0.4 ? '#aaddff' : '#ffffff',
            size: 3 + Math.random() * 6,
        });
    }

    // Arc wind lines - more visible
    for (let i = 0; i < 8; i++) {
        const a = fa - pushAngle + (pushAngle * 2 * i / 7);
        const r = range * 0.35;
        particles.push({
            x: origin.x + Math.cos(a) * r,
            y: origin.y + Math.sin(a) * r,
            vx: Math.cos(a) * 600,
            vy: Math.sin(a) * 600,
            life: 0.2, maxLife: 0.2,
            color: '#ffffff', size: 3,
        });
    }

    let hit = false;
    for (const enemy of enemiesInRadius(origin.x, origin.y, range)) {
        const dx = (enemy.x + enemy.w / 2) - origin.x;
        const dy = (enemy.y + enemy.h / 2) - origin.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        let angleDiff = Math.abs(Math.atan2(dy, dx) - fa);
        if (angleDiff > Math.PI) angleDiff = Math.PI * 2 - angleDiff;
        if (angleDiff < pushAngle + 0.4 || dist < range * 0.4) {
            hitEnemy(enemy, w.atk + Math.floor(Math.random() * 3), false);
            // Strong knockback + brief stun
            enemy._knockbackX = (dx / dist) * pushForce;
            enemy._knockbackY = (dy / dist) * pushForce;
            enemy.frozen = 0.3;
            spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#aaddff', 6);
            hit = true;
        }
    }
    addMessage(hit ? `🌀 ${w.name} 강풍! 적 밀어냄!` : '🌀 바람이 허공을 갈랐다...', 'info');
}

function slamAttack(w) {
    const origin = getAttackOrigin();
    const range = w.range || 80;
    const dmg = (w.slamDmg || w.atk) + Math.floor(Math.random() * 4);

    // 360 ring shockwave - bigger and more intense
    for (let i = 0; i < 50; i++) {
        const a = Math.PI * 2 * i / 50;
        particles.push({
            x: origin.x,
            y: origin.y,
            vx: Math.cos(a) * (250 + Math.random() * 350),
            vy: Math.sin(a) * (250 + Math.random() * 350),
            life: 0.3 + Math.random() * 0.25,
            maxLife: 0.55,
            color: '#ddcc88',
            size: 4 + Math.random() * 7,
        });
    }
    // Inner bright ring
    for (let i = 0; i < 30; i++) {
        const a = Math.PI * 2 * i / 30;
        particles.push({
            x: origin.x, y: origin.y,
            vx: Math.cos(a) * 500, vy: Math.sin(a) * 500,
            life: 0.15, maxLife: 0.15, color: '#ffffff', size: 3,
        });
    }

    // Ground crack effect - more dramatic
    for (let i = 0; i < 20; i++) {
        const a = Math.random() * Math.PI * 2;
        const r = range * Math.random() * 0.9;
        particles.push({
            x: origin.x + Math.cos(a) * r * 0.4,
            y: origin.y + Math.sin(a) * r * 0.4,
            vx: Math.cos(a) * 100,
            vy: Math.sin(a) * 100,
            life: 0.6 + Math.random() * 0.4,
            maxLife: 1.0,
            color: '#887744',
            size: 4 + Math.random() * 6,
        });
    }

    const targets = enemiesInRadius(origin.x, origin.y, range);
    for (const enemy of targets) {
        enemy.frozen = Math.max(enemy.frozen || 0, 0.4); // brief stun
        hitEnemy(enemy, dmg, true);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ddcc88', 12);
    }
    addMessage(targets.length > 0 ? `🔨 ${w.name} 360도 강타!` : '🔨 땅이 울렸다!',
        targets.length > 0 ? 'damage' : 'info');
}

function killEnemy(enemy) {
    playEnemyDeathSound(enemy.name);
    spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, enemy.color, 25);
    spawnFloatingText(enemy.x + enemy.w / 2, enemy.y - 10, '처치!', '#ffd700');

    // Stage progression
    player.kills++;
    player.killsByName[enemy.name] = (player.killsByName[enemy.name] || 0) + 1;
    addToCollection('enemies', enemy.name);
    const newStage = 1 + Math.floor(player.kills / 5);
    if (newStage > player.stage) {
        const oldStage = player.stage;
        player.stage = newStage;
        addMessage(`⚡ Stage ${player.stage} 돌입! 적들이 강해집니다!`, 'loot');
        spawnMoreEnemies();
        // Full heal on stage up
        player.hp = player.maxHp;
        addMessage('💚 단계 상승! 체력 완전 회복!', 'heal');
        // Spawn stage-gated NPCs
        spawnStageNPCs(oldStage, newStage);
    }

    // Drop weapon
    if (Math.random() < enemy.dropRate && enemy.dropPool.length > 0) {
        const weaponId = enemy.dropPool[Math.floor(Math.random() * enemy.dropPool.length)];
        const weapon = WEAPONS.find(w => w.id === weaponId);
        if (weapon && inventory.length < 12) {
            inventory.push({ ...weapon });
            addToCollection('weapons', weapon.id);
            addMessage(`🎁 ${weapon.icon} ${weapon.name} 획득!`, 'loot');
            spawnFloatingText(enemy.x + enemy.w / 2, enemy.y - 30, `${weapon.icon} ${weapon.name}`, '#ffd700');
        }
    }

    // Gold
    const goldDrop = enemy.gold || (enemy.megaBoss ? 500 : (enemy.isBoss ? 100 : 5 + Math.floor(Math.random() * 16)));
    player.gold += goldDrop;
    spawnFloatingText(enemy.x + enemy.w / 2, enemy.y - 20, `+${goldDrop}💰`, '#ffd700');

    if (enemy.isBoss) {
        // Mark boss quests as progress=1
        for (const aq of player.activeQuests) {
            const q = getQuest(aq.id);
            if (q && q.type === 'boss') aq.progress = 1;
            if (q && q.type === 'boss_specific' && q.bossName === enemy.name) aq.progress = 1;
        }
        // Track boss kill for portal unlock
        player.bossKilled = true;
        // Check portal spawn condition
        checkPortalSpawn();
    }

    // Remove enemy
    const idx = enemies.indexOf(enemy);
    if (idx >= 0) enemies.splice(idx, 1);

    // Update UI
    updateUI();
}

function updateEnemies(dt) {
    for (const enemy of enemies) {
        if (enemy.hp <= 0) continue;

        // Timers
        enemy.stateTimer -= dt;
        enemy.attackCooldown -= dt;
        if (enemy.hurtTimer > 0) enemy.hurtTimer -= dt;
        if (enemy.frozen > 0) {
            enemy.frozen -= dt;
            enemy.animTimer += dt;
            continue; // frozen enemies can't act
        }

        const px = player.x + player.w / 2;
        const py = player.y + player.h / 2;
        const ex = enemy.x + enemy.w / 2;
        const ey = enemy.y + enemy.h / 2;
        const dist = distance(ex, ey, px, py);

        // State transitions
        if (enemy.state === 'hurt' && enemy.stateTimer <= 0) {
            enemy.state = 'chase';
        }

        const aggroRange = enemy.megaBoss ? 500 : (enemy.isBoss ? 350 : 180);
        const attackRange = enemy.megaBoss ? 90 : (enemy.isBoss ? 50 : 38);
        const rangedRange = enemy.ranged ? 200 : 0;

        if (enemy.ranged && dist < rangedRange && dist > attackRange) {
            enemy.state = 'ranged';
        } else if (dist < attackRange) {
            enemy.state = 'attack';
        } else if (dist < aggroRange) {
            enemy.state = 'chase';
        } else if (enemy.state !== 'hurt' && enemy.state !== 'attack' && enemy.state !== 'ranged') {
            enemy.state = 'wander';
        }

        // Behavior
        let dx = 0, dy = 0;
        const spd = enemy.speed * dt;

        switch (enemy.state) {
            case 'wander':
                enemy.stateTimer -= dt;
                if (enemy.stateTimer <= 0 || distance(ex, ey, enemy.wanderTarget.x, enemy.wanderTarget.y) < 10) {
                    // Pick new wander target
                    const angle = Math.random() * Math.PI * 2;
                    const r = 50 + Math.random() * 120;
                    enemy.wanderTarget = {
                        x: ex + Math.cos(angle) * r,
                        y: ey + Math.sin(angle) * r,
                    };
                    enemy.stateTimer = 1.5 + Math.random() * 2;
                }
                dx = (enemy.wanderTarget.x - ex);
                dy = (enemy.wanderTarget.y - ey);
                break;

            case 'chase':
                dx = px - ex;
                dy = py - ey;
                break;

            case 'attack':
                dx = px - ex;
                dy = py - ey;
                if (enemy.attackCooldown <= 0) {
                    // Attack player
                    enemy.attackCooldown = enemy.isBoss ? 0.8 : 1.2;
                    if (player.invincible <= 0 && dist < attackRange + 15) {
                        let dmg = enemy.atk + Math.floor(Math.random() * 4);
                        if (player.shieldActive > 0) dmg = Math.floor(dmg * 0.5);
                        player.hp -= dmg;
                        playPlayerHurtSound();
                        player.invincible = 0.5;
                        spawnFloatingText(player.x + player.w / 2, player.y - 8, `-${dmg}${player.shieldActive > 0 ? '🛡️' : ''}`, '#ff4444');
                        spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ff0000', 6);
                        addMessage(`${enemy.icon} ${enemy.name}의 공격! -${dmg}`, 'damage');
                        updateUI();
                    }
                }
                break;

            case 'hurt':
                // Briefly recoil
                dx = ex - px;
                dy = ey - py;
                break;

            case 'ranged':
                // Keep distance, shoot projectiles
                enemy.rangeAttackCd -= dt;
                if (dist > rangedRange * 0.7) {
                    dx = px - ex; dy = py - ey; // Move closer if too far
                } else if (dist < rangedRange * 0.3) {
                    dx = ex - px; dy = ey - py; // Move away if too close
                } else {
                    dx = (Math.random() - 0.5); dy = (Math.random() - 0.5); // Strafe
                }
                if (enemy.rangeAttackCd <= 0) {
                    enemy.rangeAttackCd = enemy.rangeCooldown || 1.8;
                    const projSpd = enemy.projSpeed || 250;
                    const pdx = px - ex, pdy = py - ey;
                    const pmag = Math.sqrt(pdx * pdx + pdy * pdy) || 1;
                    spawnEnemyProjectile(
                        ex, ey,
                        (pdx / pmag) * projSpd,
                        (pdy / pmag) * projSpd,
                        enemy.atk,
                        enemy.color
                    );
                }
                break;
        }

        // Normalize
        const mag = Math.sqrt(dx * dx + dy * dy);
        if (mag > 0) {
            dx = dx / mag;
            dy = dy / mag;
        }

        // Direction
        if (enemy.state !== 'hurt') {
            if (Math.abs(dy) > Math.abs(dx)) {
                enemy.dir = dy > 0 ? 0 : 2;
            } else {
                enemy.dir = dx > 0 ? 3 : 1;
            }
        }

        // Movement (with knockback)
        if (enemy._knockbackX || enemy._knockbackY) {
            const kbx = enemy.x + enemy._knockbackX * dt * 4;
            const kby = enemy.y + enemy._knockbackY * dt * 4;
            if (!collidesWithMap(kbx, enemy.y, enemy.w, enemy.h) && !collidesWithEntities(kbx, enemy.y, enemy.w, enemy.h, enemy)) enemy.x = kbx;
            if (!collidesWithMap(enemy.x, kby, enemy.w, enemy.h) && !collidesWithEntities(enemy.x, kby, enemy.w, enemy.h, enemy)) enemy.y = kby;
            enemy._knockbackX *= 0.85;
            enemy._knockbackY *= 0.85;
            if (Math.abs(enemy._knockbackX) < 0.5) enemy._knockbackX = 0;
            if (Math.abs(enemy._knockbackY) < 0.5) enemy._knockbackY = 0;
        } else {
            const mx = enemy.x + dx * spd;
            const my = enemy.y + dy * spd;
            if (enemy.flying || enemy.megaBoss) {
                // Flying enemies ignore map collision
                if (!collidesWithEntities(mx, enemy.y, enemy.w, enemy.h, enemy)) enemy.x = mx;
                if (!collidesWithEntities(enemy.x, my, enemy.w, enemy.h, enemy)) enemy.y = my;
            } else {
                if (!collidesWithMap(mx, enemy.y, enemy.w, enemy.h) && !collidesWithEntities(mx, enemy.y, enemy.w, enemy.h, enemy)) enemy.x = mx;
                if (!collidesWithMap(enemy.x, my, enemy.w, enemy.h) && !collidesWithEntities(enemy.x, my, enemy.w, enemy.h, enemy)) enemy.y = my;
            }
        }

        // Clamp
        enemy.x = Math.max(0, Math.min(MAP_W * TILE_SIZE - enemy.w, enemy.x));
        enemy.y = Math.max(0, Math.min(MAP_H * TILE_SIZE - enemy.h, enemy.y));

        // Boss: terrain destruction
        if (enemy.destroyTerrain && enemy.hp > 0) {
            const ctx0 = Math.floor(enemy.x / TILE_SIZE);
            const cty = Math.floor(enemy.y / TILE_SIZE);
            for (let dy = -1; dy <= 1; dy++) {
                for (let dx = -1; dx <= 1; dx++) {
                    const tx = ctx0 + dx, ty = cty + dy;
                    if (tx >= 0 && ty >= 0 && tx < MAP_W && ty < MAP_H) {
                        const tk = TILE_KEYS[getTile(tx, ty)];
                        if (tk === 'TREE' || tk === 'BUSH' || tk === 'ROCK' || tk === 'WALL') {
                            tileMap[ty][tx] = TILE_KEYS.indexOf('DIRT');
                        }
                    }
                }
            }
        }

        // Boss: minion spawn
        if (enemy.spawnMinions && enemy.hp > 0) {
            enemy._spawnTimer -= dt;
            if (enemy._spawnTimer <= 0) {
                enemy._spawnTimer = enemy.spawnCooldown;
                for (let i = 0; i < enemy.spawnCount; i++) {
                    const sx = enemy.x + (Math.random() - 0.5) * enemy.w * 1.5;
                    const sy = enemy.y + (Math.random() - 0.5) * enemy.h * 1.5;
                    if (!isSolid(Math.floor(sx / TILE_SIZE), Math.floor(sy / TILE_SIZE))) {
                        spawnEnemy(ENEMY_TYPES[enemy.minionType], sx, sy);
                    }
                }
            }
        }

        // Animation
        enemy.animTimer += dt;
    }
}

function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.life -= dt;
        if (p.life <= 0) particles.splice(i, 1);
    }
}

function updateProjectiles(dt) {
    for (let i = projectiles.length - 1; i >= 0; i--) {
        const p = projectiles[i];
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.life -= dt;

        // Check collision with enemies
        let hitEnemyFlag = false;
        for (const enemy of enemies) {
            if (enemy.hp <= 0) continue;
            const dist = distance(p.x, p.y, enemy.x + enemy.w / 2, enemy.y + enemy.h / 2);
            if (dist < p.size + enemy.w / 2) {
                hitEnemy(enemy, p.dmg);
                spawnParticles(p.x, p.y, p.color, 8);
                projectiles.splice(i, 1);
                hitEnemyFlag = true;
                break;
            }
        }
        if (hitEnemyFlag) continue;

        // Check wall collision / expiry
        if (isSolid(Math.floor(p.x / TILE_SIZE), Math.floor(p.y / TILE_SIZE))) {
            spawnParticles(p.x, p.y, p.color, 6);
            projectiles.splice(i, 1);
            continue;
        }
        if (p.life <= 0) projectiles.splice(i, 1);
    }
}

function updateFireZones(dt) {
    for (let i = fireZones.length - 1; i >= 0; i--) {
        const fz = fireZones[i];
        fz.duration -= dt;
        fz.timer += dt;

        // Damage enemies inside every 0.4s
        if (fz.timer >= 0.4) {
            fz.timer -= 0.4;
            for (const enemy of enemiesInRadius(fz.x, fz.y, fz.radius)) {
                hitEnemy(enemy, fz.dmg);
                spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ff4400', 5);
            }
        }

        // Spawn fire particles
        if (Math.random() < 0.3) {
            const a = Math.random() * Math.PI * 2;
            const r = Math.random() * fz.radius;
            particles.push({
                x: fz.x + Math.cos(a) * r,
                y: fz.y + Math.sin(a) * r - 10,
                vx: (Math.random() - 0.5) * 20,
                vy: -40 - Math.random() * 60,
                life: 0.3 + Math.random() * 0.3,
                maxLife: 0.6,
                color: Math.random() > 0.5 ? '#ff6644' : '#ffaa00',
                size: 2 + Math.random() * 4,
            });
        }

        if (fz.duration <= 0) fireZones.splice(i, 1);
    }
}

function updateFloatingTexts(dt) {
    for (let i = floatingTexts.length - 1; i >= 0; i--) {
        const t = floatingTexts[i];
        t.y -= 40 * dt;
        t.life -= dt;
        if (t.life <= 0) floatingTexts.splice(i, 1);
    }
}

function updateEnemyProjectiles(dt) {
    for (let i = enemyProjectiles.length - 1; i >= 0; i--) {
        const p = enemyProjectiles[i];
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.life -= dt;
        // Hit player
        const dist = distance(p.x, p.y, player.x + player.w / 2, player.y + player.h / 2);
        if (dist < p.size + player.w / 2 && player.invincible <= 0) {
            let dmg = p.dmg;
            if (player.shieldActive > 0) dmg = Math.floor(dmg * 0.5);
            player.hp -= dmg;
            player.invincible = 0.3;
            spawnFloatingText(player.x + player.w / 2, player.y - 8, `-${dmg}`, '#ff4444');
            spawnParticles(p.x, p.y, p.color, 6);
            enemyProjectiles.splice(i, 1);
            updateUI();
            continue;
        }
        if (isSolid(Math.floor(p.x / TILE_SIZE), Math.floor(p.y / TILE_SIZE)) || p.life <= 0) {
            enemyProjectiles.splice(i, 1);
        }
    }
}

function updateGoldPickups(dt) {
    for (let i = goldPickups.length - 1; i >= 0; i--) {
        const g = goldPickups[i];
        g.life -= dt;
        if (g.life <= 0) { goldPickups.splice(i, 1); continue; }
        const dist = distance(player.x + player.w / 2, player.y + player.h / 2, g.x, g.y);
        if (dist < 30) {
            player.gold += g.amount;
            playCoinSound();
            spawnFloatingText(g.x, g.y - 10, `+${g.amount}💰`, '#ffd700');
            goldPickups.splice(i, 1);
            updateUI();
        }
    }
    // Respawn gold on walkable tiles only (not water)
    if (goldPickups.length < 8 && Math.random() < dt / 60) {
        const { x: gx, y: gy } = randomSpawnTile(3, (txi, tyi) => !isSolid(txi, tyi) && !isWater(txi, tyi));
        spawnGoldPickup(gx * TILE_SIZE + TILE_SIZE / 2, gy * TILE_SIZE + TILE_SIZE / 2, 20);
    }
}

function updateWeaponPickups(dt) {
    for (let i = weaponPickups.length - 1; i >= 0; i--) {
        const wp = weaponPickups[i];
        wp.life -= dt;
        if (wp.life <= 0) { weaponPickups.splice(i, 1); continue; }
        const dist = distance(player.x + player.w / 2, player.y + player.h / 2, wp.x, wp.y);
        if (dist < 28) {
            if (inventory.length < 12) {
                inventory.push({ ...wp.weapon });
                addToCollection('weapons', wp.weapon.id);
                addMessage(`🎁 ${wp.weapon.icon} ${wp.weapon.name} 획득!`, 'loot');
                playCoinSound();
            } else {
                addMessage('🎒 인벤토리가 가득 찼습니다!', 'damage');
            }
            weaponPickups.splice(i, 1);
            updateUI();
        }
    }
}

function updateChests(dt) {
    for (let i = chests.length - 1; i >= 0; i--) {
        const c = chests[i];
        if (c.opened) continue;
        // Player attack hits chest
        if (player.attackTimer > player.weapon.cooldown - 0.15) {
            const origin = getAttackOrigin();
            const dist = distance(origin.x, origin.y, c.x + c.w / 2, c.y + c.h / 2);
            if (dist < 40) {
                c.hp--;
                spawnParticles(c.x + c.w / 2, c.y + c.h / 2, '#aa8844', 5);
                if (c.hp <= 0) {
                    c.opened = true;
                    playChestBreak(c.chestData && c.chestData.id === 'iron');
                    openChest(c);
                    chests.splice(i, 1);
                }
            }
        }
    }
}

function openChest(c) {
    const cx = c.x + c.w / 2, cy = c.y + c.h / 2;
    if (c.type === 'trap') {
        const dmg = c.chestData.id === 'iron' ? 35 : 15;
        player.hp -= dmg;
        spawnParticles(cx, cy, '#ff4400', 25);
        addMessage(`💥 함정 상자! ${dmg} 피해!`, 'damage');
        updateUI();
    } else if (c.type === 'mimic') {
        addMessage('👹 상자가 미믹이었다!', 'damage');
        const enemyType = c.chestData.id === 'iron' ? ENEMY_TYPES[9] : ENEMY_TYPES[3];
        spawnEnemy(enemyType, c.x, c.y);
    } else {
        const cd = c.chestData || CHEST_TYPES[0];
        const count = cd.dropCount || 1;
        // Direction away from player
        const pdx = cx - (player.x + player.w / 2);
        const pdy = cy - (player.y + player.h / 2);
        const pdist = Math.sqrt(pdx * pdx + pdy * pdy) || 1;
        const awayX = pdx / pdist;
        const awayY = pdy / pdist;

        for (let i = 0; i < count; i++) {
            const r = Math.random();
            // Scatter position: away from player + random spread
            const spreadAngle = (Math.random() - 0.5) * Math.PI * 0.6; // ±54 degrees
            const cos = Math.cos(spreadAngle), sin = Math.sin(spreadAngle);
            const sx = awayX * cos - awayY * sin;
            const sy = awayX * sin + awayY * cos;
            const scatterDist = 30 + Math.random() * 50;
            let dropX = cx + sx * scatterDist;
            let dropY = cy + sy * scatterDist;
            // Ensure drop lands on walkable terrain (not solid, not water)
            const dtx = Math.floor(dropX / TILE_SIZE), dty = Math.floor(dropY / TILE_SIZE);
            if (isSolid(dtx, dty) || isWater(dtx, dty)) {
                dropX = cx; dropY = cy;
            }

            if (r < 0.35) {
                const [minG, maxG] = cd.dropGold;
                const amt = minG + Math.floor(Math.random() * (maxG - minG));
                spawnGoldPickup(dropX, dropY, amt);
                if (i === 0) addMessage(`📦 ${cd.name}에서 💰 ${amt}골드 획득!`, 'loot');
            } else if (r < 0.7) {
                const pool = cd.dropWeapons;
                const wid = pool[Math.floor(Math.random() * Math.min(pool.length, 1 + player.stage))];
                const weapon = WEAPONS.find(w => w.id === wid);
                if (weapon) {
                    // Spawn as weapon pickup on ground
                    weaponPickups.push({
                        x: dropX, y: dropY,
                        weapon: { ...weapon },
                        life: 120, bob: Math.random() * Math.PI * 2,
                    });
                    if (i === 0) addMessage(`📦 ${cd.name}에서 ${weapon.icon} ${weapon.name} 등장!`, 'loot');
                }
            } else {
                const healAmt = cd.id === 'iron' ? 60 : 25;
                player.hp = Math.min(player.maxHp, player.hp + healAmt);
                if (i === 0) addMessage(`📦 ${cd.name}에서 💚 체력 회복!`, 'heal');
            }
            updateUI();
        }
    }
}

// ============================================================
//  RENDERING
// ============================================================
function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw terrain
    drawTerrain();

    // Draw fountain
    drawFountain();

    // Draw portals
    drawPortals();

    // Draw fire zones (under entities)
    drawFireZones();

    // Draw particles (under entities)
    drawParticles();

    // Draw projectiles
    drawProjectiles();

    // Draw enemy projectiles
    drawEnemyProjectiles();

    // Draw gold pickups
    drawGoldPickups();

    // Draw weapon pickups
    drawWeaponPickups();

    // Draw chests
    drawChests();

    // Draw mounts
    drawMounts();

    // Draw NPCs
    drawNPCs();

    // Draw scarecrows
    drawScarecrows();

    // Draw enemies
    for (const enemy of enemies) {
        if (enemy.hp <= 0) continue;
        drawEntity(enemy);
    }

    // Draw player
    drawEntity(player);

    // Draw floating texts
    drawFloatingTexts();

    // Draw minimap
    drawMinimap();

    // Vision fog when reduced
    if (player.visionReduction > 0) {
        drawVisionFog();
    }
}


// ============================================================
//  INVENTORY UI
// ============================================================
const invPanel = document.getElementById('inventory');
const invSlots = document.getElementById('inventorySlots');
let invOpen = false;
let invSelected = 0;

function toggleInventory() {
    invOpen = !invOpen;
    if (invOpen) {
        invPanel.classList.remove('hidden');
        invSelected = 0;
        refreshInventoryUI();
    } else {
        invPanel.classList.add('hidden');
    }
}

function navigateInventory(code) {
    const cols = 4;
    let row = Math.floor(invSelected / cols);
    let col = invSelected % cols;
    if (code === 'ArrowUp') row = Math.max(0, row - 1);
    if (code === 'ArrowDown') row = Math.min(2, row + 1);
    if (code === 'ArrowLeft') col = Math.max(0, col - 1);
    if (code === 'ArrowRight') col = Math.min(cols - 1, col + 1);
    invSelected = row * cols + col;
    refreshInventoryUI();
}

function selectInventoryItem() {
    if (invSelected < inventory.length) {
        equipWeapon(invSelected);
    }
}

function refreshInventoryUI() {
    invSlots.innerHTML = '';
    for (let i = 0; i < 12; i++) {
        const slot = document.createElement('div');
        slot.className = 'inventory-slot';
        if (i === invSelected) slot.classList.add('selected');
        if (i < inventory.length) {
            const item = inventory[i];
            slot.innerHTML = `<span class="icon">${item.icon}</span><span class="name">${item.name}</span><span class="atk">ATK ${item.atk}</span><span class="ability">${item.desc || ''}</span>`;
            slot.style.borderColor = item.color;
            slot.addEventListener('click', () => { invSelected = i; equipWeapon(i); });
        } else {
            slot.classList.add('empty');
            slot.innerHTML = '<span class="icon">—</span><span class="name">빈 슬롯</span>';
        }
        invSlots.appendChild(slot);
    }
}

function equipWeapon(index) {
    if (index >= inventory.length) return;
    const item = inventory[index];
    // Unequip current weapon (if not fist)
    if (player.weapon.id !== 'fist') {
        inventory.push({ ...player.weapon });
    }
    // Equip
    player.weapon = item;
    player.atk = item.atk;
    player.comboHits = 0;
    player._comboTimer = 0;
    inventory.splice(index, 1);
    refreshInventoryUI();
    updateUI();
    addMessage(`⚔️ ${item.name} 장착! (${item.desc || ''})`, 'loot');
}

// ============================================================
//  AUXILIARY WEAPON
// ============================================================
function dismountPlayer() {
    if (!player.mount || gameOver || gameVictory) return;
    const m = player.mount;
    // Find a walkable tile near the mount
    let ox = player.x, oy = player.y;
    const searchOffsets = [
        [0, TILE_SIZE], [TILE_SIZE, 0], [-TILE_SIZE, 0], [0, -TILE_SIZE],
        [TILE_SIZE, TILE_SIZE], [-TILE_SIZE, TILE_SIZE], [TILE_SIZE, -TILE_SIZE], [-TILE_SIZE, -TILE_SIZE],
        [0, TILE_SIZE*2], [TILE_SIZE*2, 0], [-TILE_SIZE*2, 0], [0, -TILE_SIZE*2],
    ];
    let found = false;
    for (const [dx, dy] of searchOffsets) {
        const tx = player.x + dx, ty = player.y + dy;
        const ttx = Math.floor(tx / TILE_SIZE), tty = Math.floor(ty / TILE_SIZE);
        if (ttx >= 0 && ttx < MAP_W && tty >= 0 && tty < MAP_H && !isSolid(ttx, tty)) {
            // Land mounts: dismount only on land (not water)
            // Boat: dismount only on water (player was on water)
            if (m.waterOnly && !isWater(ttx, tty)) continue;
            if (!m.waterOnly && isWater(ttx, tty)) continue;
            ox = tx; oy = ty; found = true; break;
        }
    }
    if (!found) {
        // Last resort: teleport to fountain (FOUNTAIN_CX/CY are already in pixels)
        ox = FOUNTAIN_CX;
        oy = FOUNTAIN_CY;
        addMessage('⚠️ 내릴 곳이 없어 분수로 이동합니다.', 'info');
    }
    player.x = ox;
    player.y = oy;
    mounts.push({ ...m, x: player.x + TILE_SIZE, y: player.y - TILE_SIZE });
    player.mount = null;
    addMessage(`내렸습니다. ${m.icon} ${m.name}`, 'info');
    updateUI();
}

function useItem(index) {
    if (index >= player.items.length || gameOver || gameVictory || shopOpen) return;
    const item = player.items[index];
    if (!item) return;

    switch (item.use) {
        case 'heal':
            player.hp = Math.min(player.maxHp, player.hp + item.healAmount);
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#66ff66', 20);
            addMessage(`🧪 ${item.name} 사용! +${item.healAmount} HP`, 'heal');
            break;
        case 'bomb':
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ff4400', 35);
            spawnFireZone(player.x + player.w / 2, player.y + player.h / 2, 0.5, item.bombDmg, item.bombRange);
            for (const enemy of enemiesInRadius(player.x + player.w / 2, player.y + player.h / 2, item.bombRange)) {
                hitEnemy(enemy, item.bombDmg);
                spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ff4400', 15);
            }
            addMessage(`💣 ${item.name} 폭발!`, 'damage');
            break;
        case 'antidote':
            player.poisonTimer = 0;
            player.poisonTick = 0;
            player.visionReduction = 0;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#aaddff', 20);
            addMessage(`🧴 ${item.name} 사용! 모든 이상상태 해제`, 'heal');
            break;
        case 'speed':
            player.speedBoost = 10;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ffff44', 25);
            addMessage(`⚡ ${item.name} 사용! 10초간 이동속도 1.5배!`, 'loot');
            break;
        case 'return':
            player.x = FOUNTAIN_CX;
            player.y = FOUNTAIN_CY;
            player.mount = null;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#aaccff', 30);
            updateCamera(player.x + player.w / 2, player.y + player.h / 2);
            addMessage(`💠 ${item.name} 사용! 분수로 귀환!`, 'loot');
            break;
    }
    player.items.splice(index, 1);
    updateUI();
}

function cycleAuxWeapon() {
    if (player.auxWeapons.length <= 1) return;
    const curIdx = player.auxWeapons.indexOf(player.auxWeapon);
    const nextIdx = (curIdx + 1) % player.auxWeapons.length;
    player.auxWeapon = player.auxWeapons[nextIdx];
    addMessage(`🔄 ${player.auxWeapon.icon} ${player.auxWeapon.name} 장착`, 'info');
    updateUI();
}

function useAuxWeapon() {
    if (!player.auxWeapon || player.auxCooldown > 0 || gameOver || gameVictory) return;

    const aux = player.auxWeapon;

    // Check uses for limited weapons
    if (aux.uses > 0) {
        aux.uses--;
    }
    if (aux.cooldown) {
        player.auxCooldown = aux.cooldown;
    }

    const origin = getAttackOrigin();

    switch (aux.ability) {
        case 'aoe_fire':
            auxAoeFire(aux, origin);
            break;
        case 'freeze':
            auxFreeze(aux, origin);
            break;
        case 'lightning':
            auxLightning(aux, origin);
            break;
        case 'poison_zone':
            auxPoisonZone(aux, origin);
            break;
        case 'heal':
            auxHeal(aux);
            break;
        case 'taunt':
            auxTaunt(aux);
            break;
        case 'boomerang':
            auxBoomerang(aux, origin);
            break;
        case 'shuriken':
            auxShuriken(aux, origin);
            break;
        case 'shield':
            auxShield(aux);
            break;
        case 'trap':
            auxTrap(aux, origin);
            break;
    }

    updateUI();

    // Remove if out of uses
    if (aux.uses === 0) {
        addMessage(`${aux.icon} ${aux.name} 모두 사용!`, 'info');
        const idx = player.auxWeapons.indexOf(aux);
        if (idx >= 0) player.auxWeapons.splice(idx, 1);
        player.auxWeapon = player.auxWeapons.length > 0 ? player.auxWeapons[0] : null;
        updateUI();
    }
}

function auxAoeFire(aux, origin) {
    const r = aux.range || 80;
    for (let i = 0; i < 30; i++) {
        const a = Math.random() * Math.PI * 2;
        const dist = Math.random() * r;
        particles.push({
            x: origin.x + Math.cos(a) * dist,
            y: origin.y + Math.sin(a) * dist,
            vx: Math.cos(a) * 300, vy: Math.sin(a) * 300 - 20,
            life: 0.3 + Math.random() * 0.4, maxLife: 0.7,
            color: Math.random() > 0.5 ? '#ff4400' : '#ffaa00', size: 3 + Math.random() * 5,
        });
    }
    spawnFireZone(origin.x, origin.y, 1.5, 10, r * 0.7);
    for (const enemy of enemiesInRadius(origin.x, origin.y, r)) {
        hitEnemy(enemy, aux.dmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ff4400', 10);
    }
    addMessage(`🧨 ${aux.name} 폭발!`, 'damage');
}

function auxFreeze(aux, origin) {
    const r = aux.range || 70;
    for (let i = 0; i < 20; i++) {
        const a = Math.random() * Math.PI * 2;
        const dist = Math.random() * r;
        particles.push({
            x: origin.x + Math.cos(a) * dist,
            y: origin.y + Math.sin(a) * dist,
            vx: (Math.random() - 0.5) * 60, vy: (Math.random() - 0.5) * 60,
            life: 0.5, maxLife: 0.5, color: '#aaddff', size: 3 + Math.random() * 4,
        });
    }
    for (const enemy of enemiesInRadius(origin.x, origin.y, r)) {
        enemy.frozen = aux.freezeTime;
        hitEnemy(enemy, aux.dmg);
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#88ccff', 8);
    }
    addMessage(`❄️ 주변 적 얼림!`, 'info');
}

function auxLightning(aux, origin) {
    let hit = false;
    // Straight line in facing direction
    const r = aux.range || 90;
    for (let i = 0; i < 12; i++) {
        let lx = origin.x, ly = origin.y;
        switch (player.dir) {
            case 0: ly += (i / 12) * r; break;
            case 1: lx -= (i / 12) * r; break;
            case 2: ly -= (i / 12) * r; break;
            case 3: lx += (i / 12) * r; break;
        }
        particles.push({
            x: lx + (Math.random() - 0.5) * 16,
            y: ly + (Math.random() - 0.5) * 16,
            vx: (Math.random() - 0.5) * 60, vy: (Math.random() - 0.5) * 60,
            life: 0.2, maxLife: 0.2, color: '#ffff44', size: 2 + Math.random() * 3,
        });
    }
    const vertical = player.dir === 0 || player.dir === 2;
    for (const enemy of enemiesInRadius(origin.x, origin.y, r + 30)) {
        // Hit if the enemy is along the lightning line (in front, within width)
        const ex = enemy.x + enemy.w / 2, ey = enemy.y + enemy.h / 2;
        const dx = ex - origin.x, dy = ey - origin.y;
        let along = 0;
        switch (player.dir) {
            case 0: along = dy; break;
            case 1: along = -dx; break;
            case 2: along = -dy; break;
            case 3: along = dx; break;
        }
        const perp = Math.abs(vertical ? dx : dy);
        if (along > 0 && along < r && perp < 30) {
            hitEnemy(enemy, aux.dmg, true);
            spawnParticles(ex, ey, '#ffff44', 15);
            hit = true;
        }
    }
    if (hit) addMessage(`⚡ ${aux.name} 강타!`, 'damage');
}

function auxPoisonZone(aux, origin) {
    spawnFireZone(origin.x, origin.y, aux.duration, aux.dmg, aux.range);
    for (let i = 0; i < 15; i++) {
        const a = Math.random() * Math.PI * 2;
        particles.push({
            x: origin.x + Math.cos(a) * aux.range * 0.5,
            y: origin.y + Math.sin(a) * aux.range * 0.5,
            vx: (Math.random() - 0.5) * 40, vy: (Math.random() - 0.5) * 40 - 10,
            life: 0.8, maxLife: 0.8, color: '#88ff44', size: 2 + Math.random() * 3,
        });
    }
    addMessage(`☠️ 독 안개 살포!`, 'damage');
}

function auxHeal(aux) {
    const healAmt = aux.healAmount;
    player.hp = Math.min(player.maxHp, player.hp + healAmt);
    for (let i = 0; i < 12; i++) {
        particles.push({
            x: player.x + player.w / 2 + (Math.random() - 0.5) * 20,
            y: player.y - 5,
            vx: (Math.random() - 0.5) * 30,
            vy: -30 - Math.random() * 50,
            life: 0.5 + Math.random() * 0.3, maxLife: 0.8,
            color: '#66ff66', size: 3 + Math.random() * 4,
        });
    }
    addMessage(`🧪 +${healAmt} HP 회복!`, 'heal');
}

function auxTaunt(aux) {
    for (const enemy of enemies) {
        if (enemy.hp <= 0) continue;
        enemy.frozen = aux.stunTime;
        enemy.state = 'chase';
        spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ffff00', 8);
    }
    addMessage(`🥁 모든 적 도발 + 스턴!`, 'info');
}

function auxBoomerang(aux, origin) {
    const throwDir = player.dir;
    spawnProjectile(origin.x, origin.y, throwDir, 320, aux.dmg, '#aaccff', '🪃');
    // Boomerang returns after a delay
    setTimeout(() => {
        if (!gameStarted || gameOver || gameVictory) return;
        const rOrigin = getAttackOrigin();
        const revDir = (throwDir + 2) % 4;
        spawnProjectile(rOrigin.x, rOrigin.y, revDir, 280, aux.dmg, '#aaccff', '🪃');
    }, 350);
    addMessage('🪃 부메랑 투척!', 'info');
}

function auxShuriken(aux, origin) {
    for (let i = -1; i <= 1; i++) {
        // 3-way spread around the facing angle
        const fAngle = facingAngle(player.dir) + i * 0.25;
        const spd = 300;
        projectiles.push({
            x: origin.x, y: origin.y,
            vx: Math.cos(fAngle) * spd,
            vy: Math.sin(fAngle) * spd,
            dmg: aux.dmg, color: '#ffcc88', icon: '🔸', life: 0.7, size: 5,
        });
    }
    addMessage('🔸 수리검 발사!', 'info');
}

function auxShield(aux) {
    player.shieldActive = aux.duration;
    for (let i = 0; i < 10; i++) {
        const a = Math.PI * 2 * i / 10;
        particles.push({
            x: player.x + player.w / 2 + Math.cos(a) * 20,
            y: player.y + player.h / 2 + Math.sin(a) * 20,
            vx: Math.cos(a) * 50, vy: Math.sin(a) * 50,
            life: 0.6, maxLife: 0.6, color: '#aaaaff', size: 3,
        });
    }
    addMessage(`🛡️ ${aux.duration}초간 방패 활성화!`, 'info');
}

function auxTrap(aux, origin) {
    // Spawn trap as a long-lived damage zone in front of the player
    const fz = offsetByDir(player.x + player.w / 2, player.y + player.h / 2, player.dir, 30);
    spawnFireZone(fz.x, fz.y, 8, aux.dmg, 28);
    spawnParticles(fz.x, fz.y, '#aa8844', 8);
    addMessage('🪤 덫 설치!', 'info');
}

function updateUI() {
    const wpn = player.weapon;
    const usesText = wpn.uses !== undefined ? ` [${wpn.uses}회]` : '';
    document.getElementById('equipmentSlot').innerHTML =
        `${wpn.icon} ${wpn.name} <span style="color:#ff8888;font-size:10px;">ATK ${wpn.atk}${usesText}</span>`;
    document.getElementById('hpText').textContent = `${Math.max(0, Math.round(player.hp))} / ${player.maxHp}`;

    const hpRatio = Math.max(0, player.hp / player.maxHp);
    const hpBar = document.getElementById('hpBarFill');
    hpBar.style.width = `${hpRatio * 100}%`;
    hpBar.classList.remove('low', 'mid');
    if (hpRatio < 0.3) hpBar.classList.add('low');
    else if (hpRatio < 0.6) hpBar.classList.add('mid');

    // Portrait face based on HP
    const portrait = document.getElementById('charPortrait');
    const face = document.getElementById('portraitFace');
    const hudTop = document.getElementById('hudTop');
    portrait.classList.remove('danger', 'warning');
    hudTop.classList.remove('danger');
    if (hpRatio < 0.2) {
        face.textContent = '🤕';
        portrait.classList.add('danger');
        hudTop.classList.add('danger');
    } else if (hpRatio < 0.4) {
        face.textContent = '😰';
        portrait.classList.add('warning');
    } else if (hpRatio < 0.7) {
        face.textContent = player.playerFace;
    } else {
        face.textContent = player.playerFace;
    }

    document.getElementById("goldDisplay").textContent = `💰 ${player.gold}`;
    const mins = Math.floor(player.gameTime / 60);
    const secs = Math.floor(player.gameTime % 60);
    const timeEl = document.getElementById('timeDisplay');
    const timeColor = player.gameTime < 60 ? '#ff4444' : (player.gameTime < 180 ? '#ffaa44' : '#ff8866');
    timeEl.textContent = `⏱ ${mins}:${secs.toString().padStart(2, '0')}`;
    timeEl.style.color = timeColor;
    // Poison indicator
    const poisonEl = document.getElementById('poisonDisplay');
    if (player.speedBoost > 0) {
        poisonEl.style.display = 'block';
        poisonEl.style.color = '#ffff44';
        poisonEl.textContent = `⚡ 스피드 ${player.speedBoost.toFixed(1)}s`;
    } else if (player.poisonTimer > 0) {
        poisonEl.style.display = 'block';
        poisonEl.style.color = '#88ff44';
        const pMins = Math.floor(player.poisonTimer / 60);
        const pSecs = Math.floor(player.poisonTimer % 60);
        poisonEl.textContent = `☠️ 독 ${pMins}:${pSecs.toString().padStart(2, '0')}`;
    } else {
        poisonEl.style.display = 'none';
    }
    document.getElementById('stageInfo').textContent = `Stage ${player.stage}`;

    // Aux weapon display
    const aux = player.auxWeapon;
    const auxDisplay = document.getElementById('auxDisplay');
    if (aux) {
        const usesText = aux.uses > 0 ? ` [${aux.uses}]` : (aux.uses === -1 ? ' [∞]' : '');
        const cdText = player.auxCooldown > 0 ? ` (${player.auxCooldown.toFixed(1)}s)` : '';
        auxDisplay.innerHTML = `${aux.icon} ${aux.name}${usesText}${cdText}`;
        auxDisplay.style.color = aux.uses > 0 ? '#ff6644' : '#66bb6a';
    } else {
        auxDisplay.textContent = '없음';
        auxDisplay.style.color = '#888';
    }

    // Show quest progress
    const mainProgress = MAIN_QUESTS.filter(mq => player.completedQuests.includes(mq)).length;
    const mainTotal = MAIN_QUESTS.length;
    document.getElementById('clearProgress').textContent =
        `📜 주요 퀘스트: ${mainProgress} / ${mainTotal}`;

    // Mount display
    const mount = player.mount;
    const mountSlot = document.getElementById('equipMount');
    const mountDisplay = document.getElementById('mountDisplay');
    if (mount) {
        mountDisplay.textContent = `${mount.icon} ${mount.name}`;
        mountSlot.style.display = 'flex';
    } else {
        mountSlot.style.display = 'none';
    }

    // Item slots
    for (let i = 0; i < 3; i++) {
        const el = document.getElementById('item' + (i + 1));
        if (el) {
            el.textContent = player.items[i] ? player.items[i].icon : '—';
        }
    }
}

// ============================================================
//  GAME LOOP
// ============================================================
// Win/lose is handled by quest completion and player death
function triggerVictory(msg) {
    showResultScreen('victory', msg);
}

function showGameOverScreen(reason) {
    showResultScreen('gameOver', reason);
}

function showResultScreen(type, reason) {
    if (gameOver || gameVictory) return;
    stopBgMusic();
    const isWin = type === 'victory';
    if (isWin) gameVictory = true;
    else gameOver = true;

    // Grade calculation
    const score = player.kills * 10 + player.gold + Math.floor(player.damageDealt / 5);
    let grade, gradeColor;
    if (score >= 500) { grade = 'S'; gradeColor = '#ffd700'; }
    else if (score >= 300) { grade = 'A'; gradeColor = '#ff6644'; }
    else if (score >= 150) { grade = 'B'; gradeColor = '#44aaff'; }
    else if (score >= 60) { grade = 'C'; gradeColor = '#88cc88'; }
    else { grade = 'D'; gradeColor = '#888888'; }

    // Stats HTML
    const wpnIcon = player.weapon ? player.weapon.icon : '✊';
    const wpnName = player.weapon ? player.weapon.name : '맨손';
    const auxIcon = player.auxWeapon ? player.auxWeapon.icon : '—';
    const auxName = player.auxWeapon ? player.auxWeapon.name : '없음';
    const remainSec = Math.max(0, Math.ceil(player.gameTime));
    const timeStr = `${Math.floor(remainSec / 60)}분 ${remainSec % 60}초 남음`;

    const statsHTML = `
        <div class="stat-row"><span class="label">⚔️ 주무기</span><span class="value">${wpnIcon} ${wpnName}</span></div>
        <div class="stat-row"><span class="label">🎒 보조무기</span><span class="value">${auxIcon} ${auxName}</span></div>
        <div class="stat-row"><span class="label">☠️ 처치한 적</span><span class="value good">${player.kills} 마리</span></div>
        <div class="stat-row"><span class="label">💥 누적 피해량</span><span class="value" style="color:#ffaa44;">${player.damageDealt}</span></div>
        <div class="stat-row"><span class="label">💰 획득 골드</span><span class="value gold">${player.gold}</span></div>
        <div class="stat-row"><span class="label">⚡ 도달 Stage</span><span class="value" style="color:#ffaa44;">Stage ${player.stage}</span></div>
        <div class="stat-row"><span class="label">⏱️ 남은 시간</span><span class="value">${timeStr}</span></div>
        <div class="stat-row"><span class="label">🎯 목표</span><span class="value ${isWin ? 'good' : 'bad'}">${reason}</span></div>
    `;

    if (type === 'victory') {
        document.getElementById('victoryMsg').textContent = reason;
        document.getElementById('victoryStats').innerHTML = statsHTML;
        document.getElementById('victoryGrade').innerHTML = `<span style="color:${gradeColor}">${grade}</span>`;
        document.getElementById('victory').classList.remove('hidden');
    } else {
        document.getElementById('gameOverStats').innerHTML = statsHTML;
        document.getElementById('gameOverGrade').innerHTML = `<span style="color:${gradeColor}">${grade}</span>`;
        document.getElementById('gameOver').classList.remove('hidden');
    }
}

// ============================================================
//  NPC INTERACTION & QUESTS
// ============================================================
function interactNPC() {
    // Check portal first
    if (portals.length > 0 && interactPortal()) return;

    let closest = null, closestDist = 50;
    for (const npc of npcs) {
        const dist = distance(player.x + player.w/2, player.y + player.h/2, npc.x + npc.w/2, npc.y + npc.h/2);
        if (dist < closestDist) { closest = npc; closestDist = dist; }
    }
    if (!closest) return;

    // Shop NPC
    if (closest.isShop) {
        openShop(closest.shopType || 'village');
        return;
    }

    // Slot machine
    if (closest.isSlotMachine) {
        useSlotMachine();
        return;
    }

    // Stylist NPC (appearance change)
    if (closest.isStylist) {
        openAppearancePanel();
        return;
    }

    // Desert traveler NPC
    if (closest.isDesertTraveler) {
        gamePaused = true;
        document.getElementById('npcDialog').classList.remove('hidden');
        document.getElementById('npcPortrait').textContent = closest.icon;
        document.getElementById('npcName').textContent = closest.name;
        document.getElementById('npcText').textContent = closest.dialog;
        const opts = document.getElementById('npcOptions');
        opts.innerHTML = '';
        const travelBtn = document.createElement('div');
        travelBtn.className = 'dialog-option';
        travelBtn.innerHTML = `<span class="q-name">🏜️ 사막으로 이동</span><br><span class="q-desc">오아시스가 있는 사막 지역으로 떠납니다</span><br><span class="q-reward">⚠️ 돌아올 수 없습니다</span>`;
        travelBtn.addEventListener('click', () => {
            closeDialog();
            travelToDesert();
        });
        opts.appendChild(travelBtn);
        return;
    }

    gamePaused = true;
    document.getElementById('npcDialog').classList.remove('hidden');
    document.getElementById('npcPortrait').textContent = closest.icon;
    document.getElementById('npcName').textContent = closest.name;
    document.getElementById('npcText').textContent = closest.dialog;
    const opts = document.getElementById('npcOptions');
    opts.innerHTML = '';
    const availQuests = QUESTS.filter(q => closest.quests.includes(q.id) && isQuestAvailable(q, player));
    availQuests.forEach(q => {
        const btn = document.createElement('div');
        btn.className = 'dialog-option';
        const badge = q.main ? '⭐ ' : '';
        btn.innerHTML = `<span class="q-name">${badge}📜 ${q.name}</span><br><span class="q-desc">${q.desc}</span><br><span class="q-reward">보상: ${q.rewardText}</span>`;
        btn.addEventListener('click', () => acceptQuest(q));
        opts.appendChild(btn);
    });
    if (availQuests.length === 0) {
        opts.innerHTML = '<p style="color:#888;">현재 받을 수 있는 퀘스트가 없습니다.</p>';
    }
}

function acceptQuest(quest) {
    if (player.activeQuests.length >= 3) {
        addMessage('📜 최대 3개의 퀘스트만 받을 수 있습니다!', 'damage');
        closeDialog();
        return;
    }
    player.activeQuests.push({ id: quest.id, progress: 0 });
    addMessage(`📜 퀘스트 수락: ${quest.name}`, 'loot');
    closeDialog();
    updateQuestJournal();
}

function closeDialog() {
    gamePaused = false;
    document.getElementById('npcDialog').classList.add('hidden');
}

// ============================================================
//  APPEARANCE PANEL (외관 변경)
// ============================================================
function openAppearancePanel() {
    gamePaused = true;
    const panel = document.getElementById('appearancePanel');
    panel.classList.remove('hidden');

    // Highlight current face
    const options = panel.querySelectorAll('.appearance-option');
    options.forEach(opt => {
        opt.classList.toggle('selected', opt.dataset.face === player.playerFace);
    });

    // Set up click handlers
    options.forEach(opt => {
        opt.onclick = () => {
            player.playerFace = opt.dataset.face;
            options.forEach(o => o.classList.toggle('selected', o.dataset.face === player.playerFace));
            updateUI();
            addMessage(`🎭 외관이 변경되었습니다!`, 'loot');
        };
    });

    // Close via overlay click
    panel.onclick = (e) => {
        if (e.target === panel) closeAppearancePanel();
    };
}

function closeAppearancePanel() {
    gamePaused = false;
    document.getElementById('appearancePanel').classList.add('hidden');
}

// ============================================================
//  COMPENDIUM (도감)
// ============================================================
let compendiumOpen = false;

function addToCollection(type, id) {
    const col = player.collection[type];
    if (!col.includes(id)) {
        col.push(id);
    }
}

function toggleCompendium() {
    if (gameOver || gameVictory || shopOpen) return;
    compendiumOpen = !compendiumOpen;
    const panel = document.getElementById('compendiumPanel');
    if (compendiumOpen) {
        gamePaused = true;
        panel.classList.remove('hidden');
        renderCompendium();
    } else {
        gamePaused = false;
        panel.classList.add('hidden');
    }
}

function renderCompendium() {
    const grid = document.getElementById('compendiumGrid');
    grid.innerHTML = '';

    // Weapons section
    const weaponHeader = document.createElement('div');
    weaponHeader.className = 'compendium-section-header';
    weaponHeader.textContent = '⚔️ 무기';
    grid.appendChild(weaponHeader);

    WEAPONS.forEach(w => {
        const owned = player.collection.weapons.includes(w.id);
        const card = document.createElement('div');
        card.className = 'compendium-card' + (owned ? '' : ' locked');
        card.innerHTML = `<span class="cc-icon">${owned ? w.icon : '❓'}</span><span class="cc-name">${owned ? w.name : '???'}</span>`;
        if (owned) {
            card.title = `${w.icon} ${w.name}\nATK: ${w.atk}\n${w.desc || ''}\n능력: ${w.ability || '기본'}\n희귀도: ${w.rarity || '일반'}`;
        } else {
            card.title = '아직 발견하지 못한 무기';
        }
        grid.appendChild(card);
    });

    // Items section
    const itemHeader = document.createElement('div');
    itemHeader.className = 'compendium-section-header';
    itemHeader.textContent = '🧪 아이템';
    grid.appendChild(itemHeader);

    ITEMS.forEach(it => {
        const owned = player.collection.items.includes(it.id);
        const card = document.createElement('div');
        card.className = 'compendium-card' + (owned ? '' : ' locked');
        card.innerHTML = `<span class="cc-icon">${owned ? it.icon : '❓'}</span><span class="cc-name">${owned ? it.name : '???'}</span>`;
        if (owned) {
            card.title = `${it.icon} ${it.name}\n${it.desc}\n가격: ${it.price}💰`;
        } else {
            card.title = '아직 발견하지 못한 아이템';
        }
        grid.appendChild(card);
    });

    // Enemies section
    const enemyHeader = document.createElement('div');
    enemyHeader.className = 'compendium-section-header';
    enemyHeader.textContent = '👾 적';
    grid.appendChild(enemyHeader);

    const allEnemyTypes = [
        ...ENEMY_TYPES.filter(e => !e.isBoss),
        ...DESERT_ENEMY_TYPES.filter(e => !e.isBoss),
        ...ENEMY_TYPES.filter(e => e.isBoss),
        ...DESERT_ENEMY_TYPES.filter(e => e.isBoss),
    ];
    const seen = new Set();
    const uniqueEnemies = [];
    for (const e of allEnemyTypes) {
        if (!seen.has(e.name)) {
            seen.add(e.name);
            uniqueEnemies.push(e);
        }
    }

    uniqueEnemies.forEach(e => {
        const owned = player.collection.enemies.includes(e.name);
        const card = document.createElement('div');
        card.className = 'compendium-card' + (owned ? '' : ' locked');
        const kills = player.killsByName[e.name] || 0;
        card.innerHTML = `<span class="cc-icon">${owned ? (e.icon || '👾') : '❓'}</span><span class="cc-name">${owned ? e.name : '???'}</span>`;
        if (owned) {
            card.title = `${e.icon || '👾'} ${e.name}\nHP: ${e.hp} | ATK: ${e.atk}\n처치 수: ${kills}마리\n${e.flying ? '🕊️ 비행' : ''}${e.ranged ? '🏹 원거리' : ''}${e.giant ? '👣 거대' : ''}`;
        } else {
            card.title = '아직 만나보지 못한 적';
        }
        grid.appendChild(card);
    });

    // Aux weapons section
    const auxHeader = document.createElement('div');
    auxHeader.className = 'compendium-section-header';
    auxHeader.textContent = '🎒 보조무기';
    grid.appendChild(auxHeader);

    AUX_WEAPONS.forEach(a => {
        const owned = (player.auxWeapons && player.auxWeapons.some(aw => aw.id === a.id)) ||
                      (player.auxWeapon && player.auxWeapon.id === a.id);
        const card = document.createElement('div');
        card.className = 'compendium-card' + (owned ? '' : ' locked');
        card.innerHTML = `<span class="cc-icon">${owned ? a.icon : '❓'}</span><span class="cc-name">${owned ? a.name : '???'}</span>`;
        if (owned) {
            card.title = `${a.icon} ${a.name}\n${a.desc}\n사용: ${a.uses > 0 ? a.uses + '회' : '무제한'}`;
        } else {
            card.title = '아직 발견하지 못한 보조무기';
        }
        grid.appendChild(card);
    });

    // Stats
    const totalWeapons = WEAPONS.length;
    const foundWeapons = player.collection.weapons.length;
    const totalItems = ITEMS.length;
    const foundItems = player.collection.items.length;
    const totalEnemies = [...new Set([...ENEMY_TYPES, ...DESERT_ENEMY_TYPES].map(e => e.name))].length;
    const foundEnemies = player.collection.enemies.length;
    document.getElementById('compendiumStats').textContent =
        `무기 ${foundWeapons}/${totalWeapons} | 아이템 ${foundItems}/${totalItems} | 적 ${foundEnemies}/${totalEnemies}`;
}

// ============================================================
//  SCARECROW (허수아비) - training dummy
// ============================================================
function hitScarecrow(sc, dmg) {
    sc.hurtTimer = 0.25;
    sc.animTimer = 0;
    spawnFloatingText(sc.x + sc.w / 2, sc.y - 8, `-${dmg}`, '#ffaa44');
    spawnParticles(sc.x + sc.w / 2, sc.y + sc.h / 2, '#ddcc88', 8);
}

function drawScarecrows() {
    for (const sc of scarecrows) {
        const sx = sc.x - camera.x, sy = sc.y - camera.y;
        if (sx < -60 || sx > canvas.width + 60 || sy < -80 || sy > canvas.height + 80) continue;
        const time = performance.now() / 1000;

        // Bob animation
        const bob = Math.sin(time * 2 + sc.animTimer) * 2;

        // Shadow
        ctx.fillStyle = 'rgba(0,0,0,0.4)';
        ctx.beginPath(); ctx.ellipse(sx + sc.w/2, sy + sc.h - 4, 14, 5, 0, 0, Math.PI * 2); ctx.fill();

        // Wooden post - thicker
        ctx.fillStyle = '#6b4c12';
        ctx.fillRect(sx + sc.w/2 - 4, sy + 24, 8, 32);
        ctx.fillStyle = '#8B6914';
        ctx.fillRect(sx + sc.w/2 - 3, sy + 24, 6, 30);

        // Cross bar - thicker
        ctx.fillStyle = '#6b4c12';
        ctx.fillRect(sx + sc.w/2 - 17, sy + 8, 34, 5);
        ctx.fillStyle = '#a07828';
        ctx.fillRect(sx + sc.w/2 - 16, sy + 9, 32, 3);

        // Straw body - bigger and darker
        ctx.fillStyle = '#c89830';
        ctx.beginPath();
        ctx.roundRect(sx + sc.w/2 - 12, sy - 5 + bob, 24, 28, 5);
        ctx.fill();
        // Straw outline
        ctx.strokeStyle = '#8a6820';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.roundRect(sx + sc.w/2 - 12, sy - 5 + bob, 24, 28, 5);
        ctx.stroke();

        // Straw texture lines
        ctx.strokeStyle = '#a07820';
        ctx.lineWidth = 1.5;
        for (let i = 0; i < 5; i++) {
            ctx.beginPath();
            ctx.moveTo(sx + sc.w/2 - 8, sy + 2 + i * 5 + bob);
            ctx.lineTo(sx + sc.w/2 + 8, sy + 2 + i * 5 + bob);
            ctx.stroke();
        }

        // Head (burlap sack) - bigger
        ctx.fillStyle = '#c8a870';
        ctx.beginPath();
        ctx.arc(sx + sc.w/2, sy - 11 + bob, 10, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = '#8a7040';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(sx + sc.w/2, sy - 11 + bob, 10, 0, Math.PI * 2);
        ctx.stroke();

        // Face - bigger
        ctx.fillStyle = '#222';
        ctx.font = '13px sans-serif'; ctx.textAlign = 'center';
        ctx.fillText('🥺', sx + sc.w/2, sy - 8 + bob);

        // Hat (straw hat)
        ctx.fillStyle = '#c89830';
        ctx.beginPath();
        ctx.ellipse(sx + sc.w/2, sy - 19 + bob, 14, 4, 0, Math.PI, 0);
        ctx.fill();
        ctx.fillStyle = '#a07828';
        ctx.fillRect(sx + sc.w/2 - 6, sy - 22 + bob, 12, 5);
        ctx.fillStyle = '#c89830';
        ctx.fillRect(sx + sc.w/2 - 5, sy - 21 + bob, 10, 4);

        // Hurt flash
        if (sc.hurtTimer > 0) {
            ctx.fillStyle = `rgba(255,255,255,${sc.hurtTimer * 2})`;
            ctx.beginPath();
            ctx.arc(sx + sc.w/2, sy + 4, 18, 0, Math.PI * 2);
            ctx.fill();
        }

        // Label - closer range
        const dist = distance(player.x + player.w/2, player.y + player.h/2, sc.x + sc.w/2, sc.y + sc.h/2);
        if (dist < 55) {
            ctx.fillStyle = '#ffcc88';
            ctx.font = 'bold 10px sans-serif'; ctx.textAlign = 'center';
            ctx.fillText('허수아비', sx + sc.w/2, sy - 28);
        }
    }
}

// ============================================================
//  SHOP SYSTEM
// ============================================================
const SHOP_ITEMS = {
    village: [
        { id: 'dagger', price: 50 },
        { id: 'iron', price: 120 },
        { id: 'axe', price: 250 },
        { id: 'fan', price: 300 },
        { id: 'whip', price: 350 },
        { id: 'crossbow', price: 180 },
        { id: 'staff', price: 400 },
        { itemId: 'healpot', price: 30 },
        { itemId: 'bomb', price: 60 },
        { itemId: 'antidote', price: 40 },
        { itemId: 'speedpot', price: 80 },
        { itemId: 'returngem', price: 500 },
    ],
    blackmarket: [
        { id: 'firesword', price: 800 },
        { id: 'hammer', price: 1000 },
        { id: 'legend', price: 2000 },
        { id: 'scimitar', price: 600 },
        { id: 'sandstorm', price: 1200 },
        { id: 'ankh', price: 1500 },
        { id: 'scorpion', price: 3000 },
        { itemId: 'healpot', price: 30 },
        { itemId: 'bomb', price: 60 },
        { itemId: 'antidote', price: 40 },
        { itemId: 'speedpot', price: 80 },
        { itemId: 'returngem', price: 500 },
    ],
};

let shopOpen = false;
let currentShopType = 'village';

function openShop(shopType) {
    shopOpen = true;
    currentShopType = shopType;
    gamePaused = true;

    const panel = document.getElementById('shopPanel');
    const title = document.getElementById('shopTitle');
    const goldDisplay = document.getElementById('shopGold');
    const slots = document.getElementById('shopSlots');

    panel.classList.remove('hidden', 'blackmarket');
    if (shopType === 'blackmarket') {
        panel.classList.add('blackmarket');
        title.textContent = '🥷 암시장';
    } else {
        title.textContent = '🏪 상점';
    }

    goldDisplay.textContent = `보유 골드: 💰 ${player.gold}`;
    slots.innerHTML = '';

    const items = SHOP_ITEMS[shopType] || [];
    items.forEach(entry => {
        if (entry.itemId) {
            // It's a consumable item
            const item = ITEMS.find(it => it.id === entry.itemId);
            if (!item) return;
            const canAfford = player.gold >= entry.price;

            const card = document.createElement('div');
            card.className = 'shop-item' + (canAfford ? '' : ' unaffordable');
            card.innerHTML = `
                <span class="s-icon">${item.icon}</span>
                <span class="s-name">${item.name}</span>
                <span class="s-desc">${item.desc}</span>
                <span class="s-price">💰 ${entry.price}</span>
            `;
            if (canAfford) {
                card.addEventListener('click', () => buyConsumable(item, entry.price));
            }
            slots.appendChild(card);
            return;
        }
        // It's a weapon
        const weapon = WEAPONS.find(w => w.id === entry.id);
        if (!weapon) return;
        const canAfford = player.gold >= entry.price;

        const card = document.createElement('div');
        card.className = 'shop-item' + (canAfford ? '' : ' unaffordable');
        card.innerHTML = `
            <span class="s-icon">${weapon.icon}</span>
            <span class="s-name">${weapon.name}</span>
            <span class="s-atk">ATK ${weapon.atk}</span>
            <span class="s-desc">${weapon.desc || ''}</span>
            <span class="s-price">💰 ${entry.price}</span>
        `;
        if (canAfford) {
            card.addEventListener('click', () => buyItem(weapon, entry.price));
        }
        slots.appendChild(card);
    });
}

function closeShop() {
    shopOpen = false;
    gamePaused = false;
    document.getElementById('shopPanel').classList.add('hidden');
}

function buyItem(weapon, price) {
    if (player.gold < price) return;
    if (inventory.length >= 12) {
        addMessage('🎒 인벤토리가 가득 찼습니다!', 'damage');
        return;
    }
    player.gold -= price;
    inventory.push({ ...weapon });
    addToCollection('weapons', weapon.id);
    playCoinSound();
    addMessage(`🛒 ${weapon.icon} ${weapon.name} 구매! (-${price}💰)`, 'loot');
    updateUI();
    openShop(currentShopType); // refresh shop
}

function buyConsumable(item, price) {
    if (player.gold < price) return;
    if (player.items.length >= 3) {
        addMessage('🎒 아이템이 가득 찼습니다! (최대 3개)', 'damage');
        return;
    }
    player.gold -= price;
    player.items.push({ ...item });
    addToCollection('items', item.id);
    playCoinSound();
    addMessage(`🛒 ${item.icon} ${item.name} 구매! (-${price}💰)`, 'loot');
    updateUI();
    openShop(currentShopType); // refresh shop
}

// ============================================================
//  SLOT MACHINE
// ============================================================
const SLOT_SYMBOLS = ['💰', '💸', '👁️', '☠️', '🌀', '💎'];

function useSlotMachine() {
    if (player.gold < 50) {
        addMessage('🎰 골드가 부족합니다! (50💰 필요)', 'damage');
        return;
    }
    player.gold -= 50;
    updateUI();

    const outcomes = ['gold200', 'lose100', 'vision', 'poison', 'teleport', 'legendary'];
    const resultIdx = Math.floor(Math.random() * outcomes.length);
    const result = outcomes[resultIdx];

    // Jackpot: all 3 symbols match (gold, legendary)
    const isJackpot = result === 'gold200' || result === 'legendary';
    // Pick symbols
    const jackpotSymbol = SLOT_SYMBOLS[Math.floor(Math.random() * SLOT_SYMBOLS.length)];
    // For fail: ensure at least one reel differs
    let s1, s2, s3;
    if (isJackpot) {
        s1 = s2 = s3 = jackpotSymbol;
    } else {
        s1 = SLOT_SYMBOLS[Math.floor(Math.random() * SLOT_SYMBOLS.length)];
        do { s2 = SLOT_SYMBOLS[Math.floor(Math.random() * SLOT_SYMBOLS.length)]; } while (s2 === s1);
        do { s3 = SLOT_SYMBOLS[Math.floor(Math.random() * SLOT_SYMBOLS.length)]; } while (s3 === s1 && s3 === s2);
    }

    // Show modal and animate
    const modal = document.getElementById('slotMachine');
    const reel1 = document.getElementById('reel1');
    const reel2 = document.getElementById('reel2');
    const reel3 = document.getElementById('reel3');
    const resultText = document.getElementById('slotResult');
    modal.classList.remove('hidden');
    gamePaused = true;
    resultText.textContent = '';

    // Start spinning animation
    [reel1, reel2, reel3].forEach(r => {
        r.textContent = '❓';
        r.classList.add('spinning');
        r.classList.remove('stopped');
    });

    // Symbol cycling
    let cycleIdx = 0;
    const cycleInterval = setInterval(() => {
        cycleIdx = (cycleIdx + 1) % SLOT_SYMBOLS.length;
        reel1.textContent = SLOT_SYMBOLS[cycleIdx];
        reel2.textContent = SLOT_SYMBOLS[(cycleIdx + 2) % SLOT_SYMBOLS.length];
        reel3.textContent = SLOT_SYMBOLS[(cycleIdx + 4) % SLOT_SYMBOLS.length];
    }, 100);

    // Stop reels one by one
    setTimeout(() => {
        reel1.classList.remove('spinning');
        reel1.classList.add('stopped');
        reel1.textContent = s1;
    }, 800);

    setTimeout(() => {
        reel2.classList.remove('spinning');
        reel2.classList.add('stopped');
        reel2.textContent = s2;
    }, 1200);

    setTimeout(() => {
        reel3.classList.remove('spinning');
        reel3.classList.add('stopped');
        reel3.textContent = s3;
        clearInterval(cycleInterval);

        // Highlight all reels if jackpot
        if (isJackpot) {
            [reel1, reel2, reel3].forEach(r => {
                r.style.borderColor = '#ffd700';
                r.style.boxShadow = '0 0 30px rgba(255,215,0,0.8), inset 0 0 20px rgba(255,215,0,0.4)';
                r.style.fontSize = '44px';
            });
        }

        // Apply result
        applySlotResult(result);
        resultText.textContent = getSlotResultText(result);

        // Close modal after delay
        setTimeout(() => {
            modal.classList.add('hidden');
            gamePaused = false;
            // Reset reel styles
            [reel1, reel2, reel3].forEach(r => {
                r.style.borderColor = '';
                r.style.boxShadow = '';
                r.style.fontSize = '';
            });
        }, 1800);
    }, 1600);
}

function getSlotResultText(result) {
    switch (result) {
        case 'gold200': return '💰 잭팟! 200골드 획득!';
        case 'lose100': return '💸 100골드를 잃었습니다...';
        case 'vision': return '👁️ 시야가 절반으로! (1분)';
        case 'poison': return '☠️ 독에 감염! (3분)';
        case 'teleport': return '🌀 랜덤 위치로 이동!';
        case 'legendary': return '💎 전설의 검 획득!!!';
    }
}

function applySlotResult(result) {
    switch (result) {
        case 'gold200':
            player.gold += 200;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ffd700', 30);
            playCoinSound();
            break;
        case 'lose100':
            player.gold = Math.max(0, player.gold - 100);
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ff4444', 20);
            break;
        case 'vision':
            player.visionReduction = 60;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#444488', 15);
            break;
        case 'poison':
            player.poisonTimer += 180;
            if (player.poisonTick <= 0) player.poisonTick = 10;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#88ff44', 20);
            break;
        case 'teleport':
            randomTeleport();
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#aaccff', 25);
            break;
        case 'legendary':
            if (inventory.length < 12) {
                const legendWpn = WEAPONS.find(w => w.id === 'legend');
                inventory.push({ ...legendWpn });
                addToCollection('weapons', 'legend');
            } else {
                player.gold += 100;
            }
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ffd700', 40);
            break;
    }
    addMessage(`🎰 ${getSlotResultText(result)}`, result === 'gold200' || result === 'legendary' ? 'loot' : 'damage');
    updateUI();
}

function randomTeleport() {
    for (let tries = 0; tries < 100; tries++) {
        const tx = 3 + Math.floor(Math.random() * (MAP_W - 6));
        const ty = 3 + Math.floor(Math.random() * (MAP_H - 6));
        if (!isSolid(tx, ty) && !isWater(tx, ty)) {
            player.x = tx * TILE_SIZE + TILE_SIZE / 2;
            player.y = ty * TILE_SIZE + TILE_SIZE / 2;
            player.mount = null;
            updateCamera(player.x + player.w / 2, player.y + player.h / 2);
            return;
        }
    }
    player.x = FOUNTAIN_CX;
    player.y = FOUNTAIN_CY;
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);
}

function updateQuestJournal() {
    const list = document.getElementById('questList');
    list.innerHTML = '';
    player.activeQuests.forEach(aq => {
        const q = getQuest(aq.id);
        if (!q) return;
        const entry = document.createElement('div');
        entry.className = 'quest-entry';
        entry.innerHTML = `<span class="q-title">${q.name}</span><br><span class="q-progress">${getQuestProgress(q, aq.progress)}</span>`;
        list.appendChild(entry);
    });
    if (player.activeQuests.length === 0) {
        list.innerHTML = '<p style="color:#888;font-size:12px;">활성 퀘스트 없음</p>';
    }
    document.getElementById('questJournal').classList.toggle('hidden', player.activeQuests.length === 0);
}

function getQuestProgress(quest, progress) {
    if (quest.type === 'kills') return `처치: ${progress} / ${quest.target}`;
    if (quest.type === 'kills_specific') return `${quest.enemyName || '적'} 처치: ${progress} / ${quest.target}`;
    if (quest.type === 'gold') return `골드: ${progress} / ${quest.target}`;
    if (quest.type === 'boss') return progress >= quest.target ? '완료!' : '보스 처치 필요';
    if (quest.type === 'boss_specific') return progress >= quest.target ? '완료!' : `${quest.bossName || '보스'} 처치 필요`;
    return `${progress} / ${quest.target}`;
}

function updateQuestProgress() {
    let changed = false;
    for (let i = player.activeQuests.length - 1; i >= 0; i--) {
        const aq = player.activeQuests[i];
        const q = getQuest(aq.id);
        if (!q) continue;
        let prog = aq.progress;
        if (q.type === 'kills') prog = player.kills;
        else if (q.type === 'kills_specific') prog = (player.killsByName[q.enemyName] || 0);
        else if (q.type === 'gold') prog = player.gold;
        else if (q.type === 'boss') prog = aq.progress || 0;
        else if (q.type === 'boss_specific') prog = aq.progress || 0;
        if (prog !== aq.progress) { aq.progress = prog; changed = true; }
        if (prog >= q.target && !player.completedQuests.includes(aq.id)) {
            player.completedQuests.push(aq.id);
            player.gold += q.rewardGold;
            addMessage(`✅ 퀘스트 완료: ${q.name}! (+${q.rewardGold}💰)`, 'loot');
            if (q.rewardAux) {
                const auxWpn = AUX_WEAPONS.find(a => a.id === q.rewardAux);
                if (auxWpn) {
                    player.auxWeapons.push({ ...auxWpn });
                    if (!player.auxWeapon) player.auxWeapon = player.auxWeapons[0];
                    addToCollection('weapons', auxWpn.id);
                    addMessage(`🎁 보조무기: ${auxWpn.icon} ${auxWpn.name}`, 'loot');
                }
            }
            player.activeQuests.splice(i, 1);
            changed = true;
            updateUI();
        }
    }
    if (!gameVictory && player.currentRegion === 'forest' && MAIN_QUESTS.every(mq => player.completedQuests.includes(mq))) {
        triggerVictory('🏆 모든 주요 퀘스트 완료!');
    }
    if (!gameVictory && player.currentRegion === 'desert' && DESERT_QUESTS.every(dq => player.completedQuests.includes(dq))) {
        triggerVictory('🏆 사막의 모든 퀘스트 완료! 진정한 승리!');
    }
    if (!gameVictory && !player._desertUnlocked && player.currentRegion === 'forest' &&
        player.completedQuests.includes('slay_boss') &&
        player.completedQuests.includes('collect_1000gold')) {
        player._desertUnlocked = true;
        addMessage('🏜️ 사막 지역이 해금되었습니다! 분수 근처 여행자를 찾아가세요!', 'loot');
        // Spawn desert traveler NPC near fountain
        spawnDesertTraveler();
    }
    if (changed) updateQuestJournal();
}

function gameLoop(time) {
    const dt = Math.min((time - lastTime) / 1000, 0.1);
    lastTime = time;
    update(dt);
    requestAnimationFrame(gameLoop);
}

// ============================================================
//  INIT
// ============================================================
let gameStarted = false;

// Controls toggle
document.addEventListener('DOMContentLoaded', () => {
    const toggle = document.getElementById('controlsToggle');
    const panel = document.getElementById('controls');
    if (toggle && panel) {
        toggle.addEventListener('click', () => {
            panel.classList.toggle('hidden');
            toggle.textContent = panel.classList.contains('hidden') ? '🎮 키 설명' : '🎮 접기';
        });
    }

    // Start particle animation
    initStartParticles();
    // Set up start button
    const startBtn = document.getElementById('startGameBtn');
    if (startBtn) {
        startBtn.addEventListener('click', () => startGame());
    }
});

function initStartParticles() {
    const pCanvas = document.getElementById('startParticles');
    if (!pCanvas) return;
    pCanvas.width = window.innerWidth;
    pCanvas.height = window.innerHeight;
    const pCtx = pCanvas.getContext('2d');
    const pts = [];
    for (let i = 0; i < 50; i++) {
        pts.push({
            x: Math.random() * pCanvas.width,
            y: Math.random() * pCanvas.height,
            vx: (Math.random() - 0.5) * 20,
            vy: -10 - Math.random() * 25,
            size: 1 + Math.random() * 2.5,
            alpha: 0.3 + Math.random() * 0.5,
            life: Math.random() * 3,
        });
    }
    function animate() {
        if (!document.getElementById('startScreen') || document.getElementById('startScreen').classList.contains('hidden')) return;
        pCtx.clearRect(0, 0, pCanvas.width, pCanvas.height);
        for (const p of pts) {
            p.x += p.vx * 0.016;
            p.y += p.vy * 0.016;
            p.life -= 0.016;
            if (p.life <= 0 || p.y < -20) {
                p.x = Math.random() * pCanvas.width;
                p.y = pCanvas.height + 10;
                p.life = 2 + Math.random() * 3;
            }
            const alpha = p.alpha * Math.min(1, p.life);
            pCtx.fillStyle = `rgba(255,215,0,${alpha * 0.6})`;
            pCtx.beginPath(); pCtx.arc(p.x, p.y, p.size, 0, Math.PI * 2); pCtx.fill();
            pCtx.fillStyle = `rgba(255,255,200,${alpha * 0.3})`;
            pCtx.beginPath(); pCtx.arc(p.x - 1, p.y - 1, p.size * 0.6, 0, Math.PI * 2); pCtx.fill();
        }
        requestAnimationFrame(animate);
    }
    animate();
}

function showAuxSelection() {
    const grid = document.getElementById('auxSelection');
    grid.innerHTML = '';

    AUX_WEAPONS.forEach((aux, i) => {
        const card = document.createElement('div');
        card.className = `aux-card ${aux.type}`;
        card.innerHTML = `
            <span class="aux-icon">${aux.icon}</span>
            <span class="aux-name">${aux.name}</span>
            <span class="aux-desc">${aux.desc}</span>
            <span class="aux-uses">${aux.uses > 0 ? `사용 가능: ${aux.uses}회` : '영구 사용'}</span>
        `;
        card.addEventListener('click', () => startGame(i));
        grid.appendChild(card);
    });
}

function startGame() {
    document.getElementById('startScreen').classList.add('hidden');
    gameStarted = true;

    // No initial aux weapon - obtain them through quests

    const seed = Math.floor(Math.random() * 100000);
    generateMap(seed);

    let px = Math.floor(MAP_W / 2);
    let py = Math.floor(MAP_H / 2);
    while (isSolid(px, py)) {
        px = 5 + Math.floor(Math.random() * (MAP_W - 10));
        py = 5 + Math.floor(Math.random() * (MAP_H - 10));
    }
    player.x = px * TILE_SIZE + TILE_SIZE / 2;
    player.y = py * TILE_SIZE + TILE_SIZE / 2;

    spawnEnemies();
    spawnInitialPickups();
    updateUI();
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);

    addMessage('🗡️ 모험을 떠나세요!', 'info');
    addMessage('⛲ 맵 중앙 분수에서 체력 회복', 'info');
    addMessage('❗ NPC를 찾아 대화하세요 [E]', 'loot');
    addMessage('🎒 보조무기는 퀘스트 보상으로 획득! (N/K 사용, Q 순환)', 'loot');
    addMessage('이동: WASD | 공격: Space/J | 보조: N/K | 순환: Q | 인벤: I/Esc', 'info');
    addMessage('📖 C: 도감 열기', 'info');

    // Auto-collect starter weapon
    addToCollection('weapons', 'fist');

    startBgMusic();
    lastTime = performance.now();
    requestAnimationFrame(gameLoop);
}

function spawnInitialPickups() {
    for (let i = 0; i < 10; i++) {
        const { x: gx, y: gy } = randomSpawnTile(3, (txi, tyi) => !isSolid(txi, tyi) && !isWater(txi, tyi));
        spawnGoldPickup(gx * TILE_SIZE + TILE_SIZE / 2, gy * TILE_SIZE + TILE_SIZE / 2);
    }
    // Spawn wooden chests
    for (let i = 0; i < 4; i++) {
        const { x: cx, y: cy } = randomSpawnTile(4, (txi, tyi, x, y) =>
            !isSolid(txi, tyi) && !isWater(txi, tyi) && distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 150);
        spawnChest(cx * TILE_SIZE + TILE_SIZE / 2, cy * TILE_SIZE + TILE_SIZE / 2, 'wooden');
    }
    // Spawn 1 iron chest
    {
        const { x: cx, y: cy } = randomSpawnTile(5, (txi, tyi, x, y) =>
            !isSolid(txi, tyi) && !isWater(txi, tyi) && distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 200);
        spawnChest(cx * TILE_SIZE + TILE_SIZE / 2, cy * TILE_SIZE + TILE_SIZE / 2, 'iron');
    }

    // Spawn mounts
    spawnInitialMounts();
    spawnNPCs();
}

function spawnNPCs() {
    // Create multiple NPCs scattered around the map
    const npcDefs = [
        { icon: '🧙', name: '현자', dialog: '안녕하신가, 용사여! 자네에게 주요 임무를 맡기겠네.', quests: ['kill_monsters', 'hunt_wolves'] },
        { icon: '👨‍🌾', name: '농부', dialog: '독수리가 내 작물을 망치고 있어요!', quests: ['hunt_eagles'] },
        { icon: '🧝', name: '요정', dialog: '반짝이는 골드가 필요해!', quests: ['collect_coins'] },
        { icon: '👴', name: '촌장', dialog: '용사여, 위대한 임무를 맡아주게나.', quests: ['collect_gold', 'slay_boss', 'collect_riches', 'collect_1000gold'] },
    ];
    for (let i = 0; i < npcDefs.length; i++) {
        const def = npcDefs[i];
        let nx, ny;
        for (let tries = 0; tries < 50; tries++) {
            nx = 5 + Math.random() * (MAP_W - 10);
            ny = 5 + Math.random() * (MAP_H - 10);
            if (!isSolid(Math.floor(nx), Math.floor(ny)) && !isWater(Math.floor(nx), Math.floor(ny)) &&
                distance(nx * TILE_SIZE, ny * TILE_SIZE, player.x, player.y) > 100) break;
        }
        npcs.push({
            x: nx * TILE_SIZE + TILE_SIZE / 2 - 12,
            y: ny * TILE_SIZE + TILE_SIZE / 2 - 14,
            w: 24, h: 28,
            icon: def.icon, name: def.name, dialog: def.dialog,
            quests: def.quests,
        });
    }

    // ── Village shop NPC (near fountain) ──
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    npcs.push({
        x: (fcx + 8) * TILE_SIZE + TILE_SIZE / 2 - 32,
        y: fcy * TILE_SIZE + TILE_SIZE / 2 - 32,
        w: 64, h: 64,
        icon: '🏪', name: '상인',
        dialog: '어서오세요! 좋은 무기를 골드로 판매합니다.',
        quests: [],
        isShop: true,
        shopType: 'village',
    });

    // ── Appearance change NPC (near fountain) ──
    npcs.push({
        x: (fcx + 3) * TILE_SIZE + TILE_SIZE / 2 - 12,
        y: (fcy - 7) * TILE_SIZE + TILE_SIZE / 2 - 14,
        w: 24, h: 28,
        icon: '💈', name: '미용사',
        dialog: '용사님, 외관을 바꿔드릴까요? 멋진 모습으로 모험을 떠나보세요!',
        quests: [],
        isStylist: true,
    });

    // ── Scarecrow (training dummy) right next to fountain ──
    scarecrows.push({
        x: (fcx - 2) * TILE_SIZE + TILE_SIZE / 2 - 18,
        y: (fcy - 2) * TILE_SIZE + TILE_SIZE / 2 - 4,
        w: 36, h: 54,
        hp: 99999, maxHp: 99999,
        hurtTimer: 0,
        animTimer: 0,
    });

    // ── Slot machine NPC (near fountain, opposite side) ──
    npcs.push({
        x: (fcx - 8) * TILE_SIZE + TILE_SIZE / 2 - 28,
        y: (fcy + 2) * TILE_SIZE + TILE_SIZE / 2 - 28,
        w: 56, h: 56,
        icon: '🎰', name: '슬롯머신',
        dialog: '50골드를 넣고 레버를 당기면 랜덤한 능력이 발동됩니다!\n\n🎁 200골드 획득 | 💸 100골드 잃음\n👁️ 시야 절반 | ☠️ 독 감염\n🌀 랜덤 이동 | 💎 전설 무기',
        quests: [],
        isSlotMachine: true,
    });

    // ── Black market NPC (map edge) ──
    let bmx, bmy;
    const corners = [
        [3, 3], [MAP_W - 4, 3], [3, MAP_H - 4], [MAP_W - 4, MAP_H - 4],
        [3, MAP_H / 2], [MAP_W - 4, MAP_H / 2], [MAP_W / 2, 3], [MAP_W / 2, MAP_H - 4]
    ];
    for (const [cx, cy] of corners) {
        if (!isSolid(Math.floor(cx), Math.floor(cy)) && !isWater(Math.floor(cx), Math.floor(cy)) &&
            distance(cx * TILE_SIZE, cy * TILE_SIZE, player.x, player.y) > 400) {
            bmx = cx; bmy = cy; break;
        }
    }
    if (!bmx) { bmx = 3; bmy = 3; }
    npcs.push({
        x: bmx * TILE_SIZE + TILE_SIZE / 2 - 32,
        y: bmy * TILE_SIZE + TILE_SIZE / 2 - 32,
        w: 64, h: 64,
        icon: '🥷', name: '암시장 상인',
        dialog: '쉿... 희귀한 물건들입니다. 값은 비싸지만요.',
        quests: [],
        isShop: true,
        shopType: 'blackmarket',
    });
}

function spawnDesertTraveler() {
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    npcs.push({
        x: (fcx - 8) * TILE_SIZE + TILE_SIZE / 2 - 12,
        y: fcy * TILE_SIZE + TILE_SIZE / 2 - 14,
        w: 24, h: 28,
        icon: '🐪', name: '사막 여행자',
        dialog: '사막으로 가는 길을 알고 있습니다. 함께 가시겠습니까?',
        quests: [],
        isDesertTraveler: true,
    });
    addMessage('🐪 분수 근처에 사막 여행자가 나타났다!', 'loot');
}

// ============================================================
//  PORTAL SYSTEM (분수 → 사막 포탈)
// ============================================================
function checkPortalSpawn() {
    // 조건: 보스 처치 + 1000골드 + 포탈이 아직 없음 + 숲 지역
    if (player.bossKilled && player.gold >= 1000 && portals.length === 0 && player.currentRegion === 'forest') {
        spawnPortal();
    }
}

function spawnPortal() {
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    portals.push({
        x: fcx * TILE_SIZE + TILE_SIZE / 2 - 28,
        y: fcy * TILE_SIZE + TILE_SIZE / 2 - 28,
        w: 56, h: 56,
        animTimer: 0,
    });
    addMessage('🌀 분수 중앙에 차원 포탈이 열렸다! 다가가서 상호작용하세요 [E]', 'loot');
}

function interactPortal() {
    let closestPortal = null, closestDist = 50;
    for (const p of portals) {
        const dist = distance(player.x + player.w/2, player.y + player.h/2, p.x + p.w/2, p.y + p.h/2);
        if (dist < closestDist) { closestPortal = p; closestDist = dist; }
    }
    if (!closestPortal) return false;

    gamePaused = true;
    document.getElementById('npcDialog').classList.remove('hidden');
    document.getElementById('npcPortrait').textContent = '🌀';
    document.getElementById('npcName').textContent = '차원 포탈';
    document.getElementById('npcText').textContent = '사막으로 통하는 포탈이 열려있습니다. 들어가시겠습니까?';
    const opts = document.getElementById('npcOptions');
    opts.innerHTML = '';
    const travelBtn = document.createElement('div');
    travelBtn.className = 'dialog-option';
    travelBtn.innerHTML = `<span class="q-name">🏜️ 사막으로 이동</span><br><span class="q-desc">포탈을 통해 사막 지역으로 떠납니다</span><br><span class="q-reward">⚠️ 돌아올 수 없습니다</span>`;
    travelBtn.addEventListener('click', () => {
        closeDialog();
        travelToDesert();
    });
    opts.appendChild(travelBtn);
    return true;
}

// ============================================================
//  DESERT TRAVEL
// ============================================================
function travelToDesert() {
    player.currentRegion = 'desert';
    player.bossKilled = false;
    // Clear current world state
    enemies.length = 0;
    projectiles.length = 0;
    enemyProjectiles.length = 0;
    fireZones.length = 0;
    goldPickups.length = 0;
    chests.length = 0;
    npcs.length = 0;
    mounts.length = 0;
    particles.length = 0;
    floatingTexts.length = 0;
    weaponPickups.length = 0;
    portals.length = 0;

    // Generate desert map
    generateDesertMap(Math.floor(Math.random() * 100000) + 50000);

    // Place player at desert center
    player.x = MAP_W * TILE_SIZE / 2;
    player.y = MAP_H * TILE_SIZE / 2;
    player.mount = null;

    // Spawn desert enemies
    spawnDesertEnemies();
    // Spawn desert pickups
    spawnDesertPickups();
    // Spawn desert NPCs
    spawnDesertNPCs();

    updateUI();
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);
    addMessage('🏜️ 사막에 도착했습니다! 새로운 모험이 기다립니다!', 'loot');
    addMessage('☠️ 사막의 적들은 더욱 강력합니다...', 'damage');
}

function generateDesertMap(seed) {
    const noise = new SimpleNoise(seed);
    tileMap = [];

    for (let y = 0; y < MAP_H; y++) {
        tileMap[y] = [];
        for (let x = 0; x < MAP_W; x++) {
            const h = noise.fbm(x * 0.03, y * 0.03, 4, 2.2, 0.5);

            let tile;
            if (h < -0.25) {
                tile = 'SAND';
            } else if (h < -0.1) {
                tile = Math.random() < 0.3 ? 'ROCK' : 'SAND';
            } else if (h < 0.1) {
                tile = Math.random() < 0.15 ? 'ROCK' : 'SAND';
            } else if (h < 0.25) {
                tile = Math.random() < 0.5 ? 'ROCK' : 'SAND';
            } else {
                tile = 'ROCK';
            }

            // Add oasis near center
            const fcx = Math.floor(MAP_W / 2);
            const fcy = Math.floor(MAP_H / 2);
            const dist = Math.sqrt((x - fcx) ** 2 + (y - fcy) ** 2);
            if (dist < 4) {
                tile = 'WATER';
            } else if (dist < 6) {
                tile = Math.random() < 0.5 ? 'GRASS' : 'SAND';
            } else if (dist < 8) {
                tile = Math.random() < 0.2 ? 'GRASS' : 'SAND';
            }

            // Scatter cacti (use BUSH)
            if (tile === 'SAND' && Math.random() < 0.03) {
                tile = 'BUSH';
            }

            tileMap[y][x] = TILE_KEYS.indexOf(tile);
        }
    }

    ensureConnectivity();
}

function spawnDesertEnemies() {
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    const enemyCount = 25;
    for (let i = 0; i < enemyCount; i++) {
        const { x: ex, y: ey } = randomSpawnTile(4, (txi, tyi, x, y) =>
            !isSolid(txi, tyi) && !isWater(txi, tyi) &&
            distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 200 &&
            distance(x, y, fcx, fcy) >= 5);
        spawnByDistance('desert', ex, ey);
    }

    // Spawn desert boss (Pharaoh) far away
    const bossData = DESERT_ENEMY_TYPES.find(e => e.isBoss);
    if (bossData) {
        const { x: bx, y: by } = randomSpawnTile(10, (txi, tyi, x, y) =>
            !isSolid(txi, tyi) && !isWater(txi, tyi) &&
            distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 500);
        const t = { ...bossData };
        enemies.push({
            x: bx * TILE_SIZE + TILE_SIZE / 2,
            y: by * TILE_SIZE + TILE_SIZE / 2,
            w: t.size, h: t.size,
            hp: Math.floor(t.hp * 1.3), maxHp: Math.floor(t.hp * 1.3),
            atk: t.atk,
            speed: t.speed,
            name: t.name, icon: t.icon, color: t.color,
            dropRate: t.dropRate, dropPool: t.dropPool,
            isBoss: true, megaBoss: false,
            ranged: t.ranged || false,
            rangeCooldown: t.rangeCooldown || 2,
            projSpeed: t.projSpeed || 250,
            flying: false,
            level: player.stage + 8,
            animTimer: Math.random() * Math.PI * 2,
            state: 'wander', stateTimer: 0,
            attackCooldown: 0, rangeAttackCd: 1,
            hurtTimer: 0, frozen: 0,
            _knockbackX: 0, _knockbackY: 0,
            dir: 0,
            wanderTarget: { x: bx * TILE_SIZE, y: by * TILE_SIZE },
        });
        addMessage(`👑 ${t.name} 등장! 사막을 지배하는 자...`, 'damage');
    }
}

function spawnDesertPickups() {
    for (let i = 0; i < 12; i++) {
        const { x: gx, y: gy } = randomSpawnTile(3, (txi, tyi) => !isSolid(txi, tyi) && !isWater(txi, tyi));
        spawnGoldPickup(gx * TILE_SIZE + TILE_SIZE / 2, gy * TILE_SIZE + TILE_SIZE / 2);
    }
    for (let i = 0; i < 3; i++) {
        const { x: cx, y: cy } = randomSpawnTile(4, (txi, tyi, x, y) =>
            !isSolid(txi, tyi) && !isWater(txi, tyi) && distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 150);
        spawnChest(cx * TILE_SIZE + TILE_SIZE / 2, cy * TILE_SIZE + TILE_SIZE / 2, 'iron');
    }
}

function spawnDesertNPCs() {
    const npcDefs = [
        { icon: '🧕', name: '유목민', dialog: '사막에서 살아남으려면 좋은 무기가 필요하지...', quests: ['collect_1000gold'] },
        { icon: '📜', name: '고고학자', dialog: '파라오의 무덤에 대해 알고 있나?', quests: ['slay_pharaoh'] },
    ];
    for (const def of npcDefs) {
        let nx, ny;
        for (let tries = 0; tries < 50; tries++) {
            nx = 5 + Math.random() * (MAP_W - 10);
            ny = 5 + Math.random() * (MAP_H - 10);
            if (!isSolid(Math.floor(nx), Math.floor(ny)) && !isWater(Math.floor(nx), Math.floor(ny)) &&
                distance(nx * TILE_SIZE, ny * TILE_SIZE, player.x, player.y) > 120) break;
        }
        npcs.push({
            x: nx * TILE_SIZE + TILE_SIZE / 2 - 12,
            y: ny * TILE_SIZE + TILE_SIZE / 2 - 14,
            w: 24, h: 28,
            icon: def.icon, name: def.name, dialog: def.dialog,
            quests: def.quests,
        });
    }

    // Desert oasis shop
    const fcx = Math.floor(MAP_W / 2);
    const fcy = Math.floor(MAP_H / 2);
    npcs.push({
        x: (fcx + 8) * TILE_SIZE + TILE_SIZE / 2 - 32,
        y: fcy * TILE_SIZE + TILE_SIZE / 2 - 32,
        w: 64, h: 64,
        icon: '🏕️', name: '오아시스 상인',
        dialog: '사막의 희귀한 무기들... 관심 있나?',
        quests: [],
        isShop: true,
        shopType: 'blackmarket',
    });
}

function spawnInitialMounts() {
    // Land mounts
    const landMounts = [MOUNT_TYPES[0], MOUNT_TYPES[1], MOUNT_TYPES[2]]; // bicycle, horse, motor
    for (const mt of landMounts) {
        const { x: mx, y: my } = randomSpawnTile(4, (txi, tyi, x, y) =>
            !isSolid(txi, tyi) && !isWater(txi, tyi) && distance(x * TILE_SIZE, y * TILE_SIZE, player.x, player.y) >= 150);
        spawnMount(mt, mx * TILE_SIZE + TILE_SIZE / 2, my * TILE_SIZE + TILE_SIZE / 2);
    }
    // Boat: spawn at water edge
    const boat = MOUNT_TYPES[3];
    for (let tries = 0; tries < 50; tries++) {
        let bx = 3 + Math.random() * (MAP_W - 6);
        let by = 3 + Math.random() * (MAP_H - 6);
        const tileIdx = getTile(Math.floor(bx), Math.floor(by));
        const tileKey = TILE_KEYS[tileIdx];
        // Must be on water
        if (tileKey !== 'WATER' && tileKey !== 'WATER_DEEP') continue;
        // Must have at least one walkable neighbor tile (shore)
        let hasLand = false;
        for (const [dx, dy] of [[0,-1],[0,1],[-1,0],[1,0]]) {
            const nt = getTile(Math.floor(bx) + dx, Math.floor(by) + dy);
            if (!TILE[TILE_KEYS[nt]].solid) { hasLand = true; break; }
        }
        if (hasLand) {
            spawnMount(boat, bx * TILE_SIZE + TILE_SIZE / 2, by * TILE_SIZE + TILE_SIZE / 2);
            break;
        }
    }
}

