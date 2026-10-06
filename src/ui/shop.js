import { AUX_WEAPONS } from '../data/aux-weapons.js';
import { CONSUMABLE_CAPACITY, INVENTORY_CAPACITY } from '../core/constants.js';
import { isGameActive, recordDiscovery } from '../core/helpers.js';
import { inventory, player, session } from '../core/state.js';
import { ITEMS } from '../data/items.js';
import { SHOP_ITEMS } from '../data/shops.js';
import { WEAPONS } from '../data/weapons.js';
import { playCoinSound } from '../systems/audio.js';
import { updateHud } from './hud.js';
import { addMessage } from './messages.js';

// ============================================================
//  SHOP SYSTEM
// ============================================================

function openShop(shopType) {
    session.shopOpen = true;
    session.currentShopType = shopType;
    session.gamePaused = true;

    const panel = document.getElementById('shopPanel');
    const title = document.getElementById('shopTitle');
    const goldDisplay = document.getElementById('shopGold');
    const slots = document.getElementById('shopSlots');

    panel.classList.remove('hidden', 'blackmarket');
    if (shopType === 'blackmarket') {
        panel.classList.add('blackmarket');
        title.textContent = '🥷 암시장';
    } else {
        title.textContent = '🏪 상점';
    }

    goldDisplay.textContent = `보유 골드: 💰 ${player.gold}`;
    slots.innerHTML = '';

    const items = SHOP_ITEMS[shopType] || [];
    items.forEach((entry) => {
        const kind = entry.auxId ? 'auxiliary' : entry.itemId ? 'consumable' : 'weapon';
        const item =
            kind === 'auxiliary'
                ? AUX_WEAPONS.find((item) => item.id === entry.auxId)
                : kind === 'consumable'
                  ? ITEMS.find((item) => item.id === entry.itemId)
                  : WEAPONS.find((item) => item.id === entry.id);
        if (!item) return;
        const canAfford = player.gold >= entry.price;
        const card = document.createElement('div');
        card.className = 'shop-item' + (canAfford ? '' : ' unaffordable');
        card.innerHTML = `<span class="s-icon">${item.icon}</span>
            <span class="s-name">${item.name}</span>
            ${kind !== 'weapon' ? '' : `<span class="s-atk">ATK ${item.atk}</span>`}
            <span class="s-desc">${item.desc || ''}</span>
            <span class="s-price">💰 ${entry.price}</span>`;
        if (canAfford) card.addEventListener('click', () => buyShopItem(item, entry.price, kind));
        slots.appendChild(card);
    });
}

function closeShop() {
    session.shopOpen = false;
    session.gamePaused = false;
    document.getElementById('shopPanel').classList.add('hidden');
}

function buyShopItem(item, price, kind) {
    if (!isGameActive() || !session.shopOpen || player.gold < price) return;
    const consumable = kind === 'consumable';
    const auxiliary = kind === 'auxiliary';
    const items = auxiliary ? player.auxWeapons : consumable ? player.items : inventory;
    const capacity = auxiliary ? Infinity : consumable ? CONSUMABLE_CAPACITY : INVENTORY_CAPACITY;
    if (items.length >= capacity) {
        addMessage(
            consumable ? '🎒 아이템이 가득 찼습니다! (최대 3개)' : '🎒 인벤토리가 가득 찼습니다!',
            'damage',
        );
        return;
    }
    player.gold -= price;
    items.push({ ...item });
    if (auxiliary && !player.auxWeapon) player.auxWeapon = items.at(-1);
    recordDiscovery(auxiliary ? 'auxiliaryWeapons' : consumable ? 'items' : 'weapons', item.id);
    playCoinSound();
    addMessage(`🛒 ${item.icon} ${item.name} 구매! (-${price}💰)`, 'loot');
    updateHud();
    openShop(session.currentShopType);
}

export { openShop, closeShop, buyShopItem };
