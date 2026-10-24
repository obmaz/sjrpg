import { INVENTORY_CAPACITY } from '../core/constants.js';
import { recordDiscovery } from '../core/helpers.js';
import { inventory, player } from '../core/state.js';
import { addMessage } from '../ui/messages.js';

function receiveWeapon(weapon, { autoSalvage = true } = {}) {
    const duplicate =
        player.weapon.id === weapon.id || inventory.some((item) => item.id === weapon.id);
    if (autoSalvage && duplicate && weapon.uses === undefined) {
        const gold = Math.max(5, Math.round((weapon.value || 50) * 0.2));
        player.gold += gold;
        recordDiscovery('weapons', weapon.id);
        addMessage(`💰 중복 ${weapon.name} → ${gold} 골드`, 'loot');
        return 'salvaged';
    }
    if (inventory.length >= INVENTORY_CAPACITY) return 'full';
    inventory.push({ ...weapon });
    recordDiscovery('weapons', weapon.id);
    addMessage(`🎁 ${weapon.icon} ${weapon.name} 획득!`, 'loot');
    return 'stored';
}

export { receiveWeapon };
