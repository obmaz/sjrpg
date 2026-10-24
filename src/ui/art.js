import { enemyWorldArt } from '../data/art.js';

function artClass(item) {
    const creature = item && enemyWorldArt(item);
    if (creature) return `art-icon world-icon world-${creature}`;
    return Number.isInteger(item?.artIndex) ? `art-icon art-${item.artIndex}` : '';
}

function itemArt(item, className = '') {
    return `<span class="${className} ${artClass(item)}" aria-hidden="true">${item.icon || '✦'}</span>`;
}

export { artClass, itemArt };

// Keep the usable CSS/SVG controls while the painted UI is loading or unavailable.
if (typeof Image === 'function') {
    const skin = new Image();
    skin.onload = () => document.getElementById('gameArea').classList.add('reference-skin-ready');
    skin.src = new URL('../../assets/ui-reference.webp', import.meta.url).href;
}
