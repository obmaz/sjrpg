const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('rendering fountain and fog never creates particles or consumes gameplay randomness', async () => {
    const { run } = await loadGame();
    run(`updateCamera(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);
        player.hp = 50; player.gold = 100; player.visionReduction = 10;
        particles.push({x: player.x, y: player.y, vx: 1, vy: 1,
            life: 0.4, maxLife: 0.5, color: '#fff', size: 2});
        Math.random = () => { throw new Error('render consumed gameplay randomness'); };`);
    const before = run('JSON.stringify(particles)');
    for (const state of [
        'session.gamePaused = true',
        'session.gamePaused = false; session.inventoryOpen = true',
        'session.inventoryOpen = false; session.gameOver = true',
        'session.gameOver = false; session.gameVictory = true',
    ]) {
        run(`${state}; for (let i = 0; i < 30; i++) draw();`);
        assert.equal(run('JSON.stringify(particles)'), before, state);
    }
});

test('environmental emission density follows game time across 30, 60 and 120 FPS', async () => {
    for (const fps of [10, 30, 60, 120]) {
        const { run } = await loadGame();
        run(`updateCamera(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);
            player.hp = 50; player.gold = 100; player.visionReduction = 10;
            Math.random = () => 0.1;
            for (let i = 0; i < ${fps}; i++) emitEnvironmentalParticles(1 / ${fps});`);
        assert.equal(run('particles.length'), 240, `${fps} FPS`);
        assert.equal(run("particles.filter(p => p.color === '#88ccff').length"), 120);
        assert.equal(run("particles.filter(p => p.color === '#ffaa66').length"), 60);
        assert.equal(run("particles.filter(p => p.color === '#334466').length"), 60);
    }
});

test('environmental emissions stop for paused, inventory and terminal simulations', async () => {
    const { run } = await loadGame();
    run(`updateCamera(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);
        Math.random = () => 0.1; update(1 / 60);`);
    assert.ok(run('particles.length') > 0);
    const before = run('JSON.stringify(particles)');
    for (const state of [
        'session.gamePaused = true',
        'session.gamePaused = false; session.inventoryOpen = true',
        'session.inventoryOpen = false; session.gameOver = true',
        'session.gameOver = false; session.gameVictory = true',
    ]) {
        run(`${state}; update(0.1); emitEnvironmentalParticles(0.1);`);
        assert.equal(run('JSON.stringify(particles)'), before, state);
    }
});

test('HUD displays poison together with speed and removes each status independently', async () => {
    const { run, elements } = await loadGame();
    run('player.speedBoost = 10; player.poisonTimer = 240; updateHud();');
    const status = elements.get('poisonDisplay');
    assert.match(status.textContent, /스피드 10\.0s/);
    assert.match(status.textContent, /독 4:00/);
    assert.equal(elements.get('hudCenter').style.display, 'flex');
    run('player.speedBoost = 0; updateHud();');
    assert.equal(status.textContent, '☠️ 독 4:00');
    assert.equal(status.style.display, 'block');
    run('player.poisonTimer = 0; updateHud();');
    assert.equal(status.style.display, 'none');
    assert.equal(elements.get('hudCenter').style.display, 'none');
});

test('unchanged HUD output skips content, style and class mutations', async () => {
    const { run, elements } = await loadGame();
    run('updateHud();');
    let mutations = 0;
    const countAssignments = (target, property) => {
        let value = target[property];
        Object.defineProperty(target, property, {
            configurable: true,
            get: () => value,
            set(next) {
                mutations++;
                value = next;
            },
        });
    };
    for (const element of elements.values()) {
        for (const property of ['innerHTML', 'textContent']) countAssignments(element, property);
        for (const property of Object.keys(element.style))
            countAssignments(element.style, property);
        const toggle = element.classList.toggle.bind(element.classList);
        element.classList.toggle = (...args) => {
            mutations++;
            return toggle(...args);
        };
    }
    run('for (let i = 0; i < 10; i++) updateHud();');
    assert.equal(mutations, 0);
    run('player.gold++; updateHud();');
    assert.equal(mutations, 1);
    assert.equal(elements.get('goldDisplay').textContent, '1');
});

test('HUD can restore the same auxiliary weapon after showing an empty slot', async () => {
    const { run, elements } = await loadGame();
    run('player.auxWeapon = {...AUX_WEAPONS[0]}; updateHud();');
    const auxiliary = elements.get('auxDisplay');
    let htmlWrites = 0;
    Object.defineProperty(auxiliary, 'innerHTML', {
        configurable: true,
        get: () => '',
        set() {
            htmlWrites++;
        },
    });
    run(
        'player.auxWeapon = null; updateHud(); player.auxWeapon = {...AUX_WEAPONS[0]}; updateHud();',
    );
    assert.equal(htmlWrites, 1);
});

test('enemy labels stay quiet until combat while bosses always identify themselves', async () => {
    const { run } = await loadGame();
    run(`camera.x=0; camera.y=0;
        const shownLabels=[];
        ctx.fillText=text=>shownLabels.push(text);
        const shownEnemy={x:100,y:100,w:24,h:24,hp:20,maxHp:20,
            name:'고블린',level:2,state:'wander',hurtTimer:0,frozen:0,animTimer:0,color:'#789'};
        enemies.push(shownEnemy);
        drawEntity(shownEnemy);`);
    assert.equal(run('shownLabels.includes("고블린 Lv2")'), false);
    for (const state of [
        'shownEnemy.hp=19',
        'shownEnemy.hp=20; shownEnemy.state="attack"',
        'shownEnemy.state="wander"; shownEnemy.hurtTimer=0.1',
        'shownEnemy.hurtTimer=0; shownEnemy.isBoss=true',
    ]) {
        run(`shownLabels.length=0; ${state}; drawEntity(shownEnemy);`);
        assert.equal(run('shownLabels.includes("고블린 Lv2")'), true, state);
    }
    for (const isBoss of [false, true]) {
        run(`shownEnemy.isBoss=${isBoss}; shownEnemy.hp=20; floatingTexts.length=0;
            damageEnemy(shownEnemy,3,false);`);
        assert.equal(run('shownEnemy.hp'), 17);
        assert.equal(run('floatingTexts[0].kind'), 'damage');
        assert.ok(run(`floatingTexts[0].y <= shownEnemy.y - ${isBoss ? 48 : 32}`));
    }
});

test('depth sorting and world framing never reorder enemies or mutate combat state', async () => {
    const { run } = await loadGame();
    run(`enemies.length=0; npcs.length=0; camera.x=0; camera.y=0;
        player.x=100; player.y=100; player.hp=20;
        const actorTemplate={x:100,w:24,h:24,hp:20,maxHp:20,
            state:'attack',hurtTimer:0,frozen:0,animTimer:0,color:'#789'};
        enemies.push({...actorTemplate,y:150,name:'앞'}, {...actorTemplate,y:50,name:'뒤'});
        npcs.push({x:150,y:75,w:24,h:28,name:'주민',icon:'NPC_DEPTH',quests:[]});
        const actorLabels=[]; ctx.fillText=text=>actorLabels.push(text);
        Math.random=()=>{throw new Error('render consumed gameplay randomness')};`);
    const before = run(
        'JSON.stringify({player,enemies,npcs,chests,mounts,floatingTexts,particles})',
    );
    run('draw();');
    assert.ok(run('actorLabels.indexOf("뒤") < actorLabels.indexOf("NPC_DEPTH")'));
    assert.ok(run('actorLabels.indexOf("NPC_DEPTH") < actorLabels.indexOf("앞")'));
    for (const paused of [true, false]) {
        run(`session.gamePaused=${paused}; for(let i=0;i<5;i++) draw();`);
        assert.equal(
            run('JSON.stringify({player,enemies,npcs,chests,mounts,floatingTexts,particles})'),
            before,
        );
    }
});

test('reduced motion removes damage number scaling without changing the event', async () => {
    for (const reducedMotion of [false, true]) {
        const { run } = await loadGame({ reducedMotion });
        run(`spawnFloatingText(100,100,'-12','#f00','damage');
            const damageFonts=[];
            ctx.fillText=()=>damageFonts.push(ctx.font);
            drawFloatingTexts();`);
        assert.equal(
            run('damageFonts[0]'),
            reducedMotion ? 'bold 16px sans-serif' : 'bold 20px sans-serif',
        );
        assert.equal(run('floatingTexts[0].life'), 1);
        assert.equal(run('floatingTexts[0].text'), '-12');
    }
});

test('painted hero portrait preserves chosen appearance and low-health feedback', async () => {
    const { run, elements } = await loadGame();
    run('updateHud();');
    const face = elements.get('portraitFace');
    assert.equal(face.classList.contains('painted-portrait'), true);
    run("player.playerFace='😎'; updateHud();");
    assert.equal(face.classList.contains('painted-portrait'), false);
    assert.equal(face.textContent, '😎');
    run("player.playerFace='😊'; player.hp=10; updateHud();");
    assert.equal(face.classList.contains('painted-portrait'), false);
    assert.equal(face.textContent, '🤕');
    run('player.hp=100; updateHud();');
    assert.equal(face.classList.contains('painted-portrait'), true);
});

test('nearby NPC actions use one compact world tag without a second canvas action label', async () => {
    for (const coarsePointer of [false, true]) {
        const { run, elements } = await loadGame({ coarsePointer });
        run(`npcs.length=0;portals.length=0;player.x=500;player.y=570;
            npcs.push({x:500,y:500,w:64,h:64,name:'상인',icon:'🏪',isShop:true,quests:[]});
            const actionTexts=[];ctx.fillText=text=>actionTexts.push(text);
            initializeTouchControls();drawNpcs();`);
        assert.equal(elements.get('touchInteractLabel').textContent, '상점');
        assert.equal(
            elements.get('worldInteract').getAttribute('data-label'),
            coarsePointer ? '상점' : 'E · 상점',
        );
        assert.equal(
            run(
                'actionTexts.some(text=>String(text).includes("상점")||String(text).includes("터치"))',
            ),
            false,
        );
    }
});

test('forest cover follows map replacement and terrain destruction without mutating the world or RNG', async () => {
    const { run } = await loadGame();
    run(`tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));
        for(let y=10;y<=14;y++)for(let x=10;x<=14;x++)tileMap[y][x]=TILE_KEYS.indexOf('TREE');
        Math.random=()=>{throw Error('forest view consumed gameplay RNG')};`);
    assert.equal(run('getForestTile(12,12).dense'), true);
    assert.equal(run('getForestTile(12,11).mask & 4'), 4);
    run("tileMap[12][12]=TILE_KEYS.indexOf('DIRT');session.terrainRevision++;");
    const before = run('JSON.stringify(tileMap)');
    assert.equal(run('getForestTile(12,12).dense'), false);
    assert.equal(run('getForestTile(12,11).mask & 4'), 0);
    assert.equal(run('JSON.stringify(tileMap)'), before);
    run(
        "tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));",
    );
    assert.equal(run('getForestTile(12,12).dense'), false);
});

test('each primary weapon renders a distinct attack without changing gameplay state', async () => {
    const { run } = await loadGame();
    run(`const strokes=[];ctx.arc=(...a)=>strokes.push(['arc',...a]);ctx.lineTo=(...a)=>strokes.push(['line',...a]);ctx.bezierCurveTo=(...a)=>strokes.push(['curve',...a]);
        const traces=[];const weaponBefore=JSON.stringify(WEAPONS);
        Math.random=()=>{throw new Error('drawing must not use randomness')};
        for(const weapon of WEAPONS){
            strokes.length=0;player.weapon=weapon;player.attackVisual={...weapon};player.attackSerial=1;
            player.lastAttackCooldown=weapon.cooldown;player.attackTimer=weapon.cooldown-.08;
            const before=JSON.stringify(player);drawWeaponAttack(ctx,player,0,0);
            if(JSON.stringify(player)!==before)throw new Error('drawing mutated player');
            traces.push(JSON.stringify(strokes));
        }`);
    assert.equal(run('new Set(traces).size'), 16);
    assert.equal(run('JSON.stringify(WEAPONS)===weaponBefore'), true);
});

test('last-use attacks retain their own visual and ranged projectiles retain weapon identity', async () => {
    const { run } = await loadGame();
    run(
        `clearWorldEntities();player.weapon={...WEAPONS.find(w=>w.id==='legend'),uses:1};attackWithWeapon();`,
    );
    assert.equal(run('player.weapon.id'), 'fist');
    assert.equal(run('player.attackVisual.id'), 'legend');
    assert.equal(run('projectiles[0].weaponId'), 'legend');
    for (const id of ['crossbow', 'staff', 'sandstorm']) {
        run(`player.weapon={...WEAPONS.find(w=>w.id==='${id}')};attackWithWeapon();`);
        assert.equal(run('projectiles.at(-1).weaponId'), id);
    }
    assert.equal(run('enemyWorldArt({name:"고대 드래곤",artIndex:null})'), 'ancientDragon');
});

test('large minimap terrain is cached between frames and refreshed after terrain edits', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();const minimap=document.getElementById('minimap');minimap.width=100;minimap.height=100;
   let mapPaints=0;ctx.fillRect=()=>mapPaints++;drawMinimap();const initialPaints=mapPaints;
   mapPaints=0;drawMinimap();const repeatedPaints=mapPaints;
   tileMap[0][0]=TILE_KEYS.indexOf('SAND');session.terrainRevision++;mapPaints=0;drawMinimap();`);
    assert.ok(run('initialPaints') > 1000);
    assert.ok(run('repeatedPaints') < 10);
    assert.ok(run('mapPaints') > 1000);
});
