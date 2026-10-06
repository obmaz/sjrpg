import { recordDiscovery } from '../core/helpers.js';
import { player, session } from '../core/state.js';
import { AUX_WEAPONS } from '../data/aux-weapons.js';
import { DESERT_QUESTS, MAIN_QUESTS, QUESTS } from '../data/quests.js';
import { spawnDesertTraveler } from './spawning.js';
import { updateHud } from '../ui/hud.js';
import { addMessage } from '../ui/messages.js';
import { renderQuestJournal } from '../ui/quest-journal.js';
import { triggerVictory } from '../ui/results.js';

function getQuest(id) {
    return QUESTS.find((q) => q.id === id) || null;
}

// 지금 이 플레이어에게 제안할 수 있는 퀘스트인가?
//  - 이미 완료/진행 중이면 불가
//  - region이 있으면 현재 지역과 일치해야 함 (없으면 어디서나 가능)
//  - stage 퀘스트는 그 스테이지에 도달해야 등장
function isQuestAvailable(quest, player) {
    if (!quest) return false;
    if (player.completedQuests.includes(quest.id)) return false;
    if (player.activeQuests.some((aq) => aq.id === quest.id)) return false;
    if (quest.region && quest.region !== player.currentRegion) return false;
    if (quest.stage != null && player.stage < quest.stage) return false;
    return true;
}
function abandonRegionQuests(region) {
    player.activeQuests = player.activeQuests.filter((activeQuest) => {
        const quest = getQuest(activeQuest.id);
        if (quest?.region !== region) return true;
        addMessage(`📜 지역 이동으로 퀘스트 포기: ${quest.name}`, 'info');
        return false;
    });
    renderQuestJournal();
}

function updateQuestProgress() {
    let changed = false;
    for (let i = player.activeQuests.length - 1; i >= 0; i--) {
        const activeQuest = player.activeQuests[i];
        const quest = getQuest(activeQuest.id);
        if (!quest) continue;
        let progress = activeQuest.progress;
        if (quest.type === 'kills') progress = player.kills;
        else if (quest.type === 'kills_specific')
            progress = player.killsByName[quest.enemyName] || 0;
        else if (quest.type === 'gold') progress = player.gold;
        else if (quest.type === 'boss') progress = player.bossKills;
        else if (quest.type === 'boss_specific')
            progress = player.bossKillsByName[quest.bossName] || 0;
        if (progress !== activeQuest.progress) {
            activeQuest.progress = progress;
            changed = true;
        }
        if (progress >= quest.target && !player.completedQuests.includes(activeQuest.id)) {
            player.completedQuests.push(activeQuest.id);
            player.gold += quest.rewardGold;
            addMessage(`✅ 퀘스트 완료: ${quest.name}! (+${quest.rewardGold}💰)`, 'loot');
            if (quest.rewardAux) {
                const auxiliaryWeapon = AUX_WEAPONS.find((a) => a.id === quest.rewardAux);
                if (auxiliaryWeapon) {
                    player.auxWeapons.push({ ...auxiliaryWeapon });
                    if (!player.auxWeapon) player.auxWeapon = player.auxWeapons[0];
                    recordDiscovery('auxiliaryWeapons', auxiliaryWeapon.id);
                    addMessage(
                        `🎁 보조무기: ${auxiliaryWeapon.icon} ${auxiliaryWeapon.name}`,
                        'loot',
                    );
                }
            }
            player.activeQuests.splice(i, 1);
            changed = true;
            updateHud();
        }
    }
    if (
        !player.forestCleared &&
        player.currentRegion === 'forest' &&
        MAIN_QUESTS.every((questId) => player.completedQuests.includes(questId))
    ) {
        player.forestCleared = true;
        addMessage('🏆 숲의 주요 퀘스트 완료! 황금 제국 퀘스트로 사막 모험을 이어가세요.', 'loot');
    }
    if (
        !session.gameVictory &&
        player.currentRegion === 'desert' &&
        DESERT_QUESTS.every((questId) => player.completedQuests.includes(questId))
    ) {
        triggerVictory('🏆 사막의 모든 퀘스트 완료! 진정한 승리!');
    }
    if (
        !session.gameVictory &&
        !player.desertUnlocked &&
        player.currentRegion === 'forest' &&
        player.completedQuests.includes('slay_boss') &&
        player.completedQuests.includes('collect_1000gold')
    ) {
        player.desertUnlocked = true;
        addMessage('🏜️ 사막 지역이 해금되었습니다! 분수 근처 여행자를 찾아가세요!', 'loot');
        // Spawn desert traveler NPC near fountain
        spawnDesertTraveler();
    }
    if (changed) renderQuestJournal();
}

export { getQuest, isQuestAvailable, abandonRegionQuests, updateQuestProgress };
