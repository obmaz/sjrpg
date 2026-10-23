const fs = require('node:fs');
const path = require('node:path');
const { readPageSources } = require('./page-sources.cjs');

const projectRoot = path.resolve(__dirname, '..');
const destination = path.join(projectRoot, 'dist');
const { sources } = readPageSources();
const files = [
    'index.html',
    'style.css',
    'playful-pixels.mp3',
    ...sources.map((source) => source.file),
];
for (const file of files) fs.accessSync(path.join(projectRoot, file), fs.constants.R_OK);
fs.rmSync(destination, { recursive: true, force: true });
for (const file of files) {
    const target = path.join(destination, file);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(path.join(projectRoot, file), target);
}
fs.writeFileSync(path.join(destination, '.nojekyll'), '');
console.log(`Built ${files.length} static files in dist/ with relative module paths.`);
