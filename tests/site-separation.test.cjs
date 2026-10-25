const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { buildAll } = require('../scripts/build-all.cjs');
test('both games deploy independently and Flutter assets use a versioned base below /new/', (t) => {
    const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'sjrpg-dual-'));
    t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
    const compiled = path.join(temporary, 'web'),
        output = path.join(temporary, 'dist');
    fs.mkdirSync(path.join(compiled, 'assets'), { recursive: true });
    fs.writeFileSync(
        path.join(compiled, 'index.html'),
        '<base href="/sjrpg/new/"><script src="flutter_bootstrap.js"></script>',
    );
    fs.writeFileSync(path.join(compiled, 'main.dart.js'), 'new engine');
    fs.writeFileSync(path.join(compiled, 'flutter_bootstrap.js'), 'bootstrap');
    fs.writeFileSync(path.join(compiled, 'assets', 'art.json'), '{}');
    const first = buildAll(path.resolve(__dirname, '..'), output, compiled);
    assert.match(fs.readFileSync(path.join(output, 'index.html'), 'utf8'), /href="legacy\/"/);
    assert.match(fs.readFileSync(path.join(output, 'index.html'), 'utf8'), /href="new\/"/);
    const legacy = fs.readFileSync(path.join(output, 'legacy/index.html'), 'utf8');
    assert.ok(legacy.includes(`${first.legacy.assetRoot}/src/game.js`));
    const current = fs.readFileSync(path.join(output, 'new/index.html'), 'utf8');
    assert.ok(current.includes(`/sjrpg/new/releases/${first.version}/`));
    assert.equal(
        fs.readFileSync(
            path.join(output, 'new/releases', first.version, 'assets/art.json'),
            'utf8',
        ),
        '{}',
    );
    fs.writeFileSync(path.join(compiled, 'main.dart.js'), 'new engine update');
    const second = buildAll(path.resolve(__dirname, '..'), output, compiled);
    assert.notEqual(first.version, second.version);
    assert.equal(first.legacy.assetRoot, second.legacy.assetRoot);
    assert.equal(fs.readFileSync(path.join(output, 'legacy/index.html'), 'utf8'), legacy);
});
