const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { describeSite } = require('../scripts/build.cjs');
const { prepareLegacy } = require('../scripts/prepare-legacy.cjs');
const root = path.resolve(__dirname, '..');
test('unchanged Legacy is restored byte-for-byte, reused from cache and repaired if corrupted', async (t) => {
    const destination = fs.mkdtempSync(path.join(os.tmpdir(), 'legacy-restore-'));
    t.after(() => fs.rmSync(destination, { recursive: true, force: true }));
    const plan = describeSite(root);
    let requests = 0;
    const fetcher = async (url) => {
        requests++;
        const file = url.pathname.replace('/sjrpg/legacy/', '');
        return new Response(plan.rendered.get(file), { status: 200 });
    };
    const first = await prepareLegacy(root, destination, { fetcher });
    assert.equal(first.source, 'published');
    for (const [file, content] of plan.rendered)
        assert.deepEqual(fs.readFileSync(path.join(destination, file)), content);
    const downloaded = requests;
    assert.equal((await prepareLegacy(root, destination, { fetcher })).source, 'cache');
    assert.equal(requests, downloaded);
    fs.writeFileSync(path.join(destination, plan.assetRoot, 'src/game.js'), 'corrupt');
    assert.equal((await prepareLegacy(root, destination, { fetcher })).source, 'published');
});
test('an outdated published Legacy entry triggers its independent local build', async (t) => {
    const destination = fs.mkdtempSync(path.join(os.tmpdir(), 'legacy-changed-'));
    t.after(() => fs.rmSync(destination, { recursive: true, force: true }));
    let requests = 0;
    const result = await prepareLegacy(root, destination, {
        fetcher: async () => {
            requests++;
            return new Response('old version');
        },
    });
    assert.equal(result.source, 'built');
    assert.equal(requests, 1);
    assert.equal(result.assetRoot, describeSite(root).assetRoot);
});
