'use strict';

// ============================================================
//  SLOT MACHINE
// ============================================================
const SLOT_SYMBOLS = ['💰', '💸', '👁️', '☠️', '🌀', '💎'];

function useSlotMachine() {
    if (!isGameActive() || gamePaused || inventoryOpen || slotMachineOpen) return;
    if (player.gold < 50) {
        addMessage('🎰 골드가 부족합니다! (50💰 필요)', 'damage');
        return;
    }
    player.gold -= 50;
    updateHud();

    const outcomes = ['gold200', 'lose100', 'vision', 'poison', 'teleport', 'legendary'];
    const resultIdx = Math.floor(Math.random() * outcomes.length);
    const result = outcomes[resultIdx];

    // Jackpot: all 3 symbols match (gold, legendary)
    const isJackpot = result === 'gold200' || result === 'legendary';
    // Pick symbols
    const jackpotSymbol = SLOT_SYMBOLS[Math.floor(Math.random() * SLOT_SYMBOLS.length)];
    // For fail: ensure at least one reel differs
    let s1, s2, s3;
    if (isJackpot) {
        s1 = s2 = s3 = jackpotSymbol;
    } else {
        s1 = SLOT_SYMBOLS[Math.floor(Math.random() * SLOT_SYMBOLS.length)];
        const differentSymbols = SLOT_SYMBOLS.filter((symbol) => symbol !== s1);
        s2 = differentSymbols[Math.floor(Math.random() * differentSymbols.length)];
        s3 = SLOT_SYMBOLS[Math.floor(Math.random() * SLOT_SYMBOLS.length)];
    }

    // Show modal and animate
    const modal = document.getElementById('slotMachine');
    const reel1 = document.getElementById('reel1');
    const reel2 = document.getElementById('reel2');
    const reel3 = document.getElementById('reel3');
    const resultText = document.getElementById('slotResult');
    modal.classList.remove('hidden');
    slotMachineOpen = true;
    gamePaused = true;
    resultText.textContent = '';

    // Start spinning animation
    [reel1, reel2, reel3].forEach((r) => {
        r.textContent = '❓';
        r.classList.add('spinning');
        r.classList.remove('stopped');
    });

    // Symbol cycling
    let cycleIdx = 0;
    const cycleInterval = setInterval(() => {
        cycleIdx = (cycleIdx + 1) % SLOT_SYMBOLS.length;
        [reel1, reel2, reel3].forEach((reel, i) => {
            if (reel.classList.contains('spinning')) {
                reel.textContent = SLOT_SYMBOLS[(cycleIdx + i * 2) % SLOT_SYMBOLS.length];
            }
        });
    }, 100);

    // Stop reels one by one
    setTimeout(() => {
        reel1.classList.remove('spinning');
        reel1.classList.add('stopped');
        reel1.textContent = s1;
    }, 800);

    setTimeout(() => {
        reel2.classList.remove('spinning');
        reel2.classList.add('stopped');
        reel2.textContent = s2;
    }, 1200);

    setTimeout(() => {
        reel3.classList.remove('spinning');
        reel3.classList.add('stopped');
        reel3.textContent = s3;
        clearInterval(cycleInterval);

        // Highlight all reels if jackpot
        if (isJackpot) {
            [reel1, reel2, reel3].forEach((r) => {
                r.style.borderColor = '#ffd700';
                r.style.boxShadow =
                    '0 0 30px rgba(255,215,0,0.8), inset 0 0 20px rgba(255,215,0,0.4)';
                r.style.fontSize = '44px';
            });
        }

        // Apply result
        resultText.textContent = applySlotResult(result);

        // Close modal after delay
        setTimeout(() => {
            modal.classList.add('hidden');
            slotMachineOpen = false;
            gamePaused = false;
            // Reset reel styles
            [reel1, reel2, reel3].forEach((r) => {
                r.style.borderColor = '';
                r.style.boxShadow = '';
                r.style.fontSize = '';
            });
        }, 1800);
    }, 1600);
}

function getSlotResultText(result, convertedToGold = false) {
    switch (result) {
        case 'gold200':
            return '💰 잭팟! 200골드 획득!';
        case 'lose100':
            return '💸 100골드를 잃었습니다...';
        case 'vision':
            return '👁️ 시야가 절반으로! (1분)';
        case 'poison':
            return '☠️ 독에 감염! (3분)';
        case 'teleport':
            return '🌀 랜덤 위치로 이동!';
        case 'legendary':
            return convertedToGold
                ? '💎 인벤토리가 가득 차 전설의 검 대신 100골드 획득!'
                : '💎 전설의 검 획득!!!';
    }
}

function applySlotResult(result) {
    const convertedToGold = result === 'legendary' && inventory.length >= INVENTORY_CAPACITY;
    switch (result) {
        case 'gold200':
            player.gold += 200;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ffd700', 30);
            playCoinSound();
            break;
        case 'lose100':
            player.gold = Math.max(0, player.gold - 100);
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ff4444', 20);
            break;
        case 'vision':
            player.visionReduction = 60;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#444488', 15);
            break;
        case 'poison':
            applyPlayerPoison(180);
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#88ff44', 20);
            break;
        case 'teleport':
            randomTeleport();
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#aaccff', 25);
            break;
        case 'legendary':
            if (inventory.length < INVENTORY_CAPACITY) {
                const legendWpn = WEAPONS.find((w) => w.id === 'legend');
                inventory.push({ ...legendWpn });
                recordDiscovery('weapons', 'legend');
            } else {
                player.gold += 100;
            }
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ffd700', 40);
            break;
    }
    const resultMessage = getSlotResultText(result, convertedToGold);
    addMessage(
        `🎰 ${resultMessage}`,
        result === 'gold200' || result === 'legendary' ? 'loot' : 'damage',
    );
    updateHud();
    return resultMessage;
}

function randomTeleport() {
    const tile = findSpawnTile(3, (tileX, tileY, x, y) => {
        const px = x * TILE_SIZE - player.w / 2;
        const py = y * TILE_SIZE - player.h / 2;
        return (
            !isSolidTile(tileX, tileY) &&
            !collidesWithMap(px, py, player.w, player.h) &&
            !collidesWithEntities(px, py, player.w, player.h, player)
        );
    });
    const x = tile ? tile.x * TILE_SIZE - player.w / 2 : FOUNTAIN_CENTER_X;
    const y = tile ? tile.y * TILE_SIZE - player.h / 2 : FOUNTAIN_CENTER_Y;
    movePlayerTo(x, y);
}
