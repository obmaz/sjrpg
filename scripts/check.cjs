const vm = require('node:vm');
const { Linter } = require('eslint');
const globals = require('globals');
const { readPageSources } = require('./page-sources.cjs');

const { sources: pageSources, pageIds } = readPageSources();
const sources = [];
const locations = [];
let lineOffset = 0;

for (const { file, source } of pageSources) {
    new vm.Script(source, { filename: file });
    for (const [, id] of source.matchAll(/getElementById\(['"]([^'"]+)['"]\)/g)) {
        if (!pageIds.has(id)) throw new Error(`${file}: missing HTML element #${id}`);
    }
    locations.push({ file, lineOffset });
    sources.push(source);
    lineOffset += source.split('\n').length;
}

const messages = new Linter().verify(sources.join('\n'), [
    {
        languageOptions: { sourceType: 'script', globals: globals.browser },
        rules: {
            'no-undef': 'error',
            'no-unused-vars': ['error', { args: 'none' }],
            eqeqeq: ['error', 'always', { null: 'ignore' }],
            'no-var': 'error',
            'prefer-const': 'error',
            'no-unreachable': 'error',
            'no-dupe-keys': 'error',
            'no-constant-condition': 'error',
        },
    },
]);

for (const message of messages) {
    const location = locations.findLast((item) => message.line > item.lineOffset);
    console.error(
        `${location.file}:${message.line - location.lineOffset}:${message.column} ${message.message}`,
    );
}
if (messages.length) process.exitCode = 1;
else console.log(`Checked ${pageSources.length} browser scripts in page load order.`);
