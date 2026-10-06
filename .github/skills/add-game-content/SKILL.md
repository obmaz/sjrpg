---
name: add-game-content
description: '자연의 수호자 RPG 게임에 새로운 무기, 적, 보스, 보조무기, 상자, 퀘스트를 추가할 때 사용합니다. Use when: adding new weapon/enemy/boss/aux-weapon/chest/quest to the 2D RPG game.'
argument-hint: '[weapon|enemy|boss|aux|chest|quest] 설명'
---

# RPG 게임 콘텐츠 추가 (자연의 수호자)

자연의 수호자 2D RPG 게임의 데이터 파일에 새로운 콘텐츠를 추가하는 체크리스트입니다.

## 프로젝트 구조

```
sjrpg/
├── index.html          # 게임 HTML (데이터 파일을 <script>로 로드)
├── game.js             # 메인 게임 로직
├── style.css           # 스타일
└── data/
    ├── weapons.js      # 주무기 정의 (WEAPONS 배열)
    ├── aux_weapons.js  # 보조무기 정의 (AUX_WEAPONS 배열)
    ├── enemies.js      # 적 정의 (ENEMY_TYPES, DESERT_ENEMY_TYPES 배열)
    ├── bosses.js       # 보스 정의 (BOSS_TYPES 배열)
    ├── chests.js       # 상자 정의 (CHEST_TYPES 배열)
    └── quests.js       # 퀘스트 정의 (QUESTS 배열)
```

> **중요**: 모든 데이터 파일은 `index.html`에서 `<script src="...">`로 로드되며, 전역 변수로 `game.js`에서 직접 참조됩니다. 파일명이나 변수명을 변경하면 `index.html`과 `game.js`도 함께 수정해야 합니다.

---

## 1. 새 무기 추가 (주무기)

### 체크리스트

- [ ] `data/weapons.js`의 `WEAPONS` 배열에 새 항목 추가
- [ ] `id`가 기존 무기와 중복되지 않는지 확인 (`fist`, `dagger`, `iron`, `axe`, `staff`, `firesword`, `legend`, `fan`, `hammer`, `whip`, `crossbow`, `scimitar`, `sandstorm`, `ankh`, `scorpion`)
- [ ] `region` 필드 확인: 사막 전용이면 `region: 'desert'`, 아니면 생략
- [ ] `ability` 값이 유효한지 확인 (`combo`, `wide`, `combo_wide`, `ranged`, `fire`, `legend`, `push`, `slam`)
- [ ] 새 `ability`인 경우 `game.js`에 해당 능력 로직 구현 필요
- [ ] 적 드롭 풀에 추가: `data/enemies.js`의 적 `dropPool`에 새 무기 `id` 추가
- [ ] 상자 드롭 풀에 추가: `data/chests.js`의 `dropWeapons`에 새 무기 `id` 추가

### 필수 필드

```js
{ id: 'weapon_id', name: '무기명', icon: '이모지', atk: 숫자, color: '#hex', rarity: '기본|일반|희귀|영웅|전설',
  ability: '능력타입', range: 숫자, cooldown: 숫자,
  desc: '설명' }
```

### ability별 추가 필드

| ability | 추가 필드 |
|---------|----------|
| `combo` | `comboMax`, `comboMult` |
| `wide` | `wideAngle` |
| `combo_wide` | `comboMax`, `comboMult`, `wideAngle` |
| `ranged` | `projectileSpeed`, `projectileSize` |
| `fire` | `fireDuration`, `fireDmg` |
| `legend` | `comboMax`, `comboMult`, `wideAngle`, `fireDuration`, `fireDmg`, `projectileSpeed`, `uses` |
| `push` | `pushForce`, `pushAngle` |
| `slam` | `slamDmg` |

---

## 2. 새 적 추가

### 체크리스트

- [ ] `data/enemies.js`의 적절한 배열에 추가 (`ENEMY_TYPES` 또는 `DESERT_ENEMY_TYPES`)
- [ ] `dropPool`에 존재하는 무기 `id`만 포함되어 있는지 확인
- [ ] 밸런스 확인: HP, ATK, speed가 같은 티어의 적과 비슷한 수준인지
- [ ] 보스 적이면 `isBoss: true` 설정, 필요시 `data/bosses.js`에도 추가
- [ ] 새 적 유형을 타겟으로 하는 퀘스트가 필요하면 `data/quests.js`에 추가
- [ ] 상자 파괴 시 스폰되는 적이면 `game.js` 내 `CHEST_TYPES` 참조 코드 확인

### 필수 필드

```js
{ name: '적이름', icon: '', hp: 숫자, atk: 숫자, speed: 숫자, color: '#hex', size: 숫자,
  xp: 숫자, dropRate: 0~1, dropPool: ['weapon_id', ...], ranged: true|false }
```

### 선택 필드

| 필드 | 설명 |
|------|------|
| `ranged: true` | 원거리 공격. `rangeCooldown`, `projSpeed` 필요 |
| `flying: true` | 비행형 (근접 공격 면역) |
| `giant: true` | 거대형 (큰 히트박스). `size`를 72 이상으로 |
| `poison: true` | 독 공격. `poisonDmg` 필요 |
| `isBoss: true` | 보스. 큰 `hp`, `xp`, `dropRate: 1.0` 권장 |
| `region: 'desert'` | 사막 지역 전용 (게임 로직에서 필터링) |

---

## 3. 새 보조무기 추가

### 체크리스트

- [ ] `data/aux_weapons.js`의 `AUX_WEAPONS` 배열에 추가
- [ ] `type` 결정: `'limited'` (횟수 제한) 또는 `'permanent'` (무제한)
- [ ] `type: 'limited'` → `uses` 양수 값, `type: 'permanent'` → `uses: -1` + `cooldown` 필요
- [ ] `ability` 값 확인 (`aoe_fire`, `freeze`, `lightning`, `poison_zone`, `heal`, `taunt`, `boomerang`, `shuriken`, `shield`, `trap`)
- [ ] 새 `ability`인 경우 `game.js`에 구현 필요
- [ ] 퀘스트 보상으로 지급하려면 `data/quests.js`의 `rewardAux`에 `id` 추가

### 필수 필드

```js
{ id: 'aux_id', name: '이름', icon: '이모지', uses: 숫자, desc: '설명',
  ability: '능력타입', type: 'limited|permanent' }
```

---

## 4. 새 보스 추가

### 체크리스트

- [ ] `data/bosses.js`의 `BOSS_TYPES` 배열에 추가
- [ ] `id`가 중복되지 않는지 확인
- [ ] `destroyTerrain`, `spawnMinions` 설정 확인
- [ ] `spawnMinions: true`인 경우 `minionType`이 `ENEMY_TYPES`의 유효한 인덱스인지 확인
- [ ] 보스도 `data/enemies.js`에 `isBoss: true`로 등록되어 있는지 확인

### 필수 필드

```js
{ id: 'boss_id', name: '보스명', hp: 숫자, atk: 숫자, speed: 숫자, color: '#hex', size: 숫자,
  ranged: true|false, destroyTerrain: true|false, spawnMinions: true|false, gold: 숫자, desc: '설명' }
```

---

## 5. 새 상자 타입 추가

### 체크리스트

- [ ] `data/chests.js`의 `CHEST_TYPES` 배열에 추가
- [ ] `dropWeapons`에 존재하는 무기 `id`만 포함
- [ ] `dropCount`와 `dropGold` 범위가 밸런스에 맞는지 확인
- [ ] `game.js`에서 상자 파괴 시 적 스폰 로직이 새 상자 타입을 처리하는지 확인

---

## 6. 새 퀘스트 추가

### 체크리스트

- [ ] `data/quests.js`의 `QUESTS` 배열에 추가
- [ ] `type`이 유효한 값인지 확인 (`kills`, `gold`, `boss`, `boss_specific`, `kills_specific`)
- [ ] `type: 'boss_specific'` → `bossName` 필드 필수
- [ ] `type: 'kills_specific'` → `enemyName` 필드 필수
- [ ] `rewardAux` 사용 시 존재하는 보조무기 `id`인지 확인
- [ ] 메인 퀘스트: `main: true`, 서브 퀘스트: `main: false`
- [ ] 메인 퀘스트는 `MAIN_QUESTS` 또는 `DESERT_QUESTS` 배열에도 `id` 추가

---

## 7. 밸런스 가이드

### 적 티어별 권장 스탯 범위

| 티어 | HP | ATK | Speed | XP | DropRate | Size |
|------|----|-----|-------|----|----------|------|
| 약한 적 | 15~30 | 2~7 | 60~200 | 10~30 | 0.4~0.6 | 20~26 |
| 중간 적 | 35~60 | 8~14 | 50~90 | 35~60 | 0.35~0.55 | 24~30 |
| 강한 적 (giant) | 80~200 | 6~20 | 30~45 | 60~150 | 0.6~0.8 | 72~100 |
| 보스 | 150~400 | 15~25 | 40~55 | 200~300 | 1.0 | 36~50 |

### 적 특수 속성별 밸런스 팁

- **원거리 적** (`ranged: true`): ATK를 동 티어보다 높게, Speed는 낮게 설정 (예: 다크 메이지 ATK 12, Speed 50)
- **비행형** (`flying: true`): 근접 면역이므로 HP를 낮게 보정 (예: 독수리 HP 20, ATK 7)
- **독 공격** (`poison: true`): 지속 피해를 고려해 ATK를 약간 낮추거나 Speed를 높임
- **거대형** (`giant: true`): 히트박스가 커서 맞기 쉬우므로 HP를 넉넉하게

### 무기 희귀도별 권장 ATK 범위

| 희귀도 | ATK 범위 | Cooldown 범위 | 예시 |
|--------|----------|---------------|------|
| 기본 | 2 | 0.4 | 맨손 |
| 일반 | 4~7 | 0.28~0.5 | 단검, 철검, 연발 석궁 |
| 희귀 | 6~16 | 0.4~1.2 | 전투 도끼, 마법 지팡이, 시미터, 가시 채찍, 선풍기 |
| 영웅 | 14~18 | 0.5~1.5 | 불꽃검, 대지의 망치, 모래폭풍, 앙크 홀 |
| 전설 | 20~25 | 0.35~1.8 | 전설의 검, 전갈 꼬리 |

- **원거리 무기** (`ability: 'ranged'`): ATK는 높게, cooldown은 길게 보정
- **광역 무기** (`ability: 'slam'`, `'wide'`): 여러 적을 동시에 타격하므로 ATK를 적절히 조정
- **콤보 무기** (`ability: 'combo'`): cooldown을 짧게, ATK는 낮게 시작하되 콤보 배율로 보상

### 사막 vs 기본 지역

사막 지역 적은 같은 티어 대비 **HP +5~10, ATK +2~4** 정도 높게 설정되어 있습니다. 새 지역 추가 시 이 점진적 상승 곡선을 참고하세요.

---

## 공통 주의사항

- 모든 `id`는 **영문 소문자 + 언더스코어** 사용 (예: `fire_sword`)
- `dropPool` / `dropWeapons`의 무기 `id`는 반드시 `WEAPONS` 배열에 존재해야 함
- 새 지역(region)을 추가할 경우 `game.js`의 `enemyPool` 선택 로직도 수정 필요
- 변경 후 `index.html`을 브라우저에서 열어 직접 테스트할 것
