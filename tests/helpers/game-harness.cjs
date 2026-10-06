const { readPageSources } = require('../../scripts/page-sources.cjs');
const vm = require('node:vm');
const path = require('node:path');

// Link the actual page modules, with deterministic browser timers.
async function loadGame({ coarsePointer = false, innerHeight = 960 } = {}) {
    const elements = new Map();
    const listeners = {};
    const timers = [];
    let drawCount = 0;
    const context2d = new Proxy(
        {},
        {
            get: (_, name) =>
                name === 'clearRect'
                    ? () => {
                          drawCount++;
                      }
                    : name === 'createRadialGradient' || name === 'createLinearGradient'
                      ? () => ({ addColorStop() {} })
                      : () => {},
        },
    );
    function element() {
        const classes = new Set(['hidden']);
        return {
            classList: {
                add: (...names) => names.forEach((n) => classes.add(n)),
                remove: (...names) => names.forEach((n) => classes.delete(n)),
                contains: (n) => classes.has(n),
                toggle(n, force = !classes.has(n)) {
                    if (force) classes.add(n);
                    else classes.delete(n);
                },
            },
            style: {},
            children: [],
            clientWidth: 960,
            clientHeight: 640,
            getContext: () => context2d,
            get firstChild() {
                return this.children[0];
            },
            appendChild(child) {
                child.parent = this;
                this.children.push(child);
            },
            addEventListener() {},
            querySelectorAll: () => [],
            remove() {
                if (this.parent) this.parent.children.splice(this.parent.children.indexOf(this), 1);
            },
            play: () => Promise.resolve(),
            pause() {},
        };
    }
    const viewportStyles = new Map();
    const sandbox = vm.createContext({
        console,
        performance: { now: () => 0 },
        CanvasRenderingContext2D: function () {},
        window: {
            innerHeight,
            matchMedia: () => ({ matches: coarsePointer }),
            addEventListener: (name, cb) => {
                listeners[name] = cb;
            },
        },
        document: {
            readyState: 'loading',
            documentElement: {
                style: {
                    setProperty: (name, value) => viewportStyles.set(name, value),
                    getPropertyValue: (name) => viewportStyles.get(name) || '',
                },
            },
            getElementById(id) {
                if (!elements.has(id)) elements.set(id, element());
                return elements.get(id);
            },
            createElement: element,
            addEventListener() {},
        },
        requestAnimationFrame() {},
        setTimeout(cb, delay) {
            timers.push({ cb, delay });
            return timers.length;
        },
        setInterval(cb, delay) {
            timers.push({ cb, delay, interval: true });
            return timers.length;
        },
        clearInterval(id) {
            timers[id - 1].cleared = true;
        },
    });
    const page = readPageSources();
    const modules = new Map();
    for (const { file, source, type } of page.sources) {
        if (type === 'script') vm.runInContext(source, sandbox, { filename: file });
        else
            modules.set(
                file,
                new vm.SourceTextModule(source, { context: sandbox, identifier: file }),
            );
    }
    for (const entry of page.entries.filter((entry) => entry.type === 'module')) {
        const module = modules.get(entry.file);
        await module.link((specifier, referring) =>
            modules.get(
                path.posix.normalize(
                    path.posix.join(path.posix.dirname(referring.identifier), specifier),
                ),
            ),
        );
        await module.evaluate();
    }
    const productionGlobalLeaks = ['player', 'session', 'startGame', 'update', 'keys'].filter(
        (name) => Object.hasOwn(sandbox, name),
    );
    // Test-only accessors expose exports to scenario expressions; production has no globals.
    for (const module of modules.values())
        for (const name of Object.keys(module.namespace)) {
            Object.defineProperty(sandbox, name, {
                configurable: true,
                get: () => module.namespace[name],
            });
        }
    const session = modules.get('src/core/state.js').namespace.session;
    for (const name of Object.keys(session))
        Object.defineProperty(sandbox, name, {
            get: () => session[name],
            set: (value) => {
                session[name] = value;
            },
        });
    Object.defineProperty(sandbox, 'drawCount', {
        get: () => drawCount,
        set: (value) => {
            drawCount = value;
        },
    });
    const run = (code) => vm.runInContext(code, sandbox);
    run(
        'let randomSeed = 123; Math.random = () => ((randomSeed = (Math.imul(randomSeed, 1664525) + 1013904223) >>> 0) / 4294967296); gameStarted = true; generateForestMap(123);',
    );
    return { run, elements, listeners, timers, productionGlobalLeaks };
}

module.exports = { loadGame };
