import { createPaintedPanel } from './painted-panel.js';
import { VILLAGE } from '../data/village.js';
import { player } from '../core/state.js';
let scene = null;
let panel = null;
if (typeof Image === 'function') {
    scene = new Image();
    scene.onload = () => {
        panel = createPaintedPanel(
            scene,
            0,
            0,
            scene.naturalWidth,
            scene.naturalHeight,
            VILLAGE.width,
            VILLAGE.height,
        );
    };
    scene.src = new URL('../../assets/village-scene.webp', import.meta.url).href;
}
function villageArtReady() {
    return player.currentRegion === 'forest' && !!scene?.complete && scene.naturalWidth > 0;
}
function drawVillage(context, camera) {
    if (!villageArtReady()) return;
    context.drawImage(
        panel || scene,
        VILLAGE.x - camera.x - (panel ? 40 : 0),
        VILLAGE.y - camera.y - (panel ? 40 : 0),
        VILLAGE.width + (panel ? 80 : 0),
        VILLAGE.height + (panel ? 80 : 0),
    );
}
export { villageArtReady, drawVillage };
