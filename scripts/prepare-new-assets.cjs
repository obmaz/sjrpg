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
    for (const name of [
        'actors-mage',
        'gear-icons',
        'combat-fx',
        'dodge-icon',
        'actors-roll',
        'terrain-materials',
    ])
        fs.copyFileSync(
            path.join(root, `flutter_game/art/${name}.png`),
            path.join(destination, `images/${name}.png`),
        );
    for (const name of ['fx-meteor', 'fx-ice-nova'])
        fs.copyFileSync(
            path.join(root, `flutter_game/art/${name}.webp`),
            path.join(destination, `images/${name}.webp`),
        );
    const mage = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/mage-bounds.json'), 'utf8'),
    );
    const roll = JSON.parse(
        fs.readFileSync(path.join(root, 'flutter_game/art/roll-bounds.json'), 'utf8'),
    );
    const { ACTOR_BOUNDS } = await import(
        pathToFileURL(path.join(root, 'src/data/actor-bounds.js'))
    );
    const { CONTROL_SPRITES } = await import(pathToFileURL(path.join(root, 'src/data/ui-art.js')));
    fs.writeFileSync(
        path.join(destination, 'art.json'),
        JSON.stringify({ actors: { ...ACTOR_BOUNDS, mage, roll }, controls: CONTROL_SPRITES }),
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
