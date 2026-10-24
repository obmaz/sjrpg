const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('enemy hits and empty attacks keep damage feedback without message bubbles', async () => {
    const { run, elements } = await loadGame();
    run(`spawnEnemy(DESERT_ENEMY_TYPES.find(e => e.poison), player.x + 15, player.y);
        enemies[0].x=player.x+15; enemies[0].y=player.y; updateEnemies(0.01);`);
    assert.ok(run('player.hp') < 100);
    assert.ok(run('floatingTexts.length') > 0);
    assert.equal(elements.get('eventBubbles').children.length, 0);
    run('enemies.length=0; player.attackTimer=0; attackWithWeapon();');
    assert.equal(elements.get('eventBubbles').children.length, 0);
});

test('gold and weapon pickups create short lived bubbles without a history panel', async () => {
    const { run, elements, timers } = await loadGame();
    run(`goldPickups.length=0; spawnGoldPickup(player.x, player.y, 25);
        updateGoldPickups(0);`);
    const bubbles = elements.get('eventBubbles');
    assert.equal(run('player.gold'), 25);
    assert.match(bubbles.children.at(-1).textContent, /25 골드/);
    run(`spawnWeaponPickup(player.x,player.y,WEAPONS.find(w=>w.id==='iron'));
        updateWeaponPickups(0);`);
    assert.match(bubbles.children.at(-1).textContent, /철검 획득/);
    run('addMessage("추가 획득", "loot");');
    assert.equal(bubbles.children.length, 2);
    timers.filter((t) => t.delay === 2200).forEach((t) => t.cb());
    assert.equal(bubbles.children.length, 0);
});

test('bubbles track the player and camera and remain inside the visible viewport', async () => {
    const { run, elements } = await loadGame();
    run(`document.getElementById('gameArea').getBoundingClientRect=()=>({left:0,top:0,width:960,height:640});
        window.innerWidth=390; window.innerHeight=844; canvas.width=960;
        player.x=200; player.y=400; camera.x=0; camera.y=0; addMessage('획득', 'loot');`);
    const bubbles = elements.get('eventBubbles');
    assert.equal(bubbles.style.left, '212px');
    assert.equal(bubbles.style.top, '374px');
    run('camera.x=20; updateEventBubbles();');
    assert.equal(bubbles.style.left, '192px');
    run(`window.visualViewport={width:320,height:480,offsetLeft:0,offsetTop:10};
        player.x=-100; player.y=-100; updateEventBubbles();`);
    assert.ok(parseFloat(bubbles.style.left) >= 152);
    assert.ok(parseFloat(bubbles.style.top) >= 160);
});
