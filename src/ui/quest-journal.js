'use strict';

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
        list.innerHTML = '<p style="color:#888;font-size:12px;">활성 퀘스트 없음</p>';
    }
    document
        .getElementById('questJournal')
        .classList.toggle('hidden', player.activeQuests.length === 0);
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
