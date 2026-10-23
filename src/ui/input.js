import { isGameActive } from '../core/helpers.js';
import { session } from '../core/state.js';
import { cycleAuxWeapon, useAuxWeapon } from '../systems/auxiliary-weapons.js';
import { useConsumable } from '../systems/consumables.js';
import { dismountPlayer } from '../systems/mounts.js';
import { closeAppearancePanel } from './appearance.js';
import { toggleCompendium } from './compendium.js';
import { closeDialog, interactNpc } from './dialogs.js';
import {
    dropInventoryItem,
    navigateInventory,
    selectInventoryItem,
    toggleInventory,
} from './inventory.js';
import { closeShop } from './shop.js';
import { closeQuestJournal, toggleQuestJournal } from './quest-journal.js';
import { closeSettings, toggleSettings } from './settings.js';

const keys = {};
const touchKeys = {};

function isKeyDown(code) {
    return !!(keys[code] || touchKeys[code]);
}
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
    'KeyL',
    'KeyP',
    'Digit1',
    'Digit2',
    'Digit3',
    'Space',
    'Escape',
    'Enter',
    'Delete',
]);

function closeActivePanel() {
    if (session.settingsOpen) closeSettings();
    else if (session.questJournalOpen) closeQuestJournal();
    else if (session.compendiumOpen) toggleCompendium();
    else if (session.shopOpen) closeShop();
    else if (session.inventoryOpen) toggleInventory();
    else if (!document.getElementById('appearancePanel').classList.contains('hidden'))
        closeAppearancePanel();
    else if (!document.getElementById('npcDialog').classList.contains('hidden')) closeDialog();
    else return false;
    return true;
}

function performInputAction(code) {
    if (!isGameActive() || session.slotMachineOpen) return;
    switch (code) {
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
            useConsumable(Number(code.slice(-1)) - 1);
            break;
        case 'KeyC':
            toggleCompendium();
            break;
        case 'KeyL':
            toggleQuestJournal();
            break;
        case 'KeyP':
            toggleSettings();
            break;
        case 'KeyE':
            if (!session.inventoryOpen && !closeActivePanel()) interactNpc();
            break;
        case 'Enter':
            if (session.inventoryOpen) selectInventoryItem();
            break;
        case 'Delete':
            if (session.inventoryOpen) dropInventoryItem();
            break;
        default:
            if (session.inventoryOpen && code.startsWith('Arrow')) navigateInventory(code);
    }
}

function handleKeyDown(event) {
    if (!isGameActive() || !GAME_KEY_CODES.has(event.code)) return;
    event.preventDefault();
    keys[event.code] = true;
    if (event.repeat && !event.code.startsWith('Arrow')) return;
    performInputAction(event.code);
}

window.addEventListener('keydown', handleKeyDown);
window.addEventListener('keyup', (event) => {
    keys[event.code] = false;
});
window.addEventListener('blur', () => {
    for (const key of Object.keys(keys)) delete keys[key];
    for (const key of Object.keys(touchKeys)) delete touchKeys[key];
});

export { keys, touchKeys, isKeyDown, performInputAction };
