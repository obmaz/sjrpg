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
        if (
            !document.getElementById('startScreen') ||
            document.getElementById('startScreen').classList.contains('hidden')
        )
            return;
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
            pCtx.beginPath();
            pCtx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            pCtx.fill();
            pCtx.fillStyle = `rgba(255,255,200,${alpha * 0.3})`;
            pCtx.beginPath();
            pCtx.arc(p.x - 1, p.y - 1, p.size * 0.6, 0, Math.PI * 2);
            pCtx.fill();
        }
        requestAnimationFrame(animate);
    }
    animate();
}

export { initStartParticles };
