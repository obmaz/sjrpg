import { player, session } from '../core/state.js';
import { stopBgMusic } from '../systems/audio.js';

// ============================================================
//  GAME LOOP
// ============================================================
// Win/lose is handled by quest completion and player death
function triggerVictory(msg) {
    showResultScreen('victory', msg);
}

function showGameOverScreen(reason) {
    showResultScreen('gameOver', reason);
}

function showResultScreen(type, reason) {
    if (session.gameOver || session.gameVictory) return;
    stopBgMusic();
    const isWin = type === 'victory';
    if (isWin) session.gameVictory = true;
    else session.gameOver = true;

    // Grade calculation
    const score = player.kills * 10 + player.gold + Math.floor(player.damageDealt / 5);
    let grade, gradeColor;
    if (score >= 500) {
        grade = 'S';
        gradeColor = '#ffd700';
    } else if (score >= 300) {
        grade = 'A';
        gradeColor = '#ff6644';
    } else if (score >= 150) {
        grade = 'B';
        gradeColor = '#44aaff';
    } else if (score >= 60) {
        grade = 'C';
        gradeColor = '#88cc88';
    } else {
        grade = 'D';
        gradeColor = '#888888';
    }

    // Stats HTML
    const wpnIcon = player.weapon ? player.weapon.icon : '✊';
    const wpnName = player.weapon ? player.weapon.name : '맨손';
    const auxIcon = player.auxWeapon ? player.auxWeapon.icon : '—';
    const auxName = player.auxWeapon ? player.auxWeapon.name : '없음';
    const remainSec = Math.max(0, Math.ceil(player.gameTime));
    const timeStr = `${Math.floor(remainSec / 60)}분 ${remainSec % 60}초 남음`;

    const statsHTML = `
        <div class="stat-row"><span class="label">⚔️ 주무기</span><span class="value">${wpnIcon} ${wpnName}</span></div>
        <div class="stat-row"><span class="label">🎒 보조무기</span><span class="value">${auxIcon} ${auxName}</span></div>
        <div class="stat-row"><span class="label">☠️ 처치한 적</span><span class="value good">${player.kills} 마리</span></div>
        <div class="stat-row"><span class="label">💥 누적 피해량</span><span class="value" style="color:#ffaa44;">${player.damageDealt}</span></div>
        <div class="stat-row"><span class="label">💰 획득 골드</span><span class="value gold">${player.gold}</span></div>
        <div class="stat-row"><span class="label">⚡ 도달 Stage</span><span class="value" style="color:#ffaa44;">Stage ${player.stage}</span></div>
        <div class="stat-row"><span class="label">⏱️ 남은 시간</span><span class="value">${timeStr}</span></div>
        <div class="stat-row"><span class="label">🎯 목표</span><span class="value ${isWin ? 'good' : 'bad'}">${reason}</span></div>
    `;

    if (type === 'victory') {
        document.getElementById('victoryMsg').textContent = reason;
        document.getElementById('victoryStats').innerHTML = statsHTML;
        document.getElementById('victoryGrade').innerHTML =
            `<span style="color:${gradeColor}">${grade}</span>`;
        document.getElementById('victory').classList.remove('hidden');
    } else {
        document.getElementById('gameOverStats').innerHTML = statsHTML;
        document.getElementById('gameOverGrade').innerHTML =
            `<span style="color:${gradeColor}">${grade}</span>`;
        document.getElementById('gameOver').classList.remove('hidden');
    }
}

export { triggerVictory, showGameOverScreen };
