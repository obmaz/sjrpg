'use strict';

const keys = {};
const GAME_KEY_CODES = new Set([
    'ArrowLeft',
    'ArrowRight',
    'ArrowUp',
    'ArrowDown',
    'KeyA',
    'KeyD',
    'KeyW',
    'KeyS',
    'KeyJ',
    'KeyI',
    'KeyN',
    'KeyK',
    'KeyU',
    'KeyE',
    'KeyQ',
    'KeyC',
    'Digit1',
    'Digit2',
    'Digit3',
    'Space',
    'Escape',
    'Enter',
]);

function closeActivePanel() {
    if (compendiumOpen) toggleCompendium();
    else if (shopOpen) closeShop();
    else if (inventoryOpen) toggleInventory();
    else if (!document.getElementById('appearancePanel').classList.contains('hidden'))
        closeAppearancePanel();
    else if (!document.getElementById('npcDialog').classList.contains('hidden')) closeDialog();
    else return false;
    return true;
}

function handleKeyDown(event) {
    if (!isGameActive() || !GAME_KEY_CODES.has(event.code)) return;
    event.preventDefault();
    keys[event.code] = true;
    if (slotMachineOpen || (event.repeat && !event.code.startsWith('Arrow'))) return;
    switch (event.code) {
        case 'KeyI':
        case 'Escape':
            if (!closeActivePanel()) toggleInventory();
            break;
        case 'KeyN':
        case 'KeyK':
            useAuxWeapon();
            break;
        case 'KeyQ':
            cycleAuxWeapon();
            break;
        case 'KeyU':
            dismountPlayer();
            break;
        case 'Digit1':
        case 'Digit2':
        case 'Digit3':
            useConsumable(Number(event.code.slice(-1)) - 1);
            break;
        case 'KeyC':
            toggleCompendium();
            break;
        case 'KeyE':
            if (!inventoryOpen && !closeActivePanel()) interactNpc();
            break;
        case 'Enter':
            if (inventoryOpen) selectInventoryItem();
            break;
        default:
            if (inventoryOpen && event.code.startsWith('Arrow')) navigateInventory(event.code);
    }
}

window.addEventListener('keydown', handleKeyDown);
window.addEventListener('keyup', (event) => {
    keys[event.code] = false;
});
window.addEventListener('blur', () => {
    for (const key of Object.keys(keys)) delete keys[key];
});
