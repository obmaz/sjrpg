'use strict';

// ============================================================
//  NPC INTERACTION & QUESTS
// ============================================================
function interactNpc() {
    if (!canAct()) return;
    // Check portal first
    if (portals.length > 0 && interactPortal()) return;

    let closest = null,
        closestDistance = 50;
    for (const npc of npcs) {
        const dist = distance(
            player.x + player.w / 2,
            player.y + player.h / 2,
            npc.x + npc.w / 2,
            npc.y + npc.h / 2,
        );
        if (dist < closestDistance) {
            closest = npc;
            closestDistance = dist;
        }
    }
    if (!closest) return;

    // Shop NPC
    if (closest.isShop) {
        openShop(closest.shopType || 'village');
        return;
    }

    // Slot machine
    if (closest.isSlotMachine) {
        useSlotMachine();
        return;
    }

    // Stylist NPC (appearance change)
    if (closest.isStylist) {
        openAppearancePanel();
        return;
    }

    // Desert traveler NPC
    if (closest.isDesertTraveler) {
        showDesertTravelDialog(closest, '오아시스가 있는 사막 지역으로 떠납니다');
        return;
    }

    const options = showNpcDialog(closest);
    const availableQuests = getAvailableQuests(closest);
    availableQuests.forEach((quest) => {
        const questButton = document.createElement('div');
        questButton.className = 'dialog-option';
        const badge = quest.main ? '⭐ ' : '';
        questButton.innerHTML = `<span class="q-name">${badge}📜 ${quest.name}</span><br><span class="q-desc">${quest.desc}</span><br><span class="q-reward">보상: ${quest.rewardText}</span>`;
        questButton.addEventListener('click', () => acceptQuest(quest));
        options.appendChild(questButton);
    });
    if (availableQuests.length === 0) {
        options.innerHTML = '<p style="color:#888;">현재 받을 수 있는 퀘스트가 없습니다.</p>';
    }
}

function showNpcDialog(npc) {
    gamePaused = true;
    document.getElementById('npcDialog').classList.remove('hidden');
    document.getElementById('npcPortrait').textContent = npc.icon;
    document.getElementById('npcName').textContent = npc.name;
    document.getElementById('npcText').textContent = npc.dialog;
    const options = document.getElementById('npcOptions');
    options.innerHTML = '';
    return options;
}

function showDesertTravelDialog(npc, description) {
    const options = showNpcDialog(npc);
    const travelButton = document.createElement('div');
    travelButton.className = 'dialog-option';
    travelButton.innerHTML = `<span class="q-name">🏜️ 사막으로 이동</span><br><span class="q-desc">${description}</span><br><span class="q-reward">⚠️ 돌아올 수 없으며 미완료 숲 퀘스트는 포기됩니다</span>`;
    travelButton.addEventListener('click', () => {
        closeDialog();
        travelToDesert();
    });
    options.appendChild(travelButton);
}

function acceptQuest(quest) {
    if (!isGameActive() || !isQuestAvailable(quest, player)) return;
    if (player.activeQuests.length >= 3) {
        addMessage('📜 최대 3개의 퀘스트만 받을 수 있습니다!', 'damage');
        closeDialog();
        return;
    }
    player.activeQuests.push({ id: quest.id, progress: 0 });
    addMessage(`📜 퀘스트 수락: ${quest.name}`, 'loot');
    closeDialog();
    renderQuestJournal();
}

function closeDialog() {
    gamePaused = false;
    document.getElementById('npcDialog').classList.add('hidden');
}
