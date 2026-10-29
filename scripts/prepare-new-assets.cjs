const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
async function prepareNewAssets(root = path.resolve(__dirname, '..')) {
    const destination = path.join(root, 'flutter_game/assets');
    fs.mkdirSync(path.join(destination, 'images'), { recursive: true });
    const images = [
        'actors-creatures-a',
        'actors-creatures-b',
        'actors-villagers',
        'village-scene',
        'landscape-materials',
        'landscape-bridge',
        'world-forest',
        'world-desert',
        'controls',
        'atlas',
    ];
    for (const image of images)
        fs.copyFileSync(
            path.join(root, `assets/${image}.webp`),
            path.join(destination, `images/${image}.webp`),
        );
    for (const name of [
        'guardian-title',
        'actors-mage',
        'actors-motor',
        'actors-horse',
        'actors-boat',
        'gear-icons',
        'combat-fx',
        'dodge-icon',
        'actors-roll',
    ])
        fs.copyFileSync(
            path.join(root, `flutter_game/art/${name}.png`),
            path.join(destination, `images/${name}.png`),
        );
    for (const name of [
        'field-ground-meadow',
        'field-ground-desert',
        'field-ground-stone',
        'field-ground-industrial',
        'entry-loading-bar',
        'entry-ui',
        'entry-crest',
        'entry-scene',
        'entry-splash',
        'class-selection',
        'blacksmith-forge',
        'village-gardens',
        'settlement-forest',
        'settlement-sands',
        'settlement-past',
        'settlement-future',
        'settlement-tombs',
        'settlement-foundry',
        'settlement-convergence',
        'village-cottage',
        'quest-root-garden',
        'action-glyphs',
        'barbarian-skills',
        'sorceress-skills',
        'hero-helmeted-portrait',
        'actors-bicycle',
        'skill-perks',
        'physical-icons',
        'combat-illustrations',
        'combat-actions',
        'actors-boar',
        'actors-basilisk',
        'actors-wraith',
        'actors-drone',
        'actors-viper',
        'actors-bonehound',
        'actors-clockwork-spider',
        'actors-crystal-beetle',
        'actors-hero-backhand',
        'actors-hero-cleave',
        'actors-mage-cast',
        'skill-tablet',
        'ui-button-primary',
        'ui-button-secondary',
        'ui-button-disabled',
        'fx-level-up',
        'fx-meteor',
        'fx-ice-nova',
        'fx-steel-whirlwind',
        'victory-crest',
        'well-portal',
        'encounter-beacons',
        'fx-warcry',
        'fx-crushing-blow',
        'passive-icons',
        'quest-sites',
        'time-sites',
        'time-paths',
        'stage-materials',
        'terrain-materials',
        'actors-cyber',
        'actors-gunner',
        'actors-sand-warden',
        'actors-ancient-king',
        'actors-cyber-core',
        'cyber-props',
        'ruin-props',
        'desert-temple',
    ])
        fs.copyFileSync(
            path.join(root, `flutter_game/art/${name}.webp`),
            path.join(destination, `images/${name}.webp`),
        );
    for (const [source, target] of [
        ['hero-helmeted', 'actors-hero'],
        ['hero-helmeted-attack', 'actors-hero-attack'],
        ['hero-helmeted-backhand', 'actors-hero-backhand'],
        ['hero-helmeted-cleave', 'actors-hero-cleave'],
    ])
        fs.copyFileSync(
            path.join(root, `flutter_game/art/${source}.webp`),
            path.join(destination, `images/${target}.webp`),
        );
    fs.copyFileSync(
        path.join(root, 'flutter_game/art/hero-helmeted-roll.png'),
        path.join(destination, 'images/actors-roll.png'),
    );
    const repaired = Object.fromEntries(
        [
            ['hero', 'hero-helmeted'],
            ['hero-attack', 'hero-helmeted-attack'],
            ['bicycle', 'actors-bicycle'],
            ['motor', 'actors-motor'],
            ['horse', 'actors-horse'],
            ['boat', 'actors-boat'],
            ['hero-backhand', 'hero-helmeted-backhand'],
            ['hero-cleave', 'hero-helmeted-cleave'],
            ['mage-cast', 'actors-mage-cast'],
            ...[
                'boar',
                'basilisk',
                'wraith',
                'drone',
                'viper',
                'bonehound',
                'clockwork-spider',
                'crystal-beetle',
            ].map((key) => [key, `actors-${key}`]),
        ].map(([key, source]) => [
            key,
            JSON.parse(
                fs.readFileSync(path.join(root, `flutter_game/art/${source}-bounds.json`), 'utf8'),
            ),
        ]),
    );
    // Remove superseded generated output when upgrading an existing asset cache.
    fs.rmSync(path.join(destination, 'images/terrain-materials.png'), { force: true });
    fs.rmSync(path.join(destination, 'images/quest-landscapes.webp'), { force: true });
    for (const name of ['actors-vehicles', 'ui-reference', 'popup-frame', 'fx-whirlwind']) {
        fs.rmSync(path.join(destination, `images/${name}.webp`), { force: true });
    }
    const mage = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/mage-bounds.json'), 'utf8'),
    );
    const roll = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/hero-helmeted-roll-bounds.json'), 'utf8'),
    );
    const cyber = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/cyber-bounds.json'), 'utf8'),
    );
    const gunner = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/gunner-bounds.json'), 'utf8'),
    );
    const sandWarden = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/sand-warden-bounds.json'), 'utf8'),
    );
    const ancientKing = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/ancient-king-bounds.json'), 'utf8'),
    );
    const cyberCore = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/cyber-core-bounds.json'), 'utf8'),
    );
    const { ACTOR_BOUNDS } = await import(
        pathToFileURL(path.join(root, 'src/data/actor-bounds.js'))
    );
    const { CONTROL_SPRITES } = await import(pathToFileURL(path.join(root, 'src/data/ui-art.js')));
    fs.writeFileSync(
        path.join(destination, 'art.json'),
        JSON.stringify({
            actors: {
                ...ACTOR_BOUNDS,
                ...repaired,
                mage,
                roll,
                cyber,
                gunner,
                'sand-warden': sandWarden,
                'ancient-king': ancientKing,
                'cyber-core': cyberCore,
            },
            controls: CONTROL_SPRITES,
        }),
    );
    console.log(
        `Prepared ${images.length} shared pictures and measured sprite bounds for Flutter.`,
    );
}
if (require.main === module)
    prepareNewAssets().catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
module.exports = { prepareNewAssets };
