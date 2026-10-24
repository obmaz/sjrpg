import { distance } from '../core/helpers.js';
import { npcs, player, portals } from '../core/state.js';

function nearestInteraction(entities) {
    let nearest = null;
    let closestDistance = 50;
    for (const entity of entities) {
        const separation = distance(
            player.x + player.w / 2,
            player.y + player.h / 2,
            entity.x + entity.w / 2,
            entity.y + entity.h / 2,
        );
        if (separation < closestDistance) {
            nearest = entity;
            closestDistance = separation;
        }
    }
    return nearest;
}

// Share the exact target and portal priority between touch feedback and activation.
function getInteractionTarget() {
    const portal = nearestInteraction(portals);
    if (portal) return { kind: 'portal', entity: portal, label: '이동', symbol: 'icon-compass' };
    const npc = nearestInteraction(npcs);
    if (!npc) return null;
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
