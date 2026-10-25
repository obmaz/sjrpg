const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

test('install prompt captured before Flutter stays available, installs once and records cancellation', async () => {
    const window = new EventTarget(),
        document = new EventTarget(),
        attributes = new Map();
    document.documentElement = { setAttribute: (k, v) => attributes.set(k, v) };
    vm.runInNewContext(
        fs.readFileSync(path.resolve(__dirname, '../flutter_game/web/install.js'), 'utf8'),
        {
            window,
            document,
            navigator: {},
            Event,
            matchMedia: () => ({ matches: false }),
        },
    );
    let prompts = 0,
        choose;
    const event = new Event('beforeinstallprompt', { cancelable: true });
    event.prompt = async () => {
        prompts++;
    };
    event.userChoice = new Promise((resolve) => {
        choose = resolve;
    });
    window.dispatchEvent(event);
    assert.equal(event.defaultPrevented, true);
    assert.equal(attributes.get('data-install-ready'), 'true');
    document.dispatchEvent(new Event('guardian-install-request'));
    document.dispatchEvent(new Event('guardian-install-request'));
    assert.equal(prompts, 1);
    choose({ outcome: 'dismissed' });
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(attributes.get('data-install-result'), 'dismissed');
    assert.equal(attributes.get('data-install-ready'), 'false');
    window.dispatchEvent(new Event('appinstalled'));
    assert.equal(attributes.get('data-app-installed'), 'true');
});
