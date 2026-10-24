const TAU = Math.PI * 2;
function getActorAngle(actor) {
    return Number.isFinite(actor.facingAngle) && actor.facingDir === actor.dir
        ? actor.facingAngle
        : [Math.PI / 2, Math.PI, -Math.PI / 2, 0][actor.dir ?? 0];
}
function setActorFacing(actor, angle) {
    actor.facingAngle = angle;
    const quadrant = ((Math.round(angle / (Math.PI / 2)) % 4) + 4) % 4;
    actor.dir = [3, 0, 1, 2][quadrant];
    actor.facingDir = actor.dir;
}
function facingFrame(angle, count = 16) {
    return ((Math.round(((angle - Math.PI / 2) * count) / TAU) % count) + count) % count;
}
export { getActorAngle, setActorFacing, facingFrame };
