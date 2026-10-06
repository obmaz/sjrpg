const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('touch layouts retain the entry height through address-bar changes and rotation', async () => {
    const { run, listeners } = await loadGame({ coarsePointer: true, innerHeight: 720 });
    const height = () => run("document.documentElement.style.getPropertyValue('--app-height')");
    assert.equal(height(), '720px');
    for (const nextHeight of [800, 650, 390]) {
        run(`window.innerHeight = ${nextHeight};`);
        listeners.resize();
        assert.equal(height(), '720px');
    }
});

test('a new page captures a new touch height while desktop retains responsive sizing', async () => {
    const mobile = await loadGame({ coarsePointer: true, innerHeight: 390 });
    assert.equal(
        mobile.run("document.documentElement.style.getPropertyValue('--app-height')"),
        '390px',
    );
    const { run, listeners, elements } = await loadGame({ innerHeight: 720 });
    assert.equal(run("document.documentElement.style.getPropertyValue('--app-height')"), '');
    elements.get('gameArea').clientHeight = 480;
    listeners.resize();
    assert.equal(run('canvas.height'), 480);
});

test('an unavailable entry height does not lock the layout to zero', async () => {
    const { run } = await loadGame({ coarsePointer: true, innerHeight: 0 });
    assert.equal(run("document.documentElement.style.getPropertyValue('--app-height')"), '');
});
