// Align the painted bounds, not the padded atlas cell, to the control's centre.
function getUiSpriteStyle(bounds, imageWidth, imageHeight) {
    const [x, y, width, height] = bounds;
    const side = Math.max(width, height) * 1.06;
    return {
        size: `${(imageWidth / side) * 100}% ${(imageHeight / side) * 100}%`,
        x: `${((x + width / 2 - side / 2) / (imageWidth - side)) * 100}%`,
        y: `${((y + height / 2 - side / 2) / (imageHeight - side)) * 100}%`,
    };
}

export { getUiSpriteStyle };
