// ============================================================
//  SOUND SYSTEM (Web Audio API synthesized sounds)
// ============================================================
let audioContext = null;
function getAudioContext() {
    if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
    return audioContext;
}

function playSlashSound() {
    try {
        const ac = getAudioContext();
        const t = ac.currentTime;
        // Noise burst for slash
        const bufferSize = ac.sampleRate * 0.08;
        const buf = ac.createBuffer(1, bufferSize, ac.sampleRate);
        const data = buf.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            const env = 1 - i / bufferSize;
            data[i] = (Math.random() * 2 - 1) * env * env * 0.4;
        }
        const noise = ac.createBufferSource();
        noise.buffer = buf;
        const filter = ac.createBiquadFilter();
        filter.type = 'bandpass';
        filter.frequency.value = 2500;
        filter.Q.value = 1.5;
        const gain = ac.createGain();
        gain.gain.setValueAtTime(0.5, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.1);
        noise.connect(filter);
        filter.connect(gain);
        gain.connect(ac.destination);
        noise.start(t);
        noise.stop(t + 0.1);
        // Low thump
        const osc = ac.createOscillator();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(200, t);
        osc.frequency.exponentialRampToValueAtTime(60, t + 0.06);
        const g2 = ac.createGain();
        g2.gain.setValueAtTime(0.3, t);
        g2.gain.exponentialRampToValueAtTime(0.01, t + 0.08);
        osc.connect(g2);
        g2.connect(ac.destination);
        osc.start(t);
        osc.stop(t + 0.08);
    } catch {
        /* audio not available */
    }
}

function playHitSound() {
    try {
        const ac = getAudioContext();
        const t = ac.currentTime;
        const osc = ac.createOscillator();
        osc.type = 'square';
        osc.frequency.setValueAtTime(300, t);
        osc.frequency.exponentialRampToValueAtTime(80, t + 0.07);
        const g = ac.createGain();
        g.gain.setValueAtTime(0.25, t);
        g.gain.exponentialRampToValueAtTime(0.01, t + 0.1);
        osc.connect(g);
        g.connect(ac.destination);
        osc.start(t);
        osc.stop(t + 0.1);
    } catch {}
}

function playCoinSound() {
    try {
        const ac = getAudioContext();
        const t = ac.currentTime;
        [1200, 1800].forEach((freq, i) => {
            const osc = ac.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, t + i * 0.05);
            const g = ac.createGain();
            g.gain.setValueAtTime(0.2, t + i * 0.05);
            g.gain.exponentialRampToValueAtTime(0.01, t + i * 0.05 + 0.08);
            osc.connect(g);
            g.connect(ac.destination);
            osc.start(t + i * 0.05);
            osc.stop(t + i * 0.05 + 0.08);
        });
    } catch {}
}

function playPlayerHurtSound() {
    try {
        const ac = getAudioContext();
        const t = ac.currentTime;
        const osc = ac.createOscillator();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(200, t);
        osc.frequency.exponentialRampToValueAtTime(50, t + 0.15);
        const g = ac.createGain();
        g.gain.setValueAtTime(0.3, t);
        g.gain.exponentialRampToValueAtTime(0.01, t + 0.2);
        osc.connect(g);
        g.connect(ac.destination);
        osc.start(t);
        osc.stop(t + 0.2);
    } catch {}
}

function playChestBreak(isIron) {
    try {
        const ac = getAudioContext();
        const t = ac.currentTime;
        if (isIron) {
            // Loud metal clang
            const osc = ac.createOscillator();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(300, t);
            osc.frequency.exponentialRampToValueAtTime(60, t + 0.3);
            const g = ac.createGain();
            g.gain.setValueAtTime(0.6, t);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.35);
            osc.connect(g);
            g.connect(ac.destination);
            osc.start(t);
            osc.stop(t + 0.35);
            // Metallic ring
            const osc2 = ac.createOscillator();
            osc2.type = 'square';
            osc2.frequency.setValueAtTime(800, t);
            osc2.frequency.exponentialRampToValueAtTime(400, t + 0.25);
            const g2 = ac.createGain();
            g2.gain.setValueAtTime(0.35, t);
            g2.gain.exponentialRampToValueAtTime(0.01, t + 0.25);
            osc2.connect(g2);
            g2.connect(ac.destination);
            osc2.start(t);
            osc2.stop(t + 0.25);
            // Low thump
            const osc3 = ac.createOscillator();
            osc3.type = 'sine';
            osc3.frequency.setValueAtTime(80, t);
            osc3.frequency.exponentialRampToValueAtTime(20, t + 0.15);
            const g3 = ac.createGain();
            g3.gain.setValueAtTime(0.5, t);
            g3.gain.exponentialRampToValueAtTime(0.01, t + 0.15);
            osc3.connect(g3);
            g3.connect(ac.destination);
            osc3.start(t);
            osc3.stop(t + 0.15);
        } else {
            // Wood crack - louder, longer
            const bufferSize = ac.sampleRate * 0.25;
            const buf = ac.createBuffer(1, bufferSize, ac.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / bufferSize, 1.5) * 0.8;
            }
            const noise = ac.createBufferSource();
            noise.buffer = buf;
            const filter = ac.createBiquadFilter();
            filter.type = 'bandpass';
            filter.frequency.value = 500;
            filter.Q.value = 1.2;
            const g = ac.createGain();
            g.gain.setValueAtTime(0.7, t);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.3);
            noise.connect(filter);
            filter.connect(g);
            g.connect(ac.destination);
            noise.start(t);
            noise.stop(t + 0.3);
            // Wood thump
            const osc = ac.createOscillator();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(120, t);
            osc.frequency.exponentialRampToValueAtTime(30, t + 0.2);
            const g2 = ac.createGain();
            g2.gain.setValueAtTime(0.5, t);
            g2.gain.exponentialRampToValueAtTime(0.01, t + 0.2);
            osc.connect(g2);
            g2.connect(ac.destination);
            osc.start(t);
            osc.stop(t + 0.2);
        }
    } catch {}
}

function playEnemyDeathSound(enemyName) {
    try {
        const ac = getAudioContext();
        const t = ac.currentTime;
        const name = enemyName || '';
        if (name.includes('슬라임')) {
            const osc = ac.createOscillator();
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(200, t);
            osc.frequency.exponentialRampToValueAtTime(40, t + 0.3);
            const g = ac.createGain();
            g.gain.setValueAtTime(0.25, t);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.35);
            osc.connect(g);
            g.connect(ac.destination);
            osc.start(t);
            osc.stop(t + 0.35);
        } else if (name.includes('늑대')) {
            const osc = ac.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(400, t);
            osc.frequency.linearRampToValueAtTime(600, t + 0.15);
            osc.frequency.linearRampToValueAtTime(300, t + 0.3);
            const g = ac.createGain();
            g.gain.setValueAtTime(0.2, t);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.35);
            osc.connect(g);
            g.connect(ac.destination);
            osc.start(t);
            osc.stop(t + 0.35);
        } else if (name.includes('해골')) {
            const bufferSize = ac.sampleRate * 0.2;
            const buf = ac.createBuffer(1, bufferSize, ac.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                const env = 1 - i / bufferSize;
                data[i] = (Math.random() * 2 - 1) * env * env * 0.3 * Math.sin(i * 0.1);
            }
            const noise = ac.createBufferSource();
            noise.buffer = buf;
            const filter = ac.createBiquadFilter();
            filter.type = 'highpass';
            filter.frequency.value = 1500;
            const g = ac.createGain();
            g.gain.setValueAtTime(0.3, t);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.25);
            noise.connect(filter);
            filter.connect(g);
            g.connect(ac.destination);
            noise.start(t);
            noise.stop(t + 0.25);
        } else if (name.includes('메이지')) {
            const osc = ac.createOscillator();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(800, t);
            osc.frequency.exponentialRampToValueAtTime(200, t + 0.25);
            const g = ac.createGain();
            g.gain.setValueAtTime(0.2, t);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.3);
            osc.connect(g);
            g.connect(ac.destination);
            osc.start(t);
            osc.stop(t + 0.3);
            const osc2 = ac.createOscillator();
            osc2.type = 'sine';
            osc2.frequency.setValueAtTime(1000, t + 0.05);
            osc2.frequency.exponentialRampToValueAtTime(150, t + 0.3);
            const g2 = ac.createGain();
            g2.gain.setValueAtTime(0.15, t + 0.05);
            g2.gain.exponentialRampToValueAtTime(0.01, t + 0.3);
            osc2.connect(g2);
            g2.connect(ac.destination);
            osc2.start(t + 0.05);
            osc2.stop(t + 0.3);
        } else if (name.includes('보스') || name.includes('트롤')) {
            const osc = ac.createOscillator();
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(150, t);
            osc.frequency.linearRampToValueAtTime(300, t + 0.1);
            osc.frequency.exponentialRampToValueAtTime(30, t + 0.5);
            const g = ac.createGain();
            g.gain.setValueAtTime(0.3, t);
            g.gain.linearRampToValueAtTime(0.4, t + 0.1);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.55);
            osc.connect(g);
            g.connect(ac.destination);
            osc.start(t);
            osc.stop(t + 0.55);
        } else if (name.includes('골렘')) {
            const bufferSize = ac.sampleRate * 0.3;
            const buf = ac.createBuffer(1, bufferSize, ac.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                const env = 1 - i / bufferSize;
                data[i] = (Math.random() * 2 - 1) * env * env * 0.35;
            }
            const noise = ac.createBufferSource();
            noise.buffer = buf;
            const filter = ac.createBiquadFilter();
            filter.type = 'lowpass';
            filter.frequency.value = 600;
            const g = ac.createGain();
            g.gain.setValueAtTime(0.4, t);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.35);
            noise.connect(filter);
            filter.connect(g);
            g.connect(ac.destination);
            noise.start(t);
            noise.stop(t + 0.35);
        } else {
            const osc = ac.createOscillator();
            osc.type = 'square';
            osc.frequency.setValueAtTime(250, t);
            osc.frequency.exponentialRampToValueAtTime(60, t + 0.2);
            const g = ac.createGain();
            g.gain.setValueAtTime(0.2, t);
            g.gain.exponentialRampToValueAtTime(0.01, t + 0.25);
            osc.connect(g);
            g.connect(ac.destination);
            osc.start(t);
            osc.stop(t + 0.25);
        }
    } catch {}
}

// ============================================================
//  BACKGROUND MUSIC (ambient)
// ============================================================
let backgroundMusic = null;
function startBgMusic() {
    if (!backgroundMusic) backgroundMusic = document.getElementById('bgMusic');
    if (!backgroundMusic) return;
    backgroundMusic.volume = 0.3;
    backgroundMusic.play().catch(() => {
        // Autoplay blocked — retry on next user interaction
        const tryPlay = () => {
            if (backgroundMusic) backgroundMusic.play().catch(() => {});
        };
        document.addEventListener('click', tryPlay, { once: true });
        document.addEventListener('keydown', tryPlay, { once: true });
    });
}

function stopBgMusic() {
    if (backgroundMusic) {
        backgroundMusic.pause();
        backgroundMusic.currentTime = 0;
    }
}

export {
    playSlashSound,
    playHitSound,
    playCoinSound,
    playPlayerHurtSound,
    playChestBreak,
    playEnemyDeathSound,
    startBgMusic,
    stopBgMusic,
};
