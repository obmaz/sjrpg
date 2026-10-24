import { canAct, getAvailableQuests, isGameActive } from '../core/helpers.js';
import { player, session } from '../core/state.js';
import { getInteractionTarget } from '../systems/interactions.js';
import { boardMount } from '../systems/mounts.js';
import { isQuestAvailable } from '../systems/quests.js';
import { interactPortal, travelToDesert } from '../systems/travel.js';
import { openAppearancePanel } from './appearance.js';
import { addMessage } from './messages.js';
import { renderQuestJournal } from './quest-journal.js';
import { openShop } from './shop.js';
import { useSlotMachine } from './slot-machine.js';

// ============================================================
//  NPC INTERACTION & QUESTS
// ============================================================
function interactNpc(target = getInteractionTarget()) {
    if (!canAct()) return;
    if (!target) return;
    if (target.kind === 'mount') {
        boardMount(target.entity);
        return;
    }
    if (target.kind === 'portal') {
        interactPortal();
        return;
    }
    const closest = target.entity;

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
        const questButton = document.createElement('button');
        questButton.type = 'button';
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
    session.gamePaused = true;
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
    const travelButton = document.createElement('button');
    travelButton.type = 'button';
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
    session.gamePaused = false;
    document.getElementById('npcDialog').classList.add('hidden');
}

export { interactNpc, showDesertTravelDialog, acceptQuest, closeDialog };
