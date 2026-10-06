const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

// The HTML is the runtime manifest. Both static checks and tests consume it.
function readPageSources() {
    const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
    const scriptPaths = [...html.matchAll(/<script src="([^"]+)"/g)].map((match) => match[1]);
    if (new Set(scriptPaths).size !== scriptPaths.length)
        throw new Error('Duplicate script in index.html');
    const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]);
    if (new Set(ids).size !== ids.length) throw new Error('Duplicate HTML element ID');
    const sourceFiles = fs
        .readdirSync(path.join(root, 'src'), { recursive: true })
        .filter((file) => file.endsWith('.js'))
        .map((file) => `src/${file.replaceAll('\\', '/')}`);
    for (const file of sourceFiles) {
        if (!scriptPaths.includes(file)) throw new Error(`Unloaded source file: ${file}`);
    }
    return {
        pageIds: new Set(ids),
        sources: scriptPaths.map((file) => ({
            file,
            source: fs.readFileSync(path.join(root, file), 'utf8'),
        })),
    };
}

module.exports = { readPageSources };
