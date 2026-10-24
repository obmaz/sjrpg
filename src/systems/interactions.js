import { canOccupyMountPosition, distanceBetweenRectangles } from '../core/collision.js';
import { mounts, npcs, player, portals } from '../core/state.js';

function nearestInteraction(entities, point) {
    let nearest = null;
    let closestDistance = 40;
    for (const entity of entities) {
        if (
            point &&
            (point.x < entity.x - 12 ||
                point.x > entity.x + entity.w + 12 ||
                point.y < entity.y - 12 ||
                point.y > entity.y + entity.h + 12)
        )
            continue;
        const separation = distanceBetweenRectangles(player, entity);
        if (separation < closestDistance) {
            nearest = entity;
            closestDistance = separation;
        }
    }
    return nearest;
}

// Share the exact target and portal priority between touch feedback and activation.
function getInteractionTarget(point = null) {
    const portal = nearestInteraction(portals, point);
    if (portal) return { kind: 'portal', entity: portal, label: '이동', symbol: 'icon-compass' };
    const npc = nearestInteraction(npcs, point);
    if (!npc) {
        const mount =
            !player.mount &&
            nearestInteraction(
                mounts.filter((m) => canOccupyMountPosition(m, m.x, m.y)),
                point,
            );
        return mount ? { kind: 'mount', entity: mount, label: '타기', symbol: 'icon-foot' } : null;
    }
    const [label, symbol] = npc.isShop
        ? ['상점', 'icon-bag']
        : npc.isSlotMachine
          ? ['뽑기', 'icon-spark']
          : npc.isStylist
            ? ['외관', 'icon-shield']
            : npc.isDesertTraveler
              ? ['여행', 'icon-compass']
              : ['대화', 'icon-chat'];
    return { kind: 'npc', entity: npc, label, symbol };
}

export { getInteractionTarget };
