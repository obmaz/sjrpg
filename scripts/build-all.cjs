const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
function filesUnder(directory) {
    return fs
        .readdirSync(directory, { withFileTypes: true })
        .flatMap((entry) => {
            const file = path.join(directory, entry.name);
            return entry.isDirectory() ? filesUnder(file) : [file];
        })
        .sort();
}
function buildAll(
    root = path.resolve(__dirname, '..'),
    destination = path.join(root, 'dist'),
    flutterOutput = path.join(root, 'flutter_game/build/web'),
    legacyOutput = path.join(root, '.build-cache/legacy'),
) {
    if (
        !['main.dart.wasm', 'main.dart.mjs', 'main.dart.js'].every((file) =>
            fs.existsSync(path.join(flutterOutput, file)),
        )
    )
        throw new Error(
            'Build Flutter first: cd flutter_game && flutter build web --wasm --release --base-href /sjrpg/new/ --no-web-resources-cdn',
        );
    const legacyIndex = path.join(legacyOutput, 'index.html');
    if (!fs.existsSync(legacyIndex))
        throw new Error('Prepare Legacy independently first: npm run prepare:legacy');
    const legacyHtml = fs.readFileSync(legacyIndex, 'utf8');
    const assetRoot = legacyHtml.match(/(?:src|href)="(assets\/[a-f0-9]{20})\//)?.[1];
    if (!assetRoot) throw new Error('Prepared Legacy has no versioned asset root');
    const compiled = filesUnder(flutterOutput);
    const hash = createHash('sha256');
    for (const file of compiled)
        hash.update(path.relative(flutterOutput, file)).update('\0').update(fs.readFileSync(file));
    const version = hash.digest('hex').slice(0, 20);
    fs.rmSync(destination, { recursive: true, force: true });
    const legacy = { assetRoot };
    fs.cpSync(legacyOutput, path.join(destination, 'legacy'), { recursive: true });
    const newRoot = path.join(destination, 'new'),
        release = path.join(newRoot, 'releases', version);
    fs.mkdirSync(release, { recursive: true });
    fs.cpSync(flutterOutput, release, { recursive: true });
    const index = fs
        .readFileSync(path.join(flutterOutput, 'index.html'), 'utf8')
        .replace(/<base href="[^"]*">/, `<base href="/sjrpg/new/releases/${version}/">`);
    fs.writeFileSync(path.join(newRoot, 'index.html'), index);
    const portal = fs
        .readFileSync(path.join(root, 'site/index.html'), 'utf8')
        .replaceAll('{{legacyAssets}}', `legacy/${legacy.assetRoot}/assets`);
    fs.writeFileSync(path.join(destination, 'index.html'), portal);
    fs.writeFileSync(path.join(destination, '.nojekyll'), '');
    return { legacy, version, files: filesUnder(destination).length };
}
if (require.main === module) {
    const result = buildAll();
    console.log(`Assembled ${result.files} files: /legacy/ and /new/ (Flutter ${result.version}).`);
}
module.exports = { buildAll };
