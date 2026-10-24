import { ACTOR_SHEETS } from '../data/actor-art.js';
import { ACTOR_BOUNDS } from '../data/actor-bounds.js';
import { facingFrame, getActorAngle } from '../core/facing.js';
const sheets = new Map();
function getActorFrame(key, angle, phase = 0, action = 'walk') {
    const definition = ACTOR_SHEETS[key];
    if (!definition) return null;
    const [sheetName, row, count] = definition;
    const name = key === 'hero' && action === 'attack' ? 'hero-attack' : sheetName;
    const direction = facingFrame(angle, count);
    const step = phase % 2;
    const mirror = name === 'villagers' && row === 2 && direction === 7;
    const column = mirror ? 1 : direction;
    return {
        name,
        mirror,
        index: count === 16 ? direction + step * 16 : row * 8 + column + step * 32,
    };
}
function drawActorSprite(
    context,
    key,
    actor,
    x,
    feetY,
    width,
    height = width,
    angle = getActorAngle(actor),
) {
    let phase = actor.moving
        ? (actor.animFrame ?? Math.floor((actor.animTimer || 0) / 0.13)) % 2
        : 0;
    let action = 'walk';
    const elapsed = (actor.lastAttackCooldown || 0) - actor.attackTimer;
    if (
        key === 'hero' &&
        actor.attackSerial > 0 &&
        elapsed >= 0 &&
        elapsed < Math.min(0.26, actor.lastAttackCooldown) &&
        actor.attackTimer > 0 &&
        ['dagger', 'iron', 'firesword', 'ice_sword', 'legend', 'scimitar', 'scorpion'].includes(
            (actor.attackVisual || actor.weapon)?.id,
        )
    ) {
        action = 'attack';
        phase = elapsed < 0.055 ? 0 : 1;
        angle = actor.attackAngle ?? angle;
    }
    const frame = getActorFrame(key, angle, phase, action);
    if (!frame || typeof Image !== 'function') return false;
    if (!sheets.has(frame.name)) {
        const image = new Image();
        image.src = new URL(`../../assets/actors-${frame.name}.webp`, import.meta.url).href;
        sheets.set(frame.name, image);
    }
    const image = sheets.get(frame.name);
    if (!image.complete || !image.naturalWidth) return false;
    const bounds = ACTOR_BOUNDS[frame.name];
    if (!bounds) return false;
    const [sx, sy, sw, sh] = bounds.frames[frame.index];
    const definition = ACTOR_SHEETS[key];
    const [maxWidth, maxHeight] = bounds.sizes[definition[1]];
    const scale =
        key === 'hero' ? height / maxHeight : Math.min(width / maxWidth, height / maxHeight);
    context.save();
    context.translate(x, feetY);
    if (frame.mirror) context.scale(-1, 1);
    context.drawImage(
        image,
        sx,
        sy,
        sw,
        sh,
        (-sw * scale) / 2,
        -sh * scale,
        sw * scale,
        sh * scale,
    );
    context.restore();
    return true;
}
function getActorSpriteHeight(key, width, height) {
    const definition = ACTOR_SHEETS[key];
    if (!definition) return height;
    const size = ACTOR_BOUNDS[definition[0]]?.sizes[definition[1]];
    return size ? Math.min(width / size[0], height / size[1]) * size[1] : height;
}
export { getActorFrame, drawActorSprite, getActorSpriteHeight };
