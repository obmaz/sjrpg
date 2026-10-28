# Diablo II LoD 1.13 소서리스 기준 자료

대상은 LoD 1.13c입니다. 공개 미러의 폴더 표기는 `d2_113_data`이며, 버전 표기를 추측하지 않도록 원본 커밋·파일 SHA-256을 JSON fixture에 고정했습니다. D2R 2.4 이후의 히드라/공유 지연 변경은 적용하지 않습니다. 한국어 이름은 현대 한글 명칭이며 `originalName`은 원본 테이블 식별자입니다.

[기계 판독 fixture](../../flutter_game/test/fixtures/diablo2_sorceress_113.json)에는 30개 기술, 원본 Skills/SkillDesc 행, 64개 연관 Missiles 행, 난이도와 히드라 데이터 및 출처 해시가 포함됩니다.

| 학교      | 기술          | 원본 이름         | 레벨 | 0기준 행/열 | 선행 기술                |
| --------- | ------------- | ----------------- | ---- | ----------- | ------------------------ |
| fire      | 화염탄        | Fire Bolt         | 1    | 0/1         | 없음                     |
| fire      | 온기          | Warmth            | 1    | 0/2         | 없음                     |
| lightning | 번개 줄기     | Charged Bolt      | 1    | 0/1         | 없음                     |
| cold      | 얼음살        | Ice Bolt          | 1    | 0/1         | 없음                     |
| cold      | 얼어붙은 갑옷 | Frozen Armor      | 1    | 0/2         | 없음                     |
| fire      | 지옥불        | Inferno           | 6    | 1/0         | 없음                     |
| lightning | 전자기장      | Static Field      | 6    | 1/0         | 없음                     |
| lightning | 염력          | Telekinesis       | 6    | 1/2         | 없음                     |
| cold      | 서릿발        | Frost Nova        | 6    | 1/0         | 없음                     |
| cold      | 얼음 작렬     | Ice Blast         | 6    | 1/1         | 얼음살                   |
| fire      | 불길          | Blaze             | 12   | 2/0         | 지옥불                   |
| fire      | 화염구        | Fire Ball         | 12   | 2/1         | 화염탄                   |
| lightning | 번개 파장     | Nova              | 12   | 2/0         | 전자기장                 |
| lightning | 번개          | Lightning         | 12   | 2/1         | 번개 줄기                |
| cold      | 오한 갑옷     | Shiver Armor      | 12   | 2/2         | 얼음 작렬, 얼어붙은 갑옷 |
| fire      | 화염벽        | Fire Wall         | 18   | 3/0         | 불길                     |
| fire      | 마법부여      | Enchant           | 18   | 3/2         | 온기, 화염구             |
| lightning | 연쇄 번개     | Chain Lightning   | 18   | 3/1         | 번개                     |
| lightning | 순간이동      | Teleport          | 18   | 3/2         | 염력                     |
| cold      | 빙하 가시     | Glacial Spike     | 18   | 3/1         | 얼음 작렬                |
| fire      | 운석 낙하     | Meteor            | 24   | 4/1         | 화염구, 화염벽           |
| lightning | 뇌우          | Thunder Storm     | 24   | 4/0         | 번개 파장, 연쇄 번개     |
| lightning | 마력 보호막   | Energy Shield     | 24   | 4/2         | 순간이동, 연쇄 번개      |
| cold      | 눈보라        | Blizzard          | 24   | 4/0         | 서릿발, 빙하 가시        |
| cold      | 냉기 갑옷     | Chilling Armor    | 24   | 4/2         | 오한 갑옷                |
| fire      | 화염 숙련     | Fire Mastery      | 30   | 5/1         | 없음                     |
| fire      | 히드라        | Hydra             | 30   | 5/2         | 마법부여                 |
| lightning | 번개 숙련     | Lightning Mastery | 30   | 5/1         | 없음                     |
| cold      | 얼음 보주     | Frozen Orb        | 30   | 5/0         | 눈보라                   |
| cold      | 냉기 숙련     | Cold Mastery      | 30   | 5/1         | 없음                     |

## 수치와 시간

- 원본 시간은 초당 25프레임입니다. 공유 시전 지연은 화염벽 35프레임, 운석 30, 히드라 40, 눈보라 45, 얼음 보주 25입니다. 운석의 실제 낙하 대기는 별도로 60프레임입니다.
- 마나는 `(mana + lvlmana × (rank − 1)) × 2^(manashift − 8)`에 최소 마나를 적용합니다. 지옥불은 유지 프레임당 값에 Missiles의 Mana Use `8/16`과 초당 25프레임을 곱합니다. 1등급 7.03125마나/초이며 시작에는 6마나가 필요합니다.
- 피해 증가는 2–8, 9–16, 17–22, 23–28, 29+등급 구간별 증가량과 HitShift를 반영합니다. 시너지는 투자 등급(`blvl`)을 사용합니다.
- 불길·화염벽·운석 잔불의 원본 툴팁 DPS는 중첩 화염 세 개를 합산한 값입니다. 집계 DPS를 사용하면서 런타임에서 다시 세 배 하면 안 됩니다.
- 전자기장은 현재 체력의 25%를 기준으로 합니다. 원본 최대 체력 하한은 일반 0%, 악몽 33%, 지옥 50%이며 모두 처치할 수 없습니다. 보스 전용 50% 하한은 이 게임의 명시적 변형입니다.
- 마력 보호막은 물리·화염·번개·냉기·마법 피해를 마나로 흡수하며 독은 우회합니다. 피해 1당 마나는 `(32 − 투자 염력 등급)/16`, 즉 2에서 0.75까지 감소합니다. 남은 마나만큼만 흡수합니다.
- 냉기 갑옷 세 가지는 상호 배타적입니다. 얼어붙은 갑옷은 실제 근접 적중에 빙결, 오한 갑옷은 근접 공격 시도에 냉기 반격, 냉기 갑옷은 원거리 투사체에 얼음살 반격입니다.

## 원본 연출의 형태

- 지옥불: 방향을 유지하는 긴 화염 분사. Flamethrower/Flamethrower2 15프레임 레이어입니다.
- 불길: 발밑 이동 경로를 따라 남는 지면 화염. 화염벽은 지정점 양방향으로 늘어나는 불의 선입니다. groundFireBig 37프레임 중 12–36프레임을 반복합니다.
- 운석: 60프레임 목표 표시, 하강하는 Meteor/MeteorTail, 16프레임 폭발, 반복되는 groundFireMedium 잔불로 나눕니다.
- 얼음 보주: 16프레임 IceOrb 구체가 이동하며 16방향 IceBolt를 회전 방출하고 끝에서 방사형으로 터집니다. 단일 추적탄이 아닙니다.
- 히드라: 머리 세 개가 각각 움직이며 Firebolt 투사체를 발사합니다. 세 머리를 한 장의 고정 마법진으로 대체하지 않습니다.
- 번개는 관통하는 선, 연쇄 번개는 적 사이 연결, 번개 파장·서릿발은 시전자 중심으로 확장되는 고리입니다.

## 출처

- [Skills.txt](https://raw.githubusercontent.com/fabd/diablo2/e67aa992be5db412bd0437bb8afb95eedee0c9bc/code/d2_113_data/Skills.txt) · SHA-256 `59601208f3052205c175753038cedb6e338ef9bdc268f4e92a74b9c7b69cdc07`
- [SkillDesc.txt](https://raw.githubusercontent.com/fabd/diablo2/e67aa992be5db412bd0437bb8afb95eedee0c9bc/code/d2_113_data/SkillDesc.txt) · SHA-256 `1d5994c58e1965f4900b839e88a9f10fec15b1497728005b85f98954e103df0f`
- [Missiles.txt](https://raw.githubusercontent.com/fabd/diablo2/e67aa992be5db412bd0437bb8afb95eedee0c9bc/code/d2_113_data/Missiles.txt) · SHA-256 `9d6794a50e8b1931e476a4d666bfe4048d7d1dada454f19659d74a8825adef53`
- [DifficultyLevels.txt](https://raw.githubusercontent.com/fabd/diablo2/e67aa992be5db412bd0437bb8afb95eedee0c9bc/code/d2_113_data/DifficultyLevels.txt) · SHA-256 `aaa1a5d93df8c62707cf05308d82418ae7058ac1ac15ac768331f2abe440ff88`
- [MonStats.txt](https://raw.githubusercontent.com/fabd/diablo2/e67aa992be5db412bd0437bb8afb95eedee0c9bc/code/d2_113_data/MonStats.txt) · SHA-256 `973eedacd121f724f6dca1c7201750f6a4e60480c3d536ef5a9cb36853d38193`
- [PetType.txt](https://raw.githubusercontent.com/fabd/diablo2/e67aa992be5db412bd0437bb8afb95eedee0c9bc/code/d2_113_data/PetType.txt) · SHA-256 `4ce6ffd68c0db2be0b394f1c8c025aa929b6d4ceb14333a03c3426a43da89b42`
- https://github.com/ThePhrozenKeep/D2MOO/blob/master/source/D2Game/src/SKILLS/SkillSor.cpp · Reverse-engineered original engine behavior corroboration, not a replacement for 1.13 table values. HydraSrvDo144 explicitly summons3. ES EventFunc24 excludes poison. Armor EventFuncs1/2/3 implement separate triggers.
- https://classic.battle.net/diablo2exp/skills/sorceress-fire.shtml · Official Arreat Summit classic Fire spell descriptions/appearance reference.
- https://classic.battle.net/diablo2exp/skills/sorceress-lightning.shtml · Official Arreat Summit classic Lightning spell descriptions/appearance reference.
- https://classic.battle.net/diablo2exp/skills/sorceress-cold.shtml · Official Arreat Summit classic Cold spell descriptions/appearance reference.

게임 적용 범위: 원본 기술 트리·기초 수식·시너지·시전 지연을 기준으로 하되 현재 게임의 월드 단위와 전역 피해 배율에 맞춰 적용한다. 주문의 최종 피해에는 기존 공통 배율(0.6375×0.6)을 한 번 적용하며, 일반 광역기의 대상 상한과 다중 대상 피해 분산도 유지한다. 월드의 고정 범위 변환을 사용하며 화염벽의 길이는 원본 미사일의 등급별 길이 증가와 달리 모바일 전장에 맞춘 고정 범위다. 전자기장의 체력 비율 피해는 분산하지 않는다. 현재 전투에는 빗맞힘 확률이 없어 마법부여의 원본 명중률 보너스는 참고 수치로만 보존하며 실제 효과나 미리보기로 표시하지 않는다. 현재 몬스터는 개별 원소 저항·면역 수치를 갖지 않으므로 냉기 숙련은 저항 0을 기준으로 최대 두 배까지의 피해 보정으로 적용한다. 보스의 제어 저항과 전자기장 생명 50% 제한을 유지한다. 원본 아트·음원은 포함하지 않으며 효과는 실시간 Canvas/Flame 연출로 재구현한다.
