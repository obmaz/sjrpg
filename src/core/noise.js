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

    _fade(t) {
        return t * t * t * (t * (t * 6 - 15) + 10);
    }
    _lerp(a, b, t) {
        return a + t * (b - a);
    }
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
            v,
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

export { SimpleNoise };
