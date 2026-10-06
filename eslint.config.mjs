import globals from 'globals';

export default [
    {
        files: ['tests/**/*.cjs', 'scripts/**/*.cjs', 'eslint.config.mjs'],
        languageOptions: { globals: globals.node },
        rules: {
            'no-undef': 'error',
            'no-unused-vars': ['error', { args: 'none' }],
            eqeqeq: ['error', 'always', { null: 'ignore' }],
            'no-var': 'error',
            'prefer-const': 'error',
        },
    },
];
