const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('a consumable bomb deals its advertised damage once without a lingering damage zone', async () => {
    const { run } = await loadGame();
    run(`const target = {x: player.x, y: player.y, w: 20, h: 20, hp: 1000};
        enemies.push(target);
        player.items.push({...ITEMS.find(item => item.id === 'bomb')});
        useConsumable(0);`);
    assert.equal(run('target.hp'), 970);
    assert.equal(run('player.items.length'), 0);
    assert.equal(run('fireZones.length'), 0);
    run('for (let i = 0; i < 10; i++) updateFireZones(0.1);');
    assert.equal(run('target.hp'), 970);
});

test('a firebomb deals 25 explosion damage and up to 30 further damage inside its smaller burn area', async () => {
    const { run } = await loadGame();
    run(`const origin = getPlayerAttackOrigin();
        const nearby = {x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 1000};
        const outer = {x: origin.x + 65, y: origin.y - 10, w: 20, h: 20, hp: 1000};
        enemies.push(nearby, outer);
        player.auxWeapon = {...AUX_WEAPONS.find(weapon => weapon.id === 'firebomb')};
        player.auxWeapons.push(player.auxWeapon);
        useAuxWeapon();`);
    assert.equal(run('nearby.hp'), 975);
    assert.equal(run('outer.hp'), 975);
    assert.equal(run('player.auxWeapon.uses'), 2);
    run('for (let i = 0; i < 20; i++) updateFireZones(0.1);');
    assert.equal(run('nearby.hp'), 945);
    assert.equal(run('outer.hp'), 975);
    assert.equal(run('fireZones.length'), 0);
});

test('a reusable trap hits and immobilizes one enemy once, then disappears', async () => {
    const { run } = await loadGame();
    run(`player.auxWeapon = {...AUX_WEAPONS.find(weapon => weapon.id === 'trap')};
        player.auxWeapons.push(player.auxWeapon);
        useAuxWeapon();
        const zone = fireZones[0];
        const first = {x: zone.x - 10, y: zone.y - 10, w: 20, h: 20, hp: 1000};
        const second = {...first};
        enemies.push(first, second);
        updateFireZones(0.1);`);
    assert.equal(run('first.hp'), 982);
    assert.equal(run('first.frozen'), 1);
    assert.equal(run('second.hp'), 1000);
    assert.equal(run('fireZones.length'), 0);
    assert.equal(run('player.auxWeapon.uses'), -1);
    assert.equal(run('player.auxCooldown'), 4);
    run('for (let i = 0; i < 80; i++) updateFireZones(0.1);');
    assert.equal(run('first.hp'), 982);
});

test('an untriggered trap expires and cannot damage a later arrival', async () => {
    const { run } = await loadGame();
    run(`player.auxWeapon = {...AUX_WEAPONS.find(weapon => weapon.id === 'trap')};
        player.auxWeapons.push(player.auxWeapon);
        useAuxWeapon();
        const position = {x: fireZones[0].x - 10, y: fireZones[0].y - 10};
        for (let i = 0; i < 81; i++) updateFireZones(0.1);
        const target = {...position, w: 20, h: 20, hp: 1000};
        enemies.push(target);
        updateFireZones(0.1);`);
    assert.equal(run('target.hp'), 1000);
    assert.equal(run('fireZones.length'), 0);
});

test('scorpion poison adds exactly four damage ticks and stops on expiration', async () => {
    const { run } = await loadGame();
    run(`Math.random = () => 0;
        player.weapon = {...WEAPONS.find(weapon => weapon.id === 'scorpion')};
        const origin = getPlayerAttackOrigin();
        const target = {x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 1000};
        enemies.push(target);
        attackWithWeapon();`);
    assert.equal(run('target.hp'), 980);
    run('for (let i = 0; i < 40; i++) updateEnemyPoisons(0.1);');
    assert.equal(run('target.hp'), 964);
    run('for (let i = 0; i < 40; i++) updateEnemyPoisons(0.1);');
    assert.equal(run('target.hp'), 964);
});

test('reapplying scorpion poison refreshes duration without delaying the next damage tick', async () => {
    const { run } = await loadGame();
    run(`Math.random = () => 0;
        player.weapon = {...WEAPONS.find(weapon => weapon.id === 'scorpion')};
        const origin = getPlayerAttackOrigin();
        const target = {x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 1000};
        enemies.push(target);
        attackWithWeapon();
        updateEnemyPoisons(0.5);
        attackWithWeapon();`);
    assert.equal(run('target.hp'), 960);
    assert.equal(run('target.enemyPoison.remaining'), 4);
    run('updateEnemyPoisons(0.5);');
    assert.equal(run('target.hp'), 956);
});
