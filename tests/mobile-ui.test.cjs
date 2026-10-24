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
