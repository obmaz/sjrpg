const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { buildSite } = require('../scripts/build.cjs');
const { readPageSources } = require('../scripts/page-sources.cjs');
const { loadGame } = require('./helpers/game-harness.cjs');

test('a new release cannot reuse cached UI modules after a control is removed', async (t) => {
    const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'sjrpg-release-'));
    t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
    const sourceRoot = path.join(temporary, 'source');
    const output = path.join(temporary, 'dist');
    const repository = path.resolve(__dirname, '..');
    const { sources } = readPageSources();
    fs.mkdirSync(sourceRoot, { recursive: true });
    fs.cpSync(path.join(repository, 'assets'), path.join(sourceRoot, 'assets'), {
        recursive: true,
    });
    for (const file of [
        'index.html',
        'style.css',
        'playful-pixels.mp3',
        ...sources.map((s) => s.file),
    ]) {
        const target = path.join(sourceRoot, file);
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.copyFileSync(path.join(repository, file), target);
    }
    const htmlPath = path.join(sourceRoot, 'index.html');
    const controlsPath = path.join(sourceRoot, 'src/ui/touch-controls.js');
    const currentHtml = fs.readFileSync(htmlPath, 'utf8');
    const currentControls = fs.readFileSync(controlsPath, 'utf8');
    // Reproduce the previous deployed tracker and its event binding.
    fs.writeFileSync(
        htmlPath,
        currentHtml.replace('<body>', '<body><button id="questTracker"></button>'),
    );
    fs.writeFileSync(
        controlsPath,
        currentControls.replace(
            "touchQuests: 'KeyL',",
            "touchQuests: 'KeyL', questTracker: 'KeyL',",
        ),
    );
    const previous = buildSite(sourceRoot, output);
    fs.writeFileSync(htmlPath, currentHtml);
    const mixed = await loadGame({ projectRoot: sourceRoot, startAtTitle: true });
    assert.throws(() => mixed.documentListeners.DOMContentLoaded(), /addEventListener/);
    fs.writeFileSync(controlsPath, currentControls);
    const current = buildSite(sourceRoot, output);
    assert.notEqual(current.assetRoot, previous.assetRoot);
    const deployedHtml = fs.readFileSync(path.join(output, 'index.html'), 'utf8');
    for (const [, resource] of deployedHtml.matchAll(/(?:src|href)="([^"]+)"/g)) {
        if (resource.startsWith('#') || resource.startsWith('https:')) continue;
        assert.ok(resource.startsWith(`${current.assetRoot}/`), resource);
        assert.ok(fs.existsSync(path.join(output, resource)), resource);
    }
    for (const source of sources) {
        const file = path.join(output, current.assetRoot, source.file);
        assert.equal(fs.readFileSync(file, 'utf8'), source.source);
        for (const dependency of source.imports)
            assert.ok(fs.existsSync(path.join(output, current.assetRoot, dependency.file)));
    }
    assert.equal(buildSite(sourceRoot, output).assetRoot, current.assetRoot);
    fs.appendFileSync(path.join(sourceRoot, 'style.css'), '\n/* release change */\n');
    assert.notEqual(buildSite(sourceRoot, output).assetRoot, current.assetRoot);
});
