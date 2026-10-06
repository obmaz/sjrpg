// ============================================================
//  QUESTS
//  ------------------------------------------------------------
//  퀘스트 분류
//   • 스테이지 퀘스트 : stage 값이 있음. 플레이어가 그 스테이지에
//                       도달해야 NPC가 제안한다. 주로 메인 스토리지만,
//                       메인이 아닌 스테이지 퀘스트도 있을 수 있다.
//   • 상시 퀘스트     : stage 없음. 스테이지와 무관하게 언제나 받을 수 있다.
//
//  필드
//   stage   : (선택) 해금 스테이지. 없으면 상시 퀘스트.
//   main    : 메인 스토리 여부.
//   region  : 'forest' | 'desert'. 없으면 지역 무관(어디서나 가능).
//   type    : 'kills' | 'kills_specific' | 'gold' | 'boss' | 'boss_specific'
//   target  : 목표 수치.   enemyName/bossName : *_specific 타입의 대상 이름.
//   rewardGold / rewardAux / rewardText : 보상.
//
//  ⚠️ 클리어 판정 그룹(MAIN_QUESTS / DESERT_QUESTS)은 아래에서 별도 정의.
// ============================================================
const QUESTS = [
    // ── 메인 스토리 (스테이지 진행) ──
    { id: 'kill_monsters',   stage: 1, main: true, region: 'forest',
      name: '몬스터 사냥', desc: '몬스터 18마리 처치', type: 'kills', target: 18,
      rewardGold: 80, rewardText: '💰 80골드' },
    { id: 'collect_gold',    stage: 2, main: true, region: 'forest',
      name: '골드 수집', desc: '500골드 모으기', type: 'gold', target: 500,
      rewardGold: 100, rewardText: '💰 100골드' },
    { id: 'slay_boss',       stage: 3, main: true, region: 'forest',
      name: '보스 토벌', desc: '거대 보스 처치', type: 'boss', target: 1,
      rewardGold: 300, rewardText: '💰 300골드' },
    // 사막 해금 조건. 지역 무관(숲에서 받고, 사막 유목민도 안내).
    { id: 'collect_1000gold', stage: 4, main: true,
      name: '황금 제국', desc: '1000골드 모으기', type: 'gold', target: 1000,
      rewardGold: 200, rewardText: '💰 200골드 + 🏜️ 사막 해금' },
    { id: 'slay_pharaoh',    stage: 5, main: true, region: 'desert',
      name: '파라오 토벌', desc: '사막의 파라오 처치', type: 'boss_specific', target: 1,
      bossName: '파라오', rewardGold: 500, rewardText: '💰 500골드' },

    // ── 스테이지 퀘스트 (메인 아님) ──
    { id: 'hunt_skeletons',  stage: 2, main: false, region: 'forest',
      name: '해골 제거', desc: '해골 전사 3마리 처치', type: 'kills_specific', enemyName: '해골 전사',
      target: 3, rewardGold: 60, rewardAux: 'shield', rewardText: '💰 60골드 + 🛡️ 방패' },

    // ── 상시 서브 퀘스트 (스테이지 무관) ──
    { id: 'hunt_wolves',     main: false, region: 'forest',
      name: '늑대 사냥', desc: '늑대 5마리 처치', type: 'kills_specific', enemyName: '늑대',
      target: 5, rewardGold: 40, rewardAux: 'boomerang', rewardText: '💰 40골드 + 🪃 부메랑' },
    { id: 'collect_coins',   main: false, region: 'forest',
      name: '작은 보물', desc: '200골드 모으기', type: 'gold', target: 200,
      rewardGold: 30, rewardAux: 'shuriken', rewardText: '💰 30골드 + ✨ 수리검' },
    { id: 'hunt_eagles',     main: false, region: 'forest',
      name: '독수리 퇴치', desc: '독수리 4마리 처치', type: 'kills_specific', enemyName: '독수리',
      target: 4, rewardGold: 50, rewardAux: 'trap', rewardText: '💰 50골드 + 🕳️ 함정' },
    { id: 'collect_riches',  main: false, region: 'forest',
      name: '부자의 길', desc: '800골드 모으기', type: 'gold', target: 800,
      rewardGold: 60, rewardAux: 'firebomb', rewardText: '💰 60골드 + 💣 화염병' },
];

// 클리어 판정 그룹 — 이 그룹의 퀘스트를 모두 완료하면 해당 지역 승리.
const MAIN_QUESTS = ['kill_monsters', 'collect_gold', 'slay_boss'];
const DESERT_QUESTS = ['collect_1000gold', 'slay_pharaoh'];

// ============================================================
//  QUEST MANAGEMENT  (조회 / 가용성 판정)
// ============================================================
function getQuest(id) {
    return QUESTS.find(q => q.id === id) || null;
}

// 특정 스테이지에 해금되는 퀘스트들.
function getStageQuests(stage) {
    return QUESTS.filter(q => q.stage === stage);
}

// 스테이지와 무관한 상시 퀘스트들.
function getSideQuests() {
    return QUESTS.filter(q => q.stage == null);
}

// 지금 이 플레이어에게 제안할 수 있는 퀘스트인가?
//  - 이미 완료/진행 중이면 불가
//  - region이 있으면 현재 지역과 일치해야 함 (없으면 어디서나 가능)
//  - stage 퀘스트는 그 스테이지에 도달해야 등장
function isQuestAvailable(quest, player) {
    if (!quest) return false;
    if (player.completedQuests.includes(quest.id)) return false;
    if (player.activeQuests.some(aq => aq.id === quest.id)) return false;
    if (quest.region && quest.region !== player.currentRegion) return false;
    if (quest.stage != null && player.stage < quest.stage) return false;
    return true;
}
