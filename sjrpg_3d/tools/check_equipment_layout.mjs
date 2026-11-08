#!/usr/bin/env node
// Capture the actual default (unexpanded) inventory and shop at both phone orientations.
import {execFileSync} from 'node:child_process';
import {mkdirSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
const base = process.argv[2] ?? 'http://127.0.0.1:8779/';
const out = resolve(process.argv[3] ?? 'build/review/equipment');
mkdirSync(out, {recursive:true});
for (const [scene, cls, viewport] of [
    ['bag', 'warrior', '390x844'],
    ['bag', 'mage', '1280x720'],
    ['shop', 'mage', '390x844'],
    ['shop', 'warrior', '1280x720'],
]) {
    const name = `${scene}-${cls}-${viewport}`;
    const file = resolve(out, name + '.jpg');
    execFileSync(process.execPath, ['sjrpg_3d/tools/screenshot.mjs',
        '--scene', scene, '--class', cls, '--device', 'phone',
        '--viewport', viewport, '--dpr', '1', '--url', base, '--out', file,
        '--settle', '1500', '--capture-timeout', '90000'],
        {stdio:'inherit', timeout:240000});
    const b64 = readFileSync(file).toString('base64');
    for (let i = 0; i < b64.length; i += 4000)
        console.log('EQUIPMENT_IMAGE ' + name + ' ' + i + ' ' + b64.slice(i, i + 4000));
}
