const { Linter } = require('eslint');
const globals = require('globals');
const { readPageSources } = require('./page-sources.cjs');

const { sources, pageIds } = readPageSources();
let failures = 0;
for (const { file, source, type } of sources) {
    for (const [, id] of source.matchAll(/getElementById\(['"]([^'"]+)['"]\)/g)) {
        if (!pageIds.has(id)) throw new Error(`${file}: missing HTML element #${id}`);
    }
    const messages = new Linter().verify(source, [
        {
            languageOptions: { sourceType: type, globals: globals.browser },
            rules: {
                'no-undef': 'error',
                'no-unused-vars': ['error', { args: 'none' }],
                eqeqeq: ['error', 'always', { null: 'ignore' }],
                'no-var': 'error',
                'prefer-const': 'error',
                'no-unreachable': 'error',
                'no-dupe-keys': 'error',
                'no-constant-condition': 'error',
                'no-import-assign': 'error',
            },
        },
    ]);
    for (const message of messages)
        console.error(`${file}:${message.line}:${message.column} ${message.message}`);
    failures += messages.length;
}
if (failures) process.exitCode = 1;
else console.log(`Checked ${sources.length} sources and their module import/export graph.`);
