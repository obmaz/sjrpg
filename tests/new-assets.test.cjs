const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { prepareNewAssets } = require('../scripts/prepare-new-assets.cjs');

test('upgrading a prepared Flutter asset cache replaces the old ground PNG without retaining its payload', async (t) => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sjrpg-new-assets-'));
    t.after(() => fs.rmSync(root, { recursive: true, force: true }));
    const repository = path.resolve(__dirname, '..');
    for (const directory of [
        'assets',
        'flutter_game/art',
        'src/data',
        'flutter_game/assets/images',
    ])
        fs.mkdirSync(path.join(root, directory), { recursive: true });
    for (const directory of ['assets', 'flutter_game/art']) {
        for (const name of fs.readdirSync(path.join(repository, directory))) {
            if (/\.(png|webp)$/.test(name))
                fs.writeFileSync(path.join(root, directory, name), `source picture ${name}`);
            else if (directory === 'flutter_game/art' && name.endsWith('.json'))
                fs.copyFileSync(
                    path.join(repository, directory, name),
                    path.join(root, directory, name),
                );
        }
    }
    fs.writeFileSync(path.join(root, 'package.json'), '{"type":"module"}');
    fs.writeFileSync(
        path.join(root, 'src/data/actor-bounds.js'),
        'export const ACTOR_BOUNDS = { shared: { frames: [[1, 2, 3, 4]] } };',
    );
    fs.writeFileSync(
        path.join(root, 'src/data/ui-art.js'),
        'export const CONTROL_SPRITES = { attack: [1, 2, 3, 4] };',
    );
    const target = path.join(root, 'flutter_game/assets/images');
    fs.writeFileSync(path.join(target, 'terrain-materials.png'), 'obsolete large PNG');
    fs.writeFileSync(path.join(target, 'retained.webp'), 'unrelated prepared asset');
    await prepareNewAssets(root);
    assert.equal(fs.existsSync(path.join(target, 'terrain-materials.png')), false);
    assert.equal(
        fs.readFileSync(path.join(target, 'terrain-materials.webp'), 'utf8'),
        'source picture terrain-materials.webp',
    );
    assert.equal(
        fs.readFileSync(path.join(target, 'village-scene.webp'), 'utf8'),
        'source picture village-scene.webp',
    );
    assert.equal(
        fs.readFileSync(path.join(target, 'retained.webp'), 'utf8'),
        'unrelated prepared asset',
    );
    assert.equal(
        fs.readFileSync(path.join(target, 'time-paths.webp'), 'utf8'),
        'source picture time-paths.webp',
    );
    assert.equal(
        fs.readFileSync(path.join(target, 'well-portal.webp'), 'utf8'),
        'source picture well-portal.webp',
    );
    const metadata = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/assets/art.json'), 'utf8'),
    );
    assert.deepEqual(metadata.actors.shared.frames, [[1, 2, 3, 4]]);
    for (const [actor, count] of [
        ['hero', 32],
        ['hero-attack', 32],
        ['bicycle', 16],
        ['viper', 16],
    ]) {
        assert.equal(metadata.actors[actor].frames.length, count);
    }
    assert.equal(metadata.actors.hero.feet.length, 32);
    assert.deepEqual(metadata.controls.attack, [1, 2, 3, 4]);
    assert.equal(metadata.actors.gunner.frames.length, 16);
    assert.equal(metadata.actors.cyber.frames.length, 16);
    assert.equal(metadata.actors.viper.feet.length, 16);
    assert.equal(
        fs.readFileSync(path.join(target, 'actors-viper.webp'), 'utf8'),
        'source picture actors-viper.webp',
    );
    for (const actor of ['sand-warden', 'ancient-king', 'cyber-core']) {
        assert.equal(metadata.actors[actor].frames.length, 16);
        assert.equal(
            fs.readFileSync(path.join(target, `actors-${actor}.webp`), 'utf8'),
            `source picture actors-${actor}.webp`,
        );
    }
    await prepareNewAssets(root);
    assert.equal(fs.existsSync(path.join(target, 'terrain-materials.png')), false);
    assert.equal(
        fs.readFileSync(path.join(target, 'terrain-materials.webp'), 'utf8'),
        'source picture terrain-materials.webp',
    );
});
