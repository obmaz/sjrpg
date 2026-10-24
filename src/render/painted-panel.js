// Mirror just the outer texture strips and fade them to soften large scene joins.
function createPaintedPanel(image, sx, sy, sw, sh, width, height, margin = 40) {
    const panel = document.createElement('canvas');
    panel.width = width + margin * 2;
    panel.height = height + margin * 2;
    const ctx = panel.getContext('2d');
    for (let row = -1; row <= 1; row++)
        for (let col = -1; col <= 1; col++) {
            const bandX = (sw * margin) / width,
                bandY = (sh * margin) / height;
            const sourceX = col < 0 ? sx : col > 0 ? sx + sw - bandX : sx,
                sourceY = row < 0 ? sy : row > 0 ? sy + sh - bandY : sy;
            const sourceW = col ? bandX : sw,
                sourceH = row ? bandY : sh;
            const drawW = col ? margin : width,
                drawH = row ? margin : height;
            const x = col < 0 ? 0 : col > 0 ? margin + width : margin,
                y = row < 0 ? 0 : row > 0 ? margin + height : margin;
            ctx.save();
            ctx.translate(x + (col ? drawW : 0), y + (row ? drawH : 0));
            ctx.scale(col ? -1 : 1, row ? -1 : 1);
            ctx.drawImage(image, sourceX, sourceY, sourceW, sourceH, 0, 0, drawW, drawH);
            ctx.restore();
        }
    ctx.globalCompositeOperation = 'destination-in';
    for (const vertical of [false, true]) {
        const size = vertical ? panel.height : panel.width;
        const gradient = ctx.createLinearGradient(0, 0, vertical ? 0 : size, vertical ? size : 0);
        gradient.addColorStop(0, '#0000');
        gradient.addColorStop(margin / size, '#000');
        gradient.addColorStop(1 - margin / size, '#000');
        gradient.addColorStop(1, '#0000');
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, panel.width, panel.height);
    }
    return panel;
}
export { createPaintedPanel };
