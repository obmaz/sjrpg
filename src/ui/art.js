import { enemyWorldArt } from '../data/art.js';
import { CONTROL_SPRITES } from '../data/ui-art.js';
import { getUiSpriteStyle } from './sprite-layout.js';

function artClass(item) {
    const creature = item && enemyWorldArt(item);
    if (creature) return `art-icon world-icon world-${creature}`;
    return Number.isInteger(item?.artIndex) ? `art-icon art-${item.artIndex}` : '';
}

function itemArt(item, className = '') {
    return `<span class="${className} ${artClass(item)}" aria-hidden="true">${item.icon || '✦'}</span>`;
}

export { artClass, itemArt };

// Loading artwork never blocks starting or using the CSS/SVG controls.
if (typeof Image === 'function') {
    const skin = new Image();
    skin.onload = () => document.getElementById('gameArea').classList.add('reference-skin-ready');
    skin.src = new URL('../../assets/ui-reference.webp', import.meta.url).href;
    const controls = new Image();
    controls.onload = () => {
        const bind = (element, bounds, prefix = '--sprite') => {
            const sprite = getUiSpriteStyle(bounds, controls.naturalWidth, controls.naturalHeight);
            element.style.setProperty(`${prefix}-size`, sprite.size);
            element.style.setProperty(`${prefix}-x`, sprite.x);
            element.style.setProperty(`${prefix}-y`, sprite.y);
        };
        for (const [id, bounds] of Object.entries(CONTROL_SPRITES)) {
            if (id === 'auxEmpty' || id === 'roundEmpty') continue;
            bind(document.getElementById(id), bounds);
        }
        for (const id of ['touchAux', 'touchCycle', 'touchInteract'])
            bind(document.getElementById(id), CONTROL_SPRITES.roundEmpty);
        bind(document.getElementById('touchAux'), CONTROL_SPRITES.auxEmpty, '--empty-sprite');
        document.getElementById('gameArea').classList.add('controls-skin-ready');
    };
    controls.src = new URL('../../assets/controls.webp', import.meta.url).href;
    const panel = new Image();
    panel.onload = () => document.getElementById('popupLayer').classList.add('popup-skin-ready');
    panel.src = new URL('../../assets/popup-frame.webp', import.meta.url).href;
}
