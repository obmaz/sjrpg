const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('Delete frees a full inventory slot without changing the equipped weapon', async () => {
    const { run, listeners } = await loadGame();
    run(`player.weapon = {...WEAPONS.find(weapon => weapon.id === 'iron')};
        for (let i = 0; i < INVENTORY_CAPACITY; i++)
            inventory.push({...WEAPONS.find(weapon => weapon.id === 'dagger')});
        toggleInventory(); selectedInventoryIndex = 11;`);

    listeners.keydown({ code: 'Delete', preventDefault() {} });

    assert.equal(run('inventory.length'), 11);
    assert.equal(run('player.weapon.id'), 'iron');
    assert.equal(run('weaponPickups.length'), 1);
    assert.equal(run('weaponPickups[0].weapon.id'), 'dagger');
    assert.equal(run('weaponPickups[0].life'), 120);
    assert.equal(run('selectedInventoryIndex'), 10);

    listeners.keydown({ code: 'Delete', repeat: true, preventDefault() {} });
    assert.equal(run('inventory.length'), 11);
});

test('discarded weapons retain their remaining uses and can be collected after the delay', async () => {
    const { run } = await loadGame();
    const originalUses = run("WEAPONS.find(weapon => weapon.id === 'legend').uses");
    run(`inventory.push({...WEAPONS.find(weapon => weapon.id === 'legend'), uses: 1});
        toggleInventory(); dropInventoryItem(); toggleInventory();
        updateWeaponPickups(0.1);`);

    assert.equal(run('inventory.length'), 0);
    assert.equal(run('weaponPickups[0].weapon.uses'), 1);
    assert.equal(run("WEAPONS.find(weapon => weapon.id === 'legend').uses"), originalUses);

    run('updateWeaponPickups(1);');
    assert.equal(run('inventory.length'), 1);
    assert.equal(run('inventory[0].uses'), 1);
    assert.equal(run('weaponPickups.length'), 0);
});

test('dropping a common weapon lets the player collect a new weapon from a full inventory', async () => {
    const { run } = await loadGame();
    run(`player.weapon = {...WEAPONS.find(weapon => weapon.id === 'iron')};
        for (let i = 0; i < INVENTORY_CAPACITY; i++)
            inventory.push({...WEAPONS.find(weapon => weapon.id === 'dagger')});
        spawnWeaponPickup(player.x + player.w / 2, player.y + player.h / 2,
            WEAPONS.find(weapon => weapon.id === 'legend'));
        toggleInventory(); dropInventoryItem(); toggleInventory(); updateWeaponPickups(0.1);`);

    assert.equal(run('inventory.length'), 12);
    assert.equal(run("inventory.filter(weapon => weapon.id === 'legend').length"), 1);
    assert.equal(run('weaponPickups.length'), 1);
    assert.equal(run('weaponPickups[0].weapon.id'), 'dagger');
});

test('discarding weapons requires an open inventory and ignores invalid selections', async () => {
    const { run, listeners } = await loadGame();
    run("inventory.push({...WEAPONS.find(weapon => weapon.id === 'iron')});");
    listeners.keydown({ code: 'Delete', preventDefault() {} });
    run('dropInventoryItem();');
    assert.equal(run('inventory.length'), 1);

    run('toggleInventory(); dropInventoryItem(-1); dropInventoryItem(1.5); dropInventoryItem(12);');
    assert.equal(run('inventory.length'), 1);
    assert.equal(run('weaponPickups.length'), 0);

    for (const inactiveState of ['gamePaused', 'gameOver', 'gameVictory']) {
        run(`${inactiveState} = true; dropInventoryItem(); ${inactiveState} = false;`);
        assert.equal(run('inventory.length'), 1, inactiveState);
    }
});

test('inventory shows remaining uses and a discard button that does not equip the weapon', async () => {
    const { run, elements } = await loadGame();
    run(`const originalCreateElement = document.createElement;
        document.createElement = (...args) => {
            const created = originalCreateElement(...args);
            created.listeners = {};
            created.addEventListener = (name, callback) => { created.listeners[name] = callback; };
            return created;
        };
        inventory.push({...WEAPONS.find(weapon => weapon.id === 'legend'), uses: 1});
        toggleInventory();`);

    const slot = elements.get('inventorySlots').children[0];
    assert.ok(slot.innerHTML.includes('남은 1회'));
    const button = slot.children.find((child) => child.className === 'inventory-drop');
    assert.ok(button);
    let stopped = false;
    button.listeners.click({
        stopPropagation() {
            stopped = true;
        },
    });
    assert.equal(stopped, true);
    assert.equal(run('inventory.length'), 0);
    assert.equal(run('player.weapon.id'), 'fist');
    assert.equal(run('weaponPickups[0].weapon.id'), 'legend');
});
