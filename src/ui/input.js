import { isGameActive } from '../core/helpers.js';
import { session } from '../core/state.js';
import { cycleAuxWeapon, useAuxWeapon } from '../systems/auxiliary-weapons.js';
import { useConsumable } from '../systems/consumables.js';
import { dismountPlayer } from '../systems/mounts.js';
import { closeAppearancePanel } from './appearance.js';
import { toggleCompendium } from './compendium.js';
import { closeDialog, interactNpc } from './dialogs.js';
import { navigateInventory, selectInventoryItem, toggleInventory } from './inventory.js';
import { closeShop } from './shop.js';

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
    if (session.compendiumOpen) toggleCompendium();
    else if (session.shopOpen) closeShop();
    else if (session.inventoryOpen) toggleInventory();
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
    if (session.slotMachineOpen || (event.repeat && !event.code.startsWith('Arrow'))) return;
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
            if (!session.inventoryOpen && !closeActivePanel()) interactNpc();
            break;
        case 'Enter':
            if (session.inventoryOpen) selectInventoryItem();
            break;
        default:
            if (session.inventoryOpen && event.code.startsWith('Arrow'))
                navigateInventory(event.code);
    }
}

window.addEventListener('keydown', handleKeyDown);
window.addEventListener('keyup', (event) => {
    keys[event.code] = false;
});
window.addEventListener('blur', () => {
    for (const key of Object.keys(keys)) delete keys[key];
});

export { keys };
