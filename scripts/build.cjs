const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { readPageSources } = require('./page-sources.cjs');

function buildSite(
    projectRoot = path.resolve(__dirname, '..'),
    destination = path.join(projectRoot, 'dist'),
) {
    const { sources } = readPageSources(projectRoot);
    const files = [
        'index.html',
        'style.css',
        'playful-pixels.mp3',
        ...fs
            .readdirSync(path.join(projectRoot, 'assets'))
            .filter((file) => file.endsWith('.webp'))
            .map((file) => `assets/${file}`),
        ...sources.map((source) => source.file),
    ];
    const contents = new Map(
        files.map((file) => [file, fs.readFileSync(path.join(projectRoot, file))]),
    );
    const hash = createHash('sha256');
    for (const [file, content] of contents) hash.update(file).update('\0').update(content);
    const assetRoot = `assets/${hash.digest('hex').slice(0, 20)}`;
    fs.rmSync(destination, { recursive: true, force: true });
    for (const file of files) {
        const target = path.join(
            destination,
            file === 'index.html' ? file : `${assetRoot}/${file}`,
        );
        fs.mkdirSync(path.dirname(target), { recursive: true });
        const content =
            file === 'index.html'
                ? contents
                      .get(file)
                      .toString()
                      .replace(/\b(src|href)="([^"]+)"/g, (match, attribute, resource) =>
                          contents.has(resource)
                              ? `${attribute}="${assetRoot}/${resource}"`
                              : match,
                      )
                : contents.get(file);
        fs.writeFileSync(target, content);
    }
    fs.writeFileSync(path.join(destination, '.nojekyll'), '');
    return { assetRoot, files };
}

if (require.main === module) {
    const result = buildSite(undefined, path.resolve(__dirname, '../dist/legacy'));
    console.log(
        `Built ${result.files.length} static files under ${result.assetRoot} with relative module paths.`,
    );
}
module.exports = { buildSite };
