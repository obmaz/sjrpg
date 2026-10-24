import { INVENTORY_CAPACITY, INVENTORY_COLUMNS } from '../core/constants.js';
import { isGameActive } from '../core/helpers.js';
import { inventory, player, session } from '../core/state.js';
import { spawnWeaponPickup } from '../systems/entities.js';
import { updateHud } from './hud.js';
import { addMessage } from './messages.js';
import { itemArt } from './art.js';

// ============================================================
//  INVENTORY UI
// ============================================================
const inventoryPanel = document.getElementById('inventory');
const inventorySlots = document.getElementById('inventorySlots');

function toggleInventory() {
    if (!isGameActive() || session.gamePaused) return;
    session.inventoryOpen = !session.inventoryOpen;
    if (session.inventoryOpen) {
        inventoryPanel.classList.remove('hidden');
        session.selectedInventoryIndex = 0;
        refreshInventoryUI();
    } else {
        inventoryPanel.classList.add('hidden');
    }
}

function navigateInventory(code) {
    const cols =
        typeof window.getComputedStyle === 'function'
            ? window.getComputedStyle(inventorySlots).gridTemplateColumns.split(' ').length
            : INVENTORY_COLUMNS;
    let row = Math.floor(session.selectedInventoryIndex / cols);
    let col = session.selectedInventoryIndex % cols;
    if (code === 'ArrowUp') row = Math.max(0, row - 1);
    if (code === 'ArrowDown') row = Math.min(Math.ceil(INVENTORY_CAPACITY / cols) - 1, row + 1);
    if (code === 'ArrowLeft') col = Math.max(0, col - 1);
    if (code === 'ArrowRight') col = Math.min(cols - 1, col + 1);
    session.selectedInventoryIndex = row * cols + col;
    refreshInventoryUI();
}

function selectInventoryItem() {
    if (session.selectedInventoryIndex < inventory.length) {
        equipWeapon(session.selectedInventoryIndex);
    }
}

function dropInventoryItem(index = session.selectedInventoryIndex) {
    if (
        !isGameActive() ||
        !session.inventoryOpen ||
        session.gamePaused ||
        !Number.isInteger(index) ||
        index < 0 ||
        index >= inventory.length
    )
        return;
    const item = inventory[index];
    spawnWeaponPickup(player.x + player.w / 2, player.y + player.h / 2, item, {
        pickupDelay: 1,
        autoSalvage: false,
    });
    inventory.splice(index, 1);
    session.selectedInventoryIndex = Math.max(
        0,
        Math.min(session.selectedInventoryIndex, inventory.length - 1),
    );
    refreshInventoryUI();
    addMessage(`🎒 ${item.icon} ${item.name}을(를) 바닥에 내려놓았습니다. (120초 유지)`, 'info');
}

function refreshInventoryUI() {
    document.getElementById('inventoryCount').textContent =
        `${inventory.length}/${INVENTORY_CAPACITY}`;
    document.getElementById('equippedSummary').innerHTML =
        `${itemArt(player.weapon, 'equipped-icon')}<span><span class="equipped-caption">장착 중</span><strong>${player.weapon.name}</strong> · ATK ${player.weapon.atk}</span>`;
    inventorySlots.innerHTML = '';
    for (let i = 0; i < INVENTORY_CAPACITY; i++) {
        const slot = document.createElement('div');
        slot.className = 'inventory-slot';
        if (i === session.selectedInventoryIndex) slot.classList.add('selected');
        if (i < inventory.length) {
            const item = inventory[i];
            const usesText = item.uses === undefined ? '사용 횟수 무제한' : `남은 ${item.uses}회`;
            slot.innerHTML = `${itemArt(item, 'icon')}<span class="rarity-badge">${item.rarity}</span><span class="name">${item.name}</span><span class="atk">ATK ${item.atk} · ${item.cooldown}초</span><span class="damage-dice">${item.damageDice || ''} ${item.damageType || ''}</span><span class="uses">${usesText}</span><span class="ability">${item.desc || ''}</span>`;
            slot.style.borderColor = item.color;
            slot.addEventListener('click', () => {
                session.selectedInventoryIndex = i;
                equipWeapon(i);
            });
            const dropButton = document.createElement('button');
            dropButton.type = 'button';
            dropButton.className = 'inventory-drop';
            dropButton.textContent = '버리기';
            dropButton.title = `${item.name} 바닥에 내려놓기 (120초 유지)`;
            dropButton.addEventListener('click', (event) => {
                event.stopPropagation();
                dropInventoryItem(i);
            });
            slot.appendChild(dropButton);
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

export { toggleInventory, navigateInventory, selectInventoryItem, dropInventoryItem };
