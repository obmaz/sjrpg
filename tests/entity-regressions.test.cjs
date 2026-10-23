const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('damage over time preserves enemy actions and does not reset recoil or knockback', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();
        const target = {x:500,y:500,w:24,h:24,hp:100,maxHp:100,state:'ranged',stateTimer:2,knockbackX:0,knockbackY:0};
        enemies.push(target); spawnFireZone(512,512,1,8,40); updateFireZones(0.4);`);
    assert.equal(run('target.hp'), 92);
    assert.equal(run('target.state'), 'ranged');
    assert.equal(run('target.stateTimer'), 2);
    assert.equal(run('target.knockbackX'), 0);
    assert.equal(run('target.knockbackY'), 0);
});

test('damage zones stop ticking at expiry even when the frame crosses a tick boundary', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();
        const target = {x:500,y:500,w:24,h:24,hp:100,maxHp:100,state:'wander'};
        enemies.push(target); spawnFireZone(512,512,0.39,10,40); updateFireZones(0.4);`);
    assert.equal(run('target.hp'), 100);
    assert.equal(run('fireZones.length'), 0);
    run('spawnFireZone(512,512,0.4,10,40); updateFireZones(0.4);');
    assert.equal(run('target.hp'), 90);
    assert.equal(run('fireZones.length'), 0);
});

test('projectile range limits travel even across its final partial frame', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();
        tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        const target = {x:420,y:495,w:20,h:20,hp:100}; enemies.push(target);
        spawnProjectile(100,500,3,500,20,'#fff','x',1,300);
        for(let i=0;i<7;i++)updateProjectiles(0.1);`);
    assert.equal(run('target.hp'), 100);
    assert.equal(run('projectiles.length'), 0);
    run(
        'spawnProjectile(100,500,3,500,20,"#fff","x",1,350); for(let i=0;i<7;i++)updateProjectiles(0.1);',
    );
    assert.equal(run('target.hp'), 80);
});

test('winning grades depend on completion time rather than the final gold reward', async () => {
    for (const [remaining, grade] of [
        [300, 'S'],
        [180, 'A'],
        [60, 'B'],
        [1, 'C'],
    ]) {
        const { run, elements } = await loadGame();
        run(`player.currentRegion='desert'; player.gold=10000; player.gameTime=${remaining};
            triggerVictory('complete');`);
        assert.match(elements.get('victoryGrade').innerHTML, new RegExp(`>${grade}<`));
        assert.match(elements.get('victoryStats').innerHTML, /보유 골드/);
    }
});
