const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('joystick preserves all sixteen bearings and analog speed instead of eight key sectors', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(
        `initializeTouchControls();clearWorldEntities();tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));player.speed=100;`,
    );
    const stick = elements.get('touchJoystick');
    const radius = 128 * 0.36;
    stick.dispatchEvent({
        type: 'pointerdown',
        pointerId: 1,
        button: 0,
        clientX: 64,
        clientY: 64,
        preventDefault() {},
    });
    for (let i = 0; i < 16; i++) {
        const a = Math.PI / 2 + (i * Math.PI) / 8;
        run('player.x=1000;player.y=1000;');
        stick.dispatchEvent({
            type: 'pointermove',
            pointerId: 1,
            clientX: 64 + Math.cos(a) * radius,
            clientY: 64 + Math.sin(a) * radius,
            preventDefault() {},
        });
        run('updatePlayer(.1);');
        assert.ok(Math.abs(run('player.x') - 1000 - Math.cos(a) * 10) < 1e-8);
        assert.ok(Math.abs(run('player.y') - 1000 - Math.sin(a) * 10) < 1e-8);
        assert.equal(run('facingFrame(getActorAngle(player),16)'), i);
    }
    run('player.x=1000;player.y=1000;');
    stick.dispatchEvent({
        type: 'pointermove',
        pointerId: 1,
        clientX: 64 + radius * 0.6,
        clientY: 64,
        preventDefault() {},
    });
    run('updatePlayer(.1);');
    assert.ok(Math.abs(run('player.x') - 1005) < 1e-8);
    stick.dispatchEvent({ type: 'pointerup', pointerId: 1 });
    assert.equal(run('touchStick.active'), false);
    assert.equal(run('touchStick.x'), 0);
});

test('direction atlases cover every enemy and boss, with two gait images per bearing', async () => {
    const { run } = await loadGame();
    assert.equal(
        run(
            '[...ENEMY_TYPES,...DESERT_ENEMY_TYPES,...BOSS_TYPES].every(e=>!!ACTOR_SHEETS[actorArtKey(e)])',
        ),
        true,
    );
    for (const key of [
        'hero',
        'goblin',
        'wolf',
        'skeleton',
        'cultist',
        'troll',
        'golem',
        'scorpion',
        'mummy',
        'dragon',
        'demon',
        'eagle',
        'lizard',
        'slime',
        'snake',
        'pharaoh',
        'assassin',
        'merchant',
        'villager',
        'traveler',
        'stylist',
        'horse',
        'bicycle',
        'motor',
        'boat',
    ]) {
        const count = key === 'hero' ? 16 : 8;
        const frames = new Set();
        for (let phase = 0; phase < 2; phase++)
            for (let i = 0; i < count; i++) {
                const frame = run(
                    `getActorFrame('${key}',Math.PI/2+${i}*Math.PI*2/${count},${phase})`,
                );
                assert.ok(
                    run(
                        `ACTOR_BOUNDS['${frame.name}'].frames[${frame.index}].every(Number.isFinite)`,
                    ),
                );
                frames.add(`${frame.index}:${!!frame.mirror}`);
            }
        assert.equal(frames.size, count * 2, key);
    }
});

test('diagonal attacks share their actual angle with melee, projectiles and effects', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));player.x=1000;player.y=1000;setActorFacing(player,Math.PI/4);
  const front=spawnEnemy(ENEMY_TYPES[1],1040,1040);const back=spawnEnemy(ENEMY_TYPES[1],960,960);const backHp=back.hp;
  player.weapon={...WEAPONS.find(w=>w.id==='iron')};attackWithWeapon();`);
    assert.ok(run('front.hp<front.maxHp'));
    assert.equal(run('back.hp===backHp'), true);
    assert.equal(run('player.attackAngle'), Math.PI / 4);
    run(`player.weapon={...WEAPONS.find(w=>w.id==='crossbow')};attackWithWeapon();`);
    assert.ok(Math.abs(run('projectiles.at(-1).vx-projectiles.at(-1).vy')) < 1e-8);
    assert.ok(run('projectiles.at(-1).vx') > 0);
});

test('diagonal auxiliary lightning and the returning boomerang retain their casting angles', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));player.x=1000;player.y=1000;setActorFacing(player,Math.PI/4);
  const target=spawnEnemy(ENEMY_TYPES[1],1060,1060);const side=spawnEnemy(ENEMY_TYPES[1],1060,990);const sideHp=side.hp;
  player.auxWeapon={...AUX_WEAPONS.find(w=>w.id==='thunder')};useAuxWeapon();`);
    assert.ok(run('target.hp<target.maxHp'));
    assert.equal(run('side.hp===sideHp'), true);
    // Boomerang is an exported casting action; its return cannot follow later facing changes.
    run(
        `throwBoomerang(AUX_WEAPONS.find(w=>w.id==='boomerang'),getPlayerAttackOrigin());setActorFacing(player,Math.PI);updateDeferredActions(.4);`,
    );
    assert.ok(run('projectiles.at(-1).vx') < 0);
    assert.ok(run('projectiles.at(-1).vy') < 0);
});

test('hero strike poses have sixteen bearings and independent windup and follow-through frames', async () => {
    const { run } = await loadGame();
    const frames = new Set();
    for (let direction = 0; direction < 16; direction++)
        for (let phase = 0; phase < 2; phase++) {
            const frame = run(
                `getActorFrame('hero',Math.PI/2+${direction}*Math.PI/8,${phase},'attack')`,
            );
            assert.equal(frame.name, 'hero-attack');
            assert.ok(run(`ACTOR_BOUNDS['hero-attack'].frames[${frame.index}][2]`) > 0);
            frames.add(frame.index);
        }
    assert.equal(frames.size, 32);
});

test('mounts preserve their actual travel angle when the rider aims elsewhere and remounts', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));player.x=1000;player.y=1045;
  const ride=spawnMount(MOUNT_TYPES.find(m=>m.id==='horse'),1000,1000);boardMount(ride);
  setActorFacing(ride,.7);setActorFacing(player,.7);setActorFacing(player,Math.PI);dismountPlayer();`);
    assert.equal(run('getActorAngle(mounts[0])'), 0.7);
    run('player.x=mounts[0].x+mounts[0].w+1;player.y=mounts[0].y;boardMount(mounts[0]);');
    assert.equal(run('getActorAngle(player)'), 0.7);
});
