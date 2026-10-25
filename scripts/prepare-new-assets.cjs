const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
async function prepareNewAssets(root = path.resolve(__dirname, '..')) {
    const destination = path.join(root, 'flutter_game/assets');
    fs.mkdirSync(path.join(destination, 'images'), { recursive: true });
    const images = [
        'actors-hero',
        'actors-hero-attack',
        'actors-creatures-a',
        'actors-creatures-b',
        'actors-villagers',
        'actors-vehicles',
        'village-scene',
        'landscape-materials',
        'landscape-bridge',
        'world-forest',
        'world-desert',
        'controls',
        'ui-reference',
        'popup-frame',
        'atlas',
    ];
    for (const image of images)
        fs.copyFileSync(
            path.join(root, `assets/${image}.webp`),
            path.join(destination, `images/${image}.webp`),
        );
    for (const name of ['actors-mage', 'gear-icons', 'combat-fx', 'dodge-icon', 'actors-roll'])
        fs.copyFileSync(
            path.join(root, `flutter_game/art/${name}.png`),
            path.join(destination, `images/${name}.png`),
        );
    for (const name of [
        'actors-bicycle',
        'skill-perks',
        'skill-tablet',
        'ui-button-primary',
        'ui-button-secondary',
        'ui-button-disabled',
        'fx-meteor',
        'fx-ice-nova',
        'fx-whirlwind',
        'fx-warcry',
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
    ])
        fs.copyFileSync(
            path.join(root, `flutter_game/art/${name}.webp`),
            path.join(destination, `images/${name}.webp`),
        );
    for (const [source, target] of [
        ['hero-clean', 'actors-hero'],
        ['hero-attack-clean', 'actors-hero-attack'],
    ])
        fs.copyFileSync(
            path.join(root, `flutter_game/art/${source}.webp`),
            path.join(destination, `images/${target}.webp`),
        );
    const repaired = Object.fromEntries(
        [
            ['hero', 'hero-clean'],
            ['hero-attack', 'hero-attack-clean'],
            ['bicycle', 'actors-bicycle'],
        ].map(([key, source]) => [
            key,
            JSON.parse(
                fs.readFileSync(path.join(root, `flutter_game/art/${source}-bounds.json`), 'utf8'),
            ),
        ]),
    );
    // Remove superseded generated output when upgrading an existing asset cache.
    fs.rmSync(path.join(destination, 'images/terrain-materials.png'), { force: true });
    const mage = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/mage-bounds.json'), 'utf8'),
    );
    const roll = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/roll-bounds.json'), 'utf8'),
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
