'use strict';

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
function resizeCanvas() {
    const gameArea = document.getElementById('gameArea');
    if (gameArea) {
        canvas.width = gameArea.clientWidth;
        canvas.height = gameArea.clientHeight;
    } else {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }
}
window.addEventListener('resize', () => {
    resizeCanvas();
    if (gameStarted) {
        updateCamera(player.x + player.w / 2, player.y + player.h / 2);
        draw();
    }
});
resizeCanvas();

// ============================================================
//  CAMERA
// ============================================================
const camera = { x: 0, y: 0 };

function updateCamera(targetX, targetY) {
    camera.x = targetX - canvas.width / 2;
    camera.y = targetY - canvas.height / 2;
    // Clamp
    camera.x = Math.max(0, Math.min(MAP_WIDTH * TILE_SIZE - canvas.width, camera.x));
    camera.y = Math.max(0, Math.min(MAP_HEIGHT * TILE_SIZE - canvas.height, camera.y));
}
