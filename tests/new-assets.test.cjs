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
    for (const name of ['actors-vehicles', 'ui-reference', 'popup-frame', 'fx-whirlwind']) {
        fs.writeFileSync(path.join(target, `${name}.webp`), 'obsolete runtime copy');
    }
    await prepareNewAssets(root);
    assert.equal(fs.existsSync(path.join(target, 'terrain-materials.png')), false);
    for (const name of ['actors-vehicles', 'ui-reference', 'popup-frame', 'fx-whirlwind']) {
        assert.equal(fs.existsSync(path.join(target, `${name}.webp`)), false);
        const original = name === 'fx-whirlwind' ? 'flutter_game/art' : 'assets';
        assert.equal(fs.existsSync(path.join(root, original, `${name}.webp`)), true);
    }
    assert.equal(
        fs.readFileSync(path.join(target, 'terrain-materials.webp'), 'utf8'),
        'source picture terrain-materials.webp',
    );
    assert.equal(
        fs.readFileSync(path.join(target, 'village-scene.webp'), 'utf8'),
        'source picture village-scene.webp',
    );
    for (const name of [
        'field-ground-meadow',
        'field-ground-desert',
        'field-ground-stone',
        'field-ground-industrial',
        'entry-scene',
        'entry-splash',
        'class-selection',
        'entry-ui',
        'entry-crest',
        'entry-loading-bar',
    ]) {
        assert.equal(
            fs.readFileSync(path.join(target, `${name}.webp`), 'utf8'),
            `source picture ${name}.webp`,
        );
    }
    assert.equal(
        fs.readFileSync(path.join(target, 'blacksmith-forge.webp'), 'utf8'),
        'source picture blacksmith-forge.webp',
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
        ['hero', 144],
        ['mage', 144],
        ['hero-attack', 128],
        ['hero-backhand', 128],
        ['hero-cleave', 128],
        ['mage-cast', 128],
        ['roll', 64],
        ['bicycle', 16],
        ['viper', 16],
        ['bonehound', 16],
        ['clockwork-spider', 16],
        ['crystal-beetle', 16],
    ]) {
        assert.equal(metadata.actors[actor].frames.length, count);
    }
    for (const [actor, source] of [
        ['hero', 'hero-helmeted'],
        ['mage', 'mage'],
        ['hero-attack', 'hero-helmeted-attack'],
        ['hero-backhand', 'hero-helmeted-backhand'],
        ['hero-cleave', 'hero-helmeted-cleave'],
        ['mage-cast', 'actors-mage-cast'],
        ['roll', 'hero-helmeted-roll'],
    ]) {
        const original = JSON.parse(
            fs.readFileSync(path.join(root, `flutter_game/art/${source}-bounds.json`), 'utf8'),
        );
        assert.deepEqual(metadata.actors[actor], original, `${actor} retains projected anchors`);
        assert.equal(metadata.actors[actor].anchorMode, 'projected-origin');
        assert.equal(metadata.actors[actor].feet.length, metadata.actors[actor].frames.length);
    }
    for (const [targetName, sourceName] of [
        ['actors-hero.webp', 'hero-helmeted.webp'],
        ['actors-hero-attack.webp', 'hero-helmeted-attack.webp'],
        ['actors-hero-backhand.webp', 'hero-helmeted-backhand.webp'],
        ['actors-hero-cleave.webp', 'hero-helmeted-cleave.webp'],
        ['actors-roll.png', 'hero-helmeted-roll.png'],
        ['hero-helmeted-portrait.webp', 'hero-helmeted-portrait.webp'],
    ]) {
        assert.equal(
            fs.readFileSync(path.join(target, targetName), 'utf8'),
            `source picture ${sourceName}`,
            'active warrior runtime aliases must use helmeted artwork',
        );
    }
    for (const actor of ['hero', 'mage']) {
        assert.deepEqual(metadata.actors[actor].motion, {
            directions: 16,
            runFrames: 8,
            idleOffset: 0,
            runOffset: 16,
            layout: 'phase-major',
        });
    }
    assert.deepEqual(metadata.controls.attack, [1, 2, 3, 4]);
    for (const actor of ['hero-attack', 'hero-backhand', 'hero-cleave', 'mage-cast']) {
        assert.deepEqual(metadata.actors[actor].action, {
            directions: 16,
            frames: 8,
            layout: 'phase-major',
        });
        assert.equal(
            new Set(metadata.actors[actor].frames.map((frame) => JSON.stringify(frame))).size,
            128,
        );
    }
    assert.equal(metadata.actors.gunner.frames.length, 16);
    assert.equal(metadata.actors.cyber.frames.length, 16);
    assert.equal(metadata.actors.viper.feet.length, 16);
    for (const actor of ['bonehound', 'clockwork-spider', 'crystal-beetle']) {
        assert.equal(metadata.actors[actor].feet.length, 16);
        assert.equal(
            fs.readFileSync(path.join(target, `actors-${actor}.webp`), 'utf8'),
            `source picture actors-${actor}.webp`,
        );
    }
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
    for (const name of ['actors-vehicles', 'ui-reference', 'popup-frame', 'fx-whirlwind']) {
        assert.equal(fs.existsSync(path.join(target, `${name}.webp`)), false);
        const original = name === 'fx-whirlwind' ? 'flutter_game/art' : 'assets';
        assert.equal(fs.existsSync(path.join(root, original, `${name}.webp`)), true);
    }
    assert.equal(
        fs.readFileSync(path.join(target, 'terrain-materials.webp'), 'utf8'),
        'source picture terrain-materials.webp',
    );
});
