'use strict';

function updateHud() {
    const weapon = player.weapon;
    const usesText = weapon.uses !== undefined ? ` [${weapon.uses}회]` : '';
    document.getElementById('equipmentSlot').innerHTML =
        `${weapon.icon} ${weapon.name} <span style="color:#ff8888;font-size:10px;">ATK ${weapon.atk}${usesText}</span>`;
    document.getElementById('hpText').textContent =
        `${Math.max(0, Math.round(player.hp))} / ${player.maxHp}`;

    const hpRatio = Math.max(0, player.hp / player.maxHp);
    const hpBar = document.getElementById('hpBarFill');
    hpBar.style.width = `${hpRatio * 100}%`;
    hpBar.classList.remove('low', 'mid');
    if (hpRatio < 0.3) hpBar.classList.add('low');
    else if (hpRatio < 0.6) hpBar.classList.add('mid');

    // Portrait face based on HP
    const portrait = document.getElementById('charPortrait');
    const face = document.getElementById('portraitFace');
    const hudTop = document.getElementById('hudTop');
    portrait.classList.remove('danger', 'warning');
    hudTop.classList.remove('danger');
    if (hpRatio < 0.2) {
        face.textContent = '🤕';
        portrait.classList.add('danger');
        hudTop.classList.add('danger');
    } else if (hpRatio < 0.4) {
        face.textContent = '😰';
        portrait.classList.add('warning');
    } else {
        face.textContent = player.playerFace;
    }

    document.getElementById('goldDisplay').textContent = `💰 ${player.gold}`;
    const minutes = Math.floor(player.gameTime / 60);
    const seconds = Math.floor(player.gameTime % 60);
    const timeDisplay = document.getElementById('timeDisplay');
    const timeColor =
        player.gameTime < 60 ? '#ff4444' : player.gameTime < 180 ? '#ffaa44' : '#ff8866';
    timeDisplay.textContent = `⏱ ${minutes}:${seconds.toString().padStart(2, '0')}`;
    timeDisplay.style.color = timeColor;
    // Poison indicator
    const statusDisplay = document.getElementById('poisonDisplay');
    if (player.speedBoost > 0) {
        statusDisplay.style.display = 'block';
        statusDisplay.style.color = '#ffff44';
        statusDisplay.textContent = `⚡ 스피드 ${player.speedBoost.toFixed(1)}s`;
    } else if (player.poisonTimer > 0) {
        statusDisplay.style.display = 'block';
        statusDisplay.style.color = '#88ff44';
        const poisonMinutes = Math.floor(player.poisonTimer / 60);
        const poisonSeconds = Math.floor(player.poisonTimer % 60);
        statusDisplay.textContent = `☠️ 독 ${poisonMinutes}:${poisonSeconds.toString().padStart(2, '0')}`;
    } else {
        statusDisplay.style.display = 'none';
    }
    document.getElementById('stageInfo').textContent = `Stage ${player.stage}`;

    // Aux weapon display
    const auxiliaryWeapon = player.auxWeapon;
    const auxDisplay = document.getElementById('auxDisplay');
    if (auxiliaryWeapon) {
        const usesText =
            auxiliaryWeapon.uses > 0
                ? ` [${auxiliaryWeapon.uses}]`
                : auxiliaryWeapon.uses === -1
                  ? ' [∞]'
                  : '';
        const cdText = player.auxCooldown > 0 ? ` (${player.auxCooldown.toFixed(1)}s)` : '';
        auxDisplay.innerHTML = `${auxiliaryWeapon.icon} ${auxiliaryWeapon.name}${usesText}${cdText}`;
        auxDisplay.style.color = auxiliaryWeapon.uses > 0 ? '#ff6644' : '#66bb6a';
    } else {
        auxDisplay.textContent = '없음';
        auxDisplay.style.color = '#888';
    }

    // Show quest progress
    const regionQuests = player.currentRegion === 'desert' ? DESERT_QUESTS : MAIN_QUESTS;
    const mainProgress = regionQuests.filter((questId) =>
        player.completedQuests.includes(questId),
    ).length;
    const mainTotal = regionQuests.length;
    document.getElementById('clearProgress').textContent =
        `📜 주요 퀘스트: ${mainProgress} / ${mainTotal}`;

    // Mount display
    const mount = player.mount;
    const mountSlot = document.getElementById('equipMount');
    const mountDisplay = document.getElementById('mountDisplay');
    if (mount) {
        mountDisplay.textContent = `${mount.icon} ${mount.name}`;
        mountSlot.style.display = 'flex';
    } else {
        mountSlot.style.display = 'none';
    }

    // Item slots
    for (let i = 0; i < CONSUMABLE_CAPACITY; i++) {
        const slot = document.getElementById('item' + (i + 1));
        if (slot) {
            slot.textContent = player.items[i] ? player.items[i].icon : '—';
        }
    }
}
