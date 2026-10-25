const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { buildAll } = require('../scripts/build-all.cjs');
const { buildSite } = require('../scripts/build.cjs');
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
    fs.writeFileSync(path.join(compiled, 'main.dart.js'), 'fallback engine');
    fs.writeFileSync(path.join(compiled, 'main.dart.wasm'), 'wasm engine');
    fs.writeFileSync(path.join(compiled, 'main.dart.mjs'), 'wasm loader');
    const legacyCache = path.join(temporary, 'legacy');
    buildSite(path.resolve(__dirname, '..'), legacyCache);
    fs.writeFileSync(path.join(compiled, 'flutter_bootstrap.js'), 'bootstrap');
    fs.writeFileSync(path.join(compiled, 'assets', 'art.json'), '{}');
    const first = buildAll(path.resolve(__dirname, '..'), output, compiled, legacyCache);
    assert.match(fs.readFileSync(path.join(output, 'index.html'), 'utf8'), /href="legacy\/"/);
    assert.match(
        fs.readFileSync(path.join(output, 'index.html'), 'utf8'),
        /href="new\/\?v=[a-f0-9]+"/,
    );
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
    fs.writeFileSync(path.join(compiled, 'main.dart.wasm'), 'wasm engine update');
    const second = buildAll(path.resolve(__dirname, '..'), output, compiled, legacyCache);
    assert.notEqual(first.version, second.version);
    assert.ok(
        fs
            .readFileSync(path.join(output, 'index.html'), 'utf8')
            .includes(`new/?v=${second.version}`),
    );
    assert.equal(
        fs.readFileSync(
            path.join(output, 'new/releases', second.version, 'main.dart.wasm'),
            'utf8',
        ),
        'wasm engine update',
    );
    fs.rmSync(path.join(compiled, 'main.dart.wasm'));
    assert.throws(
        () => buildAll(path.resolve(__dirname, '..'), output, compiled, legacyCache),
        /Build Flutter first/,
    );
    assert.equal(fs.readFileSync(path.join(output, 'legacy/index.html'), 'utf8'), legacy);
    assert.equal(first.legacy.assetRoot, second.legacy.assetRoot);
    assert.equal(fs.readFileSync(path.join(output, 'legacy/index.html'), 'utf8'), legacy);
});
test('assembly succeeds with only prepared artifacts and no Legacy source tree', (t) => {
    const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'sjrpg-artifacts-'));
    t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
    const compiled = path.join(temporary, 'flutter'),
        legacy = path.join(temporary, 'legacy');
    fs.mkdirSync(path.join(temporary, 'site'));
    fs.writeFileSync(
        path.join(temporary, 'site/index.html'),
        '<a href="new/">New</a><a href="legacy/">Legacy</a>{{legacyAssets}}',
    );
    fs.mkdirSync(compiled);
    fs.writeFileSync(path.join(compiled, 'index.html'), '<base href="/sjrpg/new/">');
    for (const extension of ['wasm', 'mjs', 'js'])
        fs.writeFileSync(path.join(compiled, `main.dart.${extension}`), extension);
    const assetRoot = 'assets/0123456789abcdef0123';
    fs.mkdirSync(path.join(legacy, assetRoot), { recursive: true });
    fs.writeFileSync(
        path.join(legacy, 'index.html'),
        `<script src="${assetRoot}/game.js"></script>`,
    );
    fs.writeFileSync(path.join(legacy, assetRoot, 'game.js'), 'preserved deployed Legacy');
    const output = path.join(temporary, 'dist');
    buildAll(temporary, output, compiled, legacy);
    assert.equal(fs.existsSync(path.join(temporary, 'src')), false);
    assert.equal(
        fs.readFileSync(path.join(output, 'legacy', assetRoot, 'game.js'), 'utf8'),
        'preserved deployed Legacy',
    );
});
