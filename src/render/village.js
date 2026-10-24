import { VILLAGE } from '../data/village.js';
import { player } from '../core/state.js';
let scene = null;
if (typeof Image === 'function') {
    scene = new Image();
    scene.src = new URL('../../assets/village-scene.webp', import.meta.url).href;
}
function villageArtReady() {
    return player.currentRegion === 'forest' && !!scene?.complete && scene.naturalWidth > 0;
}
function drawVillage(context, camera) {
    if (!villageArtReady()) return;
    context.drawImage(
        scene,
        VILLAGE.x - camera.x,
        VILLAGE.y - camera.y,
        VILLAGE.width,
        VILLAGE.height,
    );
}
export { villageArtReady, drawVillage };
