import { canAct, isGameActive } from '../core/helpers.js';
import { player, session } from '../core/state.js';
import { getQuest } from '../systems/quests.js';

function renderQuestJournal() {
    const list = document.getElementById('questList');
    list.innerHTML = '';
    player.activeQuests.forEach((activeQuest) => {
        const quest = getQuest(activeQuest.id);
        if (!quest) return;
        const entry = document.createElement('div');
        entry.className = 'quest-entry';
        entry.innerHTML = `<span class="q-title">${quest.name}</span><br><span class="q-progress">${formatQuestProgress(quest, activeQuest.progress)}</span>`;
        list.appendChild(entry);
    });
    if (player.activeQuests.length === 0) {
        list.innerHTML = '<p class="empty-quests">활성 퀘스트 없음</p>';
    }
    document
        .getElementById('questJournal')
        .classList.toggle('hidden', player.activeQuests.length === 0 && !session.questJournalOpen);
}

function toggleQuestJournal() {
    if (!isGameActive()) return;
    if (session.questJournalOpen) {
        closeQuestJournal();
        return;
    }
    if (!canAct()) return;
    session.questJournalOpen = true;
    session.gamePaused = true;
    document.getElementById('questJournal').classList.add('mobile-journal-open');
    renderQuestJournal();
}

function closeQuestJournal() {
    if (!session.questJournalOpen) return;
    session.questJournalOpen = false;
    session.gamePaused = false;
    document.getElementById('questJournal').classList.remove('mobile-journal-open');
    renderQuestJournal();
}

function formatQuestProgress(quest, progress) {
    if (quest.type === 'kills') return `처치: ${progress} / ${quest.target}`;
    if (quest.type === 'kills_specific')
        return `${quest.enemyName || '적'} 처치: ${progress} / ${quest.target}`;
    if (quest.type === 'gold') return `골드: ${progress} / ${quest.target}`;
    if (quest.type === 'boss') return progress >= quest.target ? '완료!' : '보스 처치 필요';
    if (quest.type === 'boss_specific')
        return progress >= quest.target ? '완료!' : `${quest.bossName || '보스'} 처치 필요`;
    return `${progress} / ${quest.target}`;
}

export { renderQuestJournal, toggleQuestJournal, closeQuestJournal };
