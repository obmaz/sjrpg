const fs = require('node:fs');
const path = require('node:path');
const espree = require('espree');

const root = path.resolve(__dirname, '..');
function readPageSources() {
    const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
    const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]);
    if (new Set(ids).size !== ids.length) throw new Error('Duplicate HTML element ID');
    const entries = [...html.matchAll(/<script\b([^>]+)>/g)]
        .map(([, attributes]) => ({
            file: attributes.match(/\bsrc="([^"]+)"/)?.[1],
            type: /\btype="module"/.test(attributes) ? 'module' : 'script',
        }))
        .filter((entry) => entry.file);
    if (new Set(entries.map((entry) => entry.file)).size !== entries.length)
        throw new Error('Duplicate script entry');
    const sources = new Map();
    function visit(file, type) {
        if (!file.startsWith('src/') || !file.endsWith('.js'))
            throw new Error(`Invalid source path: ${file}`);
        if (sources.has(file)) return;
        const source = fs.readFileSync(path.join(root, file), 'utf8');
        const ast = espree.parse(source, { ecmaVersion: 'latest', sourceType: type });
        const imports = ast.body
            .filter((node) => node.type === 'ImportDeclaration')
            .map((node) => ({
                file: path.posix.normalize(
                    path.posix.join(path.posix.dirname(file), node.source.value),
                ),
                names: node.specifiers
                    .filter((specifier) => specifier.type === 'ImportSpecifier')
                    .map((specifier) => specifier.imported.name),
            }));
        const exports = new Set(
            ast.body
                .filter((node) => node.type === 'ExportNamedDeclaration')
                .flatMap((node) => [
                    ...node.specifiers.map((specifier) => specifier.exported.name),
                    ...(node.declaration?.id ? [node.declaration.id.name] : []),
                    ...(node.declaration?.declarations?.map((declaration) => declaration.id.name) ||
                        []),
                ]),
        );
        sources.set(file, { file, source, type, imports, exports });
        for (const dependency of imports) visit(dependency.file, 'module');
    }
    for (const entry of entries) visit(entry.file, entry.type);
    for (const source of sources.values())
        for (const dependency of source.imports)
            for (const name of dependency.names) {
                if (!sources.get(dependency.file).exports.has(name))
                    throw new Error(`${source.file}: missing export ${name} in ${dependency.file}`);
            }
    const files = fs
        .readdirSync(path.join(root, 'src'), { recursive: true })
        .filter((file) => file.endsWith('.js'))
        .map((file) => `src/${file.replaceAll('\\', '/')}`);
    for (const file of files)
        if (!sources.has(file)) throw new Error(`Unreachable source: ${file}`);
    return { pageIds: new Set(ids), entries, sources: [...sources.values()] };
}
module.exports = { readPageSources };
