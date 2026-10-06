'use strict';

// ============================================================
//  INVENTORY UI
// ============================================================
const inventoryPanel = document.getElementById('inventory');
const inventorySlots = document.getElementById('inventorySlots');

function toggleInventory() {
    if (!isGameActive() || gamePaused) return;
    inventoryOpen = !inventoryOpen;
    if (inventoryOpen) {
        inventoryPanel.classList.remove('hidden');
        selectedInventoryIndex = 0;
        refreshInventoryUI();
    } else {
        inventoryPanel.classList.add('hidden');
    }
}

function navigateInventory(code) {
    const cols = INVENTORY_COLUMNS;
    let row = Math.floor(selectedInventoryIndex / cols);
    let col = selectedInventoryIndex % cols;
    if (code === 'ArrowUp') row = Math.max(0, row - 1);
    if (code === 'ArrowDown') row = Math.min(Math.ceil(INVENTORY_CAPACITY / cols) - 1, row + 1);
    if (code === 'ArrowLeft') col = Math.max(0, col - 1);
    if (code === 'ArrowRight') col = Math.min(cols - 1, col + 1);
    selectedInventoryIndex = row * cols + col;
    refreshInventoryUI();
}

function selectInventoryItem() {
    if (selectedInventoryIndex < inventory.length) {
        equipWeapon(selectedInventoryIndex);
    }
}

function refreshInventoryUI() {
    inventorySlots.innerHTML = '';
    for (let i = 0; i < INVENTORY_CAPACITY; i++) {
        const slot = document.createElement('div');
        slot.className = 'inventory-slot';
        if (i === selectedInventoryIndex) slot.classList.add('selected');
        if (i < inventory.length) {
            const item = inventory[i];
            slot.innerHTML = `<span class="icon">${item.icon}</span><span class="name">${item.name}</span><span class="atk">ATK ${item.atk}</span><span class="ability">${item.desc || ''}</span>`;
            slot.style.borderColor = item.color;
            slot.addEventListener('click', () => {
                selectedInventoryIndex = i;
                equipWeapon(i);
            });
        } else {
            slot.classList.add('empty');
            slot.innerHTML = '<span class="icon">—</span><span class="name">빈 슬롯</span>';
        }
        inventorySlots.appendChild(slot);
    }
}

function equipWeapon(index) {
    if (!Number.isInteger(index) || index < 0 || index >= inventory.length) return;
    const item = inventory[index];
    // Unequip current weapon (if not fist)
    if (player.weapon.id !== 'fist') {
        inventory.push({ ...player.weapon });
    }
    // Equip
    player.weapon = item;
    player.comboHits = 0;
    player.comboTimer = 0;
    inventory.splice(index, 1);
    refreshInventoryUI();
    updateHud();
    addMessage(`⚔️ ${item.name} 장착! (${item.desc || ''})`, 'loot');
}
