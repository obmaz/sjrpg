const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = readFileSync(path.join(__dirname, '../flutter_game/web/index.html'), 'utf8');
const hostScript = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
    .map((match) => match[1])
    .find((source) => source.includes('flutter-host') && source.includes('fullscreenchange'));
assert.ok(hostScript, 'exercise the actual Flutter host script');

function loadHost({ coarse = true, width = 844, height = 390, orientation = true } = {}) {
    const host = { style: {} };
    const documentListeners = new Map();
    const windowListeners = new Map();
    const orientationListeners = new Map();
    const animationFrames = [];
    const dispatched = [];
    let loadingRemovals = 0;
    const context = {
        innerWidth: width,
        innerHeight: height,
        matchMedia: () => ({ matches: coarse }),
        screen: orientation
            ? {
                  orientation: {
                      addEventListener: (name, callback) =>
                          orientationListeners.set(name, callback),
                  },
              }
            : {},
        requestAnimationFrame: (callback) => animationFrames.push(callback),
        Event: class {
            constructor(type) {
                this.type = type;
            }
        },
        document: {
            hidden: false,
            fullscreenElement: null,
            getElementById: (id) => {
                if (id === 'flutter-host') return host;
                assert.equal(id, 'loading');
                return { remove: () => loadingRemovals++ };
            },
            addEventListener: (name, callback, options) =>
                documentListeners.set(name, { callback, options }),
        },
        addEventListener: (name, callback) => windowListeners.set(name, callback),
        dispatchEvent: (event) => dispatched.push(event.type),
    };
    context.window = context;
    vm.runInNewContext(hostScript, context, { filename: 'flutter-host-inline.js' });
    return {
        host,
        context,
        dispatched,
        documentListeners,
        windowListeners,
        orientationListeners,
        loadingRemovals: () => loadingRemovals,
        documentEvent: (name) => documentListeners.get(name)?.callback(),
        resize(nextWidth, nextHeight) {
            context.innerWidth = nextWidth;
            context.innerHeight = nextHeight;
            windowListeners.get('resize')?.();
        },
        rotate(nextWidth, nextHeight) {
            context.innerWidth = nextWidth;
            context.innerHeight = nextHeight;
            orientationListeners.get('change')?.();
            while (animationFrames.length) animationFrames.shift()();
        },
    };
}

test('coarse pointer retains its entry height through address-bar height-only resizes', () => {
    const h = loadHost({ width: 390, height: 844 });
    assert.equal(h.host.style.height, '844px');
    for (const height of [780, 720, 890, 844]) {
        h.resize(390, height);
        assert.equal(h.host.style.height, '844px');
    }
});

test('coarse pointer width changes rebaseline landscape and portrait in both directions', () => {
    const h = loadHost();
    assert.equal(h.host.style.height, '390px');
    h.resize(390, 844);
    assert.equal(h.host.style.height, '844px');
    h.resize(390, 760);
    assert.equal(h.host.style.height, '844px');
    h.resize(844, 390);
    assert.equal(h.host.style.height, '390px');
});

test('screen orientation events rebaseline even without a separate resize event', () => {
    const h = loadHost();
    assert.ok(h.orientationListeners.has('change'));
    h.rotate(390, 844);
    assert.equal(h.host.style.height, '844px');
    h.rotate(844, 390);
    assert.equal(h.host.style.height, '390px');
});

test('fullscreen fills dynamic height and exit preserves the same-width entry baseline', () => {
    const h = loadHost({ width: 390, height: 844 });
    h.context.document.fullscreenElement = {};
    h.documentEvent('fullscreenchange');
    assert.equal(h.host.style.height, '100dvh');
    h.resize(390, 920);
    assert.equal(h.host.style.height, '100dvh');
    h.context.document.fullscreenElement = null;
    h.documentEvent('fullscreenchange');
    assert.equal(h.host.style.height, '844px');
});

test('rotation during fullscreen rebaselines on exit without adopting later address-bar heights', () => {
    const h = loadHost();
    h.context.document.fullscreenElement = {};
    h.documentEvent('fullscreenchange');
    h.rotate(390, 844);
    assert.equal(h.host.style.height, '100dvh');
    h.context.document.fullscreenElement = null;
    h.documentEvent('fullscreenchange');
    assert.equal(h.host.style.height, '844px');
    h.resize(390, 740);
    assert.equal(h.host.style.height, '844px');
});

test('desktop remains responsive through resize, orientation and fullscreen exit', () => {
    const h = loadHost({ coarse: false });
    assert.equal(h.host.style.height, '100%');
    h.resize(390, 844);
    assert.equal(h.host.style.height, '100%');
    h.context.document.fullscreenElement = {};
    h.documentEvent('fullscreenchange');
    assert.equal(h.host.style.height, '100dvh');
    h.rotate(844, 390);
    h.context.document.fullscreenElement = null;
    h.documentEvent('fullscreenchange');
    assert.equal(h.host.style.height, '100%');
});

test('missing screen orientation API still allows resize-based rebaseline', () => {
    const h = loadHost({ orientation: false });
    h.resize(390, 844);
    assert.equal(h.host.style.height, '844px');
});

test('host retains double-tap zoom prevention, background blur and loading removal hooks', () => {
    const h = loadHost();
    let prevented = 0;
    const doubleClick = h.documentListeners.get('dblclick');
    doubleClick.callback({ preventDefault: () => prevented++ });
    assert.equal(prevented, 1);
    assert.equal(doubleClick.options.passive, false);
    h.documentEvent('visibilitychange');
    assert.deepEqual(h.dispatched, []);
    h.context.document.hidden = true;
    h.documentEvent('visibilitychange');
    assert.deepEqual(h.dispatched, ['blur']);
    h.windowListeners.get('flutter-first-frame')();
    assert.equal(h.loadingRemovals(), 1);
});
