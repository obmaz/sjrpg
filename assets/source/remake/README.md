# 마을 전체 재제작 원본

사용자 레퍼런스와 `docs/reference-look-guide.md`를 기준으로 생성한 마을 패밀리입니다.
`town-master-scene.png`는 세 번째 비교 수정 후보의 원본입니다. 전체 재질·분위기 보조 컨셉이며 게임에 한 장 배경으로 붙이지 않습니다. 최상위 기준은 항상 `../style/approved-game-reference.jpg`이고 이 후보를 사용자 승인으로 간주하지 않습니다.
생성 프롬프트·실제 참조 파일·원본 경로는 `tools/extract/town_remake_generation.json`에 기록합니다.
게임용 원화는 분리하고 기존 추출·패킹·실측 절차로 검수합니다.

`master-scene-v1-rejected-prompt.txt`는 사용자가 거절한 첫 장면의 생성 문구입니다. 해당 첫 장면은 배포용 원화의 스타일 기준이 아닙니다. 두 번째 후보와 세 번째 후보의 실제 입력·출력·프롬프트는 생성 기록에서 구별합니다.

`trees.png`, `portal.png`, `gate-b.png`는 카메라·형태 검수에서 탈락한 비교 원본이며 런타임에서 사용하지 않습니다. 채택된 대체본은 각각 `trees-v2.png`, `portal-v2.png`, `gate-b-v2.png`입니다. `chapel.png`는 실제 게임 비교에서 넓은 난간 마당 때문에 탈락했으며, 이를 실제 입력으로 참조해 `chapel-v2.png`의 지면 접근형 본체와 작은 문턱을 다시 생성했습니다. 비교 근거와 재생성 입력을 보존하기 위해 탈락본도 이 소스 폴더에 남깁니다.

`wall-from-gate.png`는 새 성문 원화의 실제 보정 픽셀에서 추출하며 별도 생성한 다른 성벽을 섞지 않습니다. `props-cells/`도 생성 시트의 정확한 셀 잘라내기 결과입니다. 이 폴더 전체는 `assets/source/.gdignore`로 웹 PCK에서 제외됩니다.
