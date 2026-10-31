const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
async function prepareNewAssets(root = path.resolve(__dirname, '..')) {
    const destination = path.join(root, 'flutter_game/assets');
    fs.mkdirSync(path.join(destination, 'images'), { recursive: true });
    const images = [
        'actors-villagers',
        'village-scene',
        'landscape-materials',
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
        'select-scene',
        'select-header',
        'select-warrior-card',
        'select-mage-card',
        'select-frame',
        'select-warrior-info',
        'select-mage-info',
        'select-start',
        'select-back',

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
        'cave-entrances',
        'cave-rock',
        'landscape-bridge',
        'forest-trees',
        'forest-quest-chapel',
        'forest-quest-cottage',
        'forest-quest-cave',
        'landmarks-forest',
        'landmarks-sands',
        'landmarks-past',
        'landmarks-future',
        'landmarks-tombs',
        'landmarks-foundry',
        'landmarks-convergence',
        'field-ground-meadow',
        'field-ground-desert',
        'field-ground-stone',
        'field-ground-industrial',
        'entry-loading-bar',
        'entry-ui',
        'entry-crest',
        'entry-scene',
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
        'action-glyphs',
        'barbarian-skills',
        'sorceress-skills',
        'hero-helmeted-portrait',
        'actors-bicycle',
        'skill-perks',
        'physical-icons',
        'combat-illustrations',
        'combat-actions',
        'd1-interface',
        'cinematic-interface',
        'reference-battle-buttons',
        'level-badge',
        'mount-skill-icons',
        'monster-corpses',
        'actors-walk-goblin',
        'actors-walk-wolf',
        'actors-walk-skeleton',
        'actors-walk-cultist',
        'actors-walk-troll',
        'actors-walk-golem',
        'actors-walk-scorpion',
        'actors-walk-mummy',
        'actors-walk-boar',
        'actors-walk-basilisk',
        'actors-walk-wraith',
        'actors-walk-drone',
        'actors-walk-viper',
        'actors-walk-bonehound',
        'actors-walk-clockwork-spider',
        'actors-walk-crystal-beetle',
        'actors-walk-cyber',
        'actors-walk-gunner',
        'actors-walk-sand-warden',
        'actors-walk-ancient-king',
        'actors-walk-cyber-core',
        'reference-menus',
        'village-gateway',
        'd1-warrior',
        'd1-mage',
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
            ['walk-goblin', 'actors-walk-goblin'],
            ['walk-wolf', 'actors-walk-wolf'],
            ['walk-skeleton', 'actors-walk-skeleton'],
            ['walk-cultist', 'actors-walk-cultist'],
            ['walk-troll', 'actors-walk-troll'],
            ['walk-golem', 'actors-walk-golem'],
            ['walk-scorpion', 'actors-walk-scorpion'],
            ['walk-mummy', 'actors-walk-mummy'],
            ['walk-boar', 'actors-walk-boar'],
            ['walk-basilisk', 'actors-walk-basilisk'],
            ['walk-wraith', 'actors-walk-wraith'],
            ['walk-drone', 'actors-walk-drone'],
            ['walk-viper', 'actors-walk-viper'],
            ['walk-bonehound', 'actors-walk-bonehound'],
            ['walk-clockwork-spider', 'actors-walk-clockwork-spider'],
            ['walk-crystal-beetle', 'actors-walk-crystal-beetle'],
            ['walk-cyber', 'actors-walk-cyber'],
            ['walk-gunner', 'actors-walk-gunner'],
            ['walk-sand-warden', 'actors-walk-sand-warden'],
            ['walk-ancient-king', 'actors-walk-ancient-king'],
            ['walk-cyber-core', 'actors-walk-cyber-core'],
            ['cinematic-goblin', 'actors-cinematic-goblin'],
            ['cinematic-wolf', 'actors-cinematic-wolf'],
            ['cinematic-skeleton', 'actors-cinematic-skeleton'],
            ['cinematic-cultist', 'actors-cinematic-cultist'],
            ['cinematic-troll', 'actors-cinematic-troll'],
            ['cinematic-golem', 'actors-cinematic-golem'],
            ['cinematic-scorpion', 'actors-cinematic-scorpion'],
            ['cinematic-mummy', 'actors-cinematic-mummy'],
            ['cinematic-boar', 'actors-cinematic-boar'],
            ['cinematic-basilisk', 'actors-cinematic-basilisk'],
            ['cinematic-wraith', 'actors-cinematic-wraith'],
            ['cinematic-drone', 'actors-cinematic-drone'],
            ['cinematic-viper', 'actors-cinematic-viper'],
            ['cinematic-bonehound', 'actors-cinematic-bonehound'],
            ['cinematic-clockwork-spider', 'actors-cinematic-clockwork-spider'],
            ['cinematic-crystal-beetle', 'actors-cinematic-crystal-beetle'],
            ['cinematic-cyber', 'actors-cinematic-cyber'],
            ['cinematic-gunner', 'actors-cinematic-gunner'],
            ['cinematic-sand-warden', 'actors-cinematic-sand-warden'],
            ['cinematic-ancient-king', 'actors-cinematic-ancient-king'],
            ['cinematic-cyber-core', 'actors-cinematic-cyber-core'],
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
    for (const name of [
        'actors-cinematic-goblin',
        'actors-cinematic-wolf',
        'actors-cinematic-skeleton',
        'actors-cinematic-cultist',
        'actors-cinematic-troll',
        'actors-cinematic-golem',
        'actors-cinematic-scorpion',
        'actors-cinematic-mummy',
        'actors-cinematic-boar',
        'actors-cinematic-basilisk',
        'actors-cinematic-wraith',
        'actors-cinematic-drone',
        'actors-cinematic-viper',
        'actors-cinematic-bonehound',
        'actors-cinematic-clockwork-spider',
        'actors-cinematic-crystal-beetle',
        'actors-cinematic-cyber',
        'actors-cinematic-gunner',
        'actors-cinematic-sand-warden',
        'actors-cinematic-ancient-king',
        'actors-cinematic-cyber-core',
        'actors-vehicles',
        'ui-reference',
        'popup-frame',
        'fx-whirlwind',
        'entry-splash',
        'quest-root-garden',
        'actors-creatures-a',
        'actors-creatures-b',
        'actors-boar',
        'actors-basilisk',
        'actors-wraith',
        'actors-drone',
        'actors-viper',
        'actors-bonehound',
        'actors-clockwork-spider',
        'actors-crystal-beetle',
        'actors-cyber',
        'actors-gunner',
        'actors-sand-warden',
        'actors-ancient-king',
        'actors-cyber-core',
    ]) {
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
            corpses: JSON.parse(
                fs.readFileSync(
                    path.join(root, 'flutter_game/art/monster-corpses-bounds.json'),
                    'utf8',
                ),
            ),
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
