---
name: debug-game
description: '자연의 수호자 RPG 게임의 버그를 진단하고 수정할 때 사용합니다. Use when: debugging game.js issues, fixing collision/combat/spawning/rendering bugs, diagnosing state management problems.'
argument-hint: '[버그 설명]'
---

# RPG 게임 디버깅 (자연의 수호자)

자연의 수호자 2D RPG 게임의 버그를 진단하고 수정하는 가이드입니다.

## 게임 아키텍처 개요

```
game.js (~5500줄, 단일 파일, 전역 스코프)
├── 사운드 시스템 (Web Audio API, try/catch)
├── 지형 생성 (Perlin-like noise)
├── 플레이어 (player 전역 객체)
├── 적 시스템 (enemies[], bossTypes)
├── 투사체 (projectiles[], enemyProjectiles[])
├── 파티클 (particles[])
├── 화염 장판 (fireZones[])
├── 아이템/인벤토리/상점
├── 퀘스트/NPC/대화
├── 지역 전환 (forest ↔ desert)
└── 렌더링 (Canvas 2D + DOM HUD)
```

> **중요**: `game.js`에는 `console.log`가 전혀 없습니다. 모든 피드백은 `addMessage()`, `spawnFloatingText()`, `spawnParticles()` 등의 인게임 시스템을 통해 이루어집니다.

---

## 1. 디버깅 시작: 임시 로깅 추가

`console.log`가 없으므로, 버그 진단 시 가장 먼저 할 일은 관련 지점에 임시 로깅을 추가하는 것입니다.

```js
// 권장 디버그 로깅 패턴
console.log('[DEBUG] functionName:', { var1, var2, var3 });

// HP/데미지 추적
console.log('[HP] player.hp:', player.hp, '| invincible:', player.invincible);
console.log('[DMG] enemy:', enemy.name, '| dmg:', dmg, '| remaining:', enemy.hp);

// 스폰 추적
console.log('[SPAWN] type:', type.name, 'at', x, y, '| total enemies:', enemies.length);

// 상태 전이 추적
console.log('[STATE] enemy:', enemy.name, 'state:', enemy.state, '→', newState);
```

---

## 2. 핵심 시스템별 진단 포인트

### 2.1 플레이어 HP 관련 버그

**의심 변수**: `player.hp`, `player.invincible`, `player.poisonTimer`

| 증상 | 확인할 곳 (line) | 의심 원인 |
|------|-----------------|----------|
| HP가 갑자기 0이 됨 | `updatePlayer()` ~1065, `takeDamage()` | invincible 타이머가 적용 안 됨 |
| HP 회복이 안 됨 | `updatePlayer()` 분수 로직 | `_fountainTimer` 리셋 문제 |
| 독 데미지가 비정상 | `updatePlayer()` | `poisonTick` 간격 문제 |
| 회복약 효과 없음 | `useConsumable()` | 아이템 제거 후 참조 문제 |

```js
// HP 디버깅 체크
console.log('[HP] hp:', player.hp, 'inv:', player.invincible,
  'poison:', player.poisonTimer, 'shield:', player.shieldActive);
```

### 2.2 공격/전투 관련 버그

**의심 변수**: `player.attackTimer`, `player.comboHits`, `player._comboTimer`, `player.weapon`

| 증상 | 확인할 곳 (line) | 의심 원인 |
|------|-----------------|----------|
| 공격이 안 나감 | `playerAttack()` ~1146 | `attackTimer` 초기화, `gamePaused` 체크 |
| 콤보가 안 쌓임 | `playerAttack()` | `_comboTimer` 만료, 적 미적중 |
| 데미지가 0 | `playerAttack()` ~1146 | `uses` 소진 → 맨손 전환 확인 |
| 무기 교체 후 버그 | `equipWeapon()` ~4000 | inventory 배열 splice 오류 |

```js
// 전투 디버깅 체크
console.log('[ATK] weapon:', player.weapon.id,
  'atk:', player.atk, 'timer:', player.attackTimer,
  'combo:', player.comboHits, 'paused:', gamePaused);
```

### 2.3 적 AI/스폰 관련 버그

**의심 변수**: `enemy.state`, `enemy.frozen`, `enemy._knockbackX/Y`

적 상태 머신 (wander → chase → attack → hurt → ranged):

| 증상 | 확인할 곳 (line) | 의심 원인 |
|------|-----------------|----------|
| 적이 움직이지 않음 | `updateEnemies()` ~1782 | `frozen` 상태, `gamePaused` |
| 적이 플레이어 무시 | `updateEnemies()` | `aggroRange` 계산, `isBoss` 플래그 |
| 보스가 스폰 안 됨 | `spawnBoss()` ~697 | `BOSS_TYPES` 배열, `getRandomBoss()` |
| 적이 벽에 끼임 | `updateEnemies()` 이동 로직 | `collidesWithMap()` 보정값 |
| 미니언 소환 실패 | `spawnEnemy()` ~660 | `minionType` 인덱스가 유효한지 |

```js
// 적 디버깅 체크
console.log('[ENEMY]', enemy.name,
  'state:', enemy.state, 'frozen:', enemy.frozen,
  'hp:', enemy.hp, 'x:', enemy.x.toFixed(0), 'y:', enemy.y.toFixed(0));
```

### 2.4 충돌 감지 관련 버그

**의심 함수**: `collidesWithMap()`, `collidesWithEntities()`, `aabb()`

| 증상 | 확인할 곳 (line) | 의심 원인 |
|------|-----------------|----------|
| 플레이어 벽 통과 | `updatePlayer()` ~1065 | 분리 축 충돌 순서, `skipMap` 플래그 |
| 적 통과 | `collidesWithEntities()` ~828 | 충돌 마진(4px) 문제 |
| 상자/아이템 못 먹음 | `collidesWithEntities()` | 히트박스 크기 불일치 |
| 탈것 충돌 오류 | `updatePlayer()` | 탈것 상태에서 `w/h` 변경 |

```js
// 충돌 디버깅 체크
console.log('[COL] x:', x, 'y:', y,
  'solid:', isSolid(Math.floor(x/TILE_SIZE), Math.floor(y/TILE_SIZE)),
  'entities:', collidesWithEntities(x, y, w, h, self));
```

### 2.5 렌더링 관련 버그

**의심 함수**: `draw()`, `drawTerrain()`, `drawMinimap()`, `updateUI()`

| 증상 | 확인할 곳 (line) | 의심 원인 |
|------|-----------------|----------|
| 화면 깜빡임 | `draw()` ~2095 | `ctx.clearRect()` 범위 |
| HUD 갱신 안 됨 | `updateUI()` ~4280 | `innerHTML` 덮어쓰기 누락 |
| 미니맵 위치 오류 | `drawMinimap()` | 스케일 계산, `MAP_W/MAP_H` |
| 텍스트 깨짐 | `draw()` | `ctx.font` 설정 순서 |

### 2.6 지역 전환 관련 버그

**의심 함수**: `travelToDesert()`, `travelToForest()`

| 증상 | 확인할 곳 (line) | 의심 원인 |
|------|-----------------|----------|
| 전환 후 적 안 나옴 | `travelToDesert()` ~5074 | 적 배열 초기화 누락 |
| 전환 후 충돌 오류 | `travelToDesert()` | 새 맵 생성, 타일 데이터 초기화 |
| 골드/아이템 유지 | `travelToDesert()` | `length = 0` 초기화 누락된 배열 |

```js
// 지역 전환 디버깅 체크
console.log('[REGION]', player.currentRegion,
  'enemies:', enemies.length, 'chests:', chests.length,
  'pickups:', goldPickups.length, weaponPickups.length);
```

---

## 3. 게임 상태 전체 덤프

심각한 버그 진단 시 game loop에 추가할 수 있는 상태 덤프:

```js
function debugDump() {
    console.log('=== GAME STATE DUMP ===');
    console.log('Player:', {
        hp: player.hp, maxHp: player.maxHp, atk: player.atk,
        weapon: player.weapon?.id, gold: player.gold,
        x: player.x.toFixed(0), y: player.y.toFixed(0),
        stage: player.stage, kills: player.kills,
        invincible: player.invincible, gamePaused,
        region: player.currentRegion, time: player.gameTime?.toFixed(1),
    });
    console.log('Enemies:', enemies.length, 'Projectiles:', projectiles.length,
        'Particles:', particles.length, 'FireZones:', fireZones.length);
    console.log('Arrays:', {
        chests: chests.length, npcs: npcs.length, mounts: mounts.length,
        goldPickups: goldPickups.length, weaponPickups: weaponPickups.length,
    });
    console.log('Inventory:', inventory.map(w => w.id),
        'AuxWeapons:', player.auxWeapons.map(a => a.id));
    console.log('Quests:', player.activeQuests, 'Completed:', player.completedQuests);
    console.log('========================');
}
```

---

## 4. 일반적인 디버깅 워크플로우

### Step 1: 증상 파악
- [ ] 어떤 동작이 기대와 다른가?
- [ ] 특정 조건에서만 발생하는가? (특정 무기, 특정 적, 특정 지역)
- [ ] 재현 가능한가?

### Step 2: 관련 시스템 식별
- [ ] 위 섹션 2에서 관련 시스템 찾기
- [ ] 관련 함수 line number 확인
- [ ] 의심 변수 목록 작성

### Step 3: 로깅 삽입
- [ ] 관련 함수 진입점에 `console.log` 추가
- [ ] 의심 변수 값 출력
- [ ] `gamePaused`, `gameOver`, `gameVictory` 등 가드 조건 확인

### Step 4: 원인 격리
- [ ] 로그 출력 분석
- [ ] 변수 값이 예상과 다른 지점 찾기
- [ ] 콜스택 추적 (어디서 호출되었는지)

### Step 5: 수정 및 검증
- [ ] 수정 코드 적용
- [ ] 동일 조건에서 재현 테스트
- [ ] 사이드 이펙트 확인 (다른 시스템에 영향 없는지)
- [ ] 디버그 로그 제거 (또는 주석 처리)

---

## 5. 알려진 취약 패턴

### 5.1 `gamePaused` 체크 누락
대화, 상점, 인벤토리 중 `gamePaused = true` 상태에서도 실행되는 로직이 있는지 확인:
```js
// 거의 모든 update 함수는 이 체크가 필요
if (gamePaused || gameOver || gameVictory) return;
```

### 5.2 배열 `length = 0` 초기화 누락
`travelToDesert()`에서 모든 엔티티 배열이 초기화되는지 확인. 새 배열을 추가했다면 반드시 지역 전환 시 초기화해야 함.

### 5.3 `uses` 소진 후 무기 참조
무기의 `uses`가 0이 되면 `WEAPONS[0]`(맨손)로 전환. 전환 전 `weapon.id`를 참조하는 코드가 있으면 undefined 오류 발생 가능.

### 5.4 `setTimeout` / `setInterval` 잔여 콜백
부메랑 반환, 슬롯 머신 애니메이션 등에서 사용. 게임 종료 후 콜백 실행을 막는 가드 조건 필수:
```js
if (!gameStarted || gameOver || gameVictory) return;
```

### 5.5 오디오 컨텍스트 미초기화
모든 사운드 함수는 `try/catch`로 감싸져 있지만, `getAudioCtx()` 호출 전에 `gameStarted` 체크가 없는 경우 불필요한 AudioContext 생성 가능.

---

## 6. 핵심 상수

| 상수 | 값 | 설명 |
|------|-----|------|
| `TILE_SIZE` | 32 | 타일 크기 (px) |
| `MAP_W` | 80 | 맵 너비 (타일) |
| `MAP_H` | 60 | 맵 높이 (타일) |
| `player.speed` | 225 | 플레이어 속도 (px/s) |
| `player.maxHp` | 100 | 최대 체력 |
| `player.maxGameTime` | 600 | 제한 시간 (초) |
| 충돌 마진 | 4 | `collidesWithMap()` 보정값 (px) |
| dt cap | 0.1 | `update()` delta time 상한 (초) |

---

## 7. 데이터 파일 디버깅

데이터 파일 관련 버그는 주로 오타나 ID 불일치로 발생:

- [ ] 무기 `id`가 `dropPool`/`dropWeapons`에 정확히 기재되었는지
- [ ] 적 `minionType` 인덱스가 `ENEMY_TYPES` 범위 내인지 (0-based)
- [ ] `rewardAux`의 `id`가 `AUX_WEAPONS`에 존재하는지
- [ ] `bossName`이 실제 적 `name`과 일치하는지
- [ ] `region: 'desert'`가 필요한 무기에 설정되었는지

---

## 주의사항

- **디버그 로그는 반드시 제거하거나 주석 처리** 후 최종 확인
- `game.js`는 단일 5500줄 파일 — 수정 시 줄번호가 밀리지 않도록 주의
- 데이터 파일 수정 후 `index.html`을 새로고침하여 반영 확인
- 사막 지역 버그는 `travelToDesert()` 호출 후에만 재현됨에 유의
