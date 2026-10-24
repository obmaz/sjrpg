const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('mobile action buttons follow equipment, limited uses and cooldown recovery', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run('initializeTouchControls();');
    assert.equal(elements.get('touchAuxStatus').textContent, '미획득');
    assert.equal(elements.get('touchAux').disabled, true);
    run(`player.weapon={...WEAPONS.find(w => w.id === 'axe')};
        player.auxWeapon={...AUX_WEAPONS.find(w => w.id === 'shield')};
        player.auxWeapons=[player.auxWeapon]; player.auxCooldown=4; updateTouchControls();`);
    assert.equal(elements.get('touchAttackIcon').textContent, '🪓');
    assert.match(elements.get('touchAttack').getAttribute('aria-label'), /전투 도끼/);
    assert.equal(elements.get('touchAuxIcon').textContent, '🛡️');
    assert.equal(elements.get('touchAuxStatus').textContent, '4초');
    assert.equal(elements.get('touchAuxCount').textContent, '∞');
    assert.equal(elements.get('touchAuxRing').style.strokeDashoffset, '50');
    assert.equal(elements.get('touchAux').disabled, true);
    run('player.auxCooldown=0; updateTouchControls();');
    assert.equal(elements.get('touchAuxStatus').textContent, '보조');
    assert.equal(elements.get('touchAuxRing').style.strokeDashoffset, '0');
    assert.equal(elements.get('touchAux').disabled, false);
    run(`player.auxWeapon={...AUX_WEAPONS.find(w => w.id === 'healpot'), uses: 2};
        player.auxWeapons=[player.auxWeapon]; updateTouchControls();`);
    elements.get('touchAux').dispatchEvent({ type: 'click' });
    assert.equal(elements.get('touchAuxCount').textContent, '1');
    elements.get('touchAux').dispatchEvent({ type: 'click' });
    assert.equal(elements.get('touchAuxStatus').textContent, '미획득');
    assert.equal(elements.get('touchAuxCount').textContent, '');
    assert.equal(elements.get('touchAux').disabled, true);
});

test('the objective tracker opens the journal and updates progress for the current region', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(`initializeTouchControls(); player.completedQuests=[MAIN_QUESTS[0]]; updateHud();
        touchKeys.Space=true;`);
    assert.equal(elements.get('regionBadge').textContent, '푸른 숲');
    assert.match(elements.get('clearProgress').textContent, /1 \/ 3/);
    assert.ok(parseFloat(elements.get('questProgressFill').style.width) > 33);
    elements.get('questTracker').dispatchEvent({ type: 'click' });
    assert.equal(run('session.questJournalOpen && session.gamePaused'), true);
    assert.equal(run('isKeyDown("Space")'), false);
    elements.get('closeQuestJournal').dispatchEvent({ type: 'click' });
    run('player.currentRegion="desert"; player.completedQuests=[...DESERT_QUESTS]; updateHud();');
    assert.equal(elements.get('regionBadge').textContent, '황금 사막');
    assert.equal(elements.get('questProgressFill').style.width, '100%');
});

test('interaction feedback matches the nearest NPC and preserves portal priority at the range boundary', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(`initializeTouchControls(); npcs.length=0; portals.length=0;
        player.x=500; player.y=500;
        npcs.push({x:550,y:500,w:player.w,h:player.h,name:'상인',isShop:true});
        updateTouchControls();`);
    const button = elements.get('touchInteract');
    assert.equal(button.disabled, true, 'exactly 50px is outside interaction range');
    run('npcs[0].x=549; updateTouchControls();');
    assert.equal(button.disabled, false);
    assert.equal(button.classList.contains('ready'), true);
    assert.equal(elements.get('touchInteractLabel').textContent, '상점');
    button.dispatchEvent({ type: 'click' });
    assert.equal(run('session.shopOpen && session.gamePaused'), true);
    assert.equal(button.disabled, true, 'paused controls cannot show an active target');
    elements.get('closeShop').dispatchEvent({ type: 'click' });
    run(`npcs.push({x:500,y:500,w:player.w,h:player.h,name:'마을 주민',icon:'🙂',
        dialog:'반갑습니다',quests:[]}); updateTouchControls();`);
    assert.equal(elements.get('touchInteractLabel').textContent, '대화');
    assert.match(button.getAttribute('aria-label'), /마을 주민/);
    button.dispatchEvent({ type: 'click' });
    assert.equal(elements.get('npcName').textContent, '마을 주민');
    elements.get('closeNpcDialog').dispatchEvent({ type: 'click' });
    run('portals.push({x:549,y:500,w:player.w,h:player.h}); updateTouchControls();');
    assert.equal(elements.get('touchInteractLabel').textContent, '이동');
    assert.equal(elements.get('touchInteractSymbol').getAttribute('href'), '#icon-compass');
    button.dispatchEvent({ type: 'click' });
    assert.equal(elements.get('npcName').textContent, '차원 포탈');
    assert.equal(
        run('player.currentRegion'),
        'forest',
        'portal interaction still asks before travel',
    );
    elements.get('closeNpcDialog').dispatchEvent({ type: 'click' });
    run('npcs.length=0; portals.length=0; updateTouchControls();');
    assert.equal(button.disabled, true);
    assert.equal(button.classList.contains('ready'), false);
});

test('inventory summary and capacity follow equipping and discarding weapons', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(`inventory.length=0;
        inventory.push({...WEAPONS.find(w => w.id === 'iron')}, {...WEAPONS.find(w => w.id === 'axe')});
        toggleInventory();`);
    assert.equal(elements.get('inventoryCount').textContent, '2/12');
    assert.match(elements.get('equippedSummary').innerHTML, /맨손/);
    elements.get('inventorySlots').children[0].dispatchEvent({ type: 'click' });
    assert.match(elements.get('equippedSummary').innerHTML, /철검/);
    assert.equal(elements.get('inventoryCount').textContent, '1/12');
    run('dropInventoryItem(0);');
    assert.equal(elements.get('inventoryCount').textContent, '0/12');
    assert.match(elements.get('equippedSummary').innerHTML, /철검/);
});
