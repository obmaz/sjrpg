'use strict';

// ============================================================
//  SHOP SYSTEM
// ============================================================

function openShop(shopType) {
    shopOpen = true;
    currentShopType = shopType;
    gamePaused = true;

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
        const consumable = Boolean(entry.itemId);
        const item = consumable
            ? ITEMS.find((item) => item.id === entry.itemId)
            : WEAPONS.find((weapon) => weapon.id === entry.id);
        if (!item) return;
        const canAfford = player.gold >= entry.price;
        const card = document.createElement('div');
        card.className = 'shop-item' + (canAfford ? '' : ' unaffordable');
        card.innerHTML = `<span class="s-icon">${item.icon}</span>
            <span class="s-name">${item.name}</span>
            ${consumable ? '' : `<span class="s-atk">ATK ${item.atk}</span>`}
            <span class="s-desc">${item.desc || ''}</span>
            <span class="s-price">💰 ${entry.price}</span>`;
        if (canAfford)
            card.addEventListener('click', () => buyShopItem(item, entry.price, consumable));
        slots.appendChild(card);
    });
}

function closeShop() {
    shopOpen = false;
    gamePaused = false;
    document.getElementById('shopPanel').classList.add('hidden');
}

function buyShopItem(item, price, consumable) {
    if (!isGameActive() || !shopOpen || player.gold < price) return;
    const items = consumable ? player.items : inventory;
    const capacity = consumable ? CONSUMABLE_CAPACITY : INVENTORY_CAPACITY;
    if (items.length >= capacity) {
        addMessage(
            consumable ? '🎒 아이템이 가득 찼습니다! (최대 3개)' : '🎒 인벤토리가 가득 찼습니다!',
            'damage',
        );
        return;
    }
    player.gold -= price;
    items.push({ ...item });
    recordDiscovery(consumable ? 'items' : 'weapons', item.id);
    playCoinSound();
    addMessage(`🛒 ${item.icon} ${item.name} 구매! (-${price}💰)`, 'loot');
    updateHud();
    openShop(currentShopType);
}
