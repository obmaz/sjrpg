# 웹·안드로이드 내보내기와 GPU 텍스처

같은 `sjrpg_3d/` 프로젝트를 웹과 Android APK로 내보냅니다. Godot 버전은 루트 `.godot-version`, 공간 표시 방식은 GL Compatibility·120° 직교 카메라입니다.

| 대상 | GPU 텍스처 | 빌드 |
| --- | --- | --- |
| PC 웹 | S3TC | WebGL2·단일 스레드 |
| 모바일 웹 | ETC2, 지원되는 형식 자동 선택 | 같은 Web 패키지에 두 형식 포함 |
| Android | ETC2 | arm64-v8a APK, 현재 패키지 ID·저장 경로 유지 |

`project.godot`는 S3TC/BPTC와 ETC2/ASTC 임포트 그룹을 모두 켭니다. Web 프리셋의 desktop/mobile 옵션도 모두 켭니다. 실제 선택한 표면은 `compress/high_quality=false`이므로 S3TC와 ETC2 파일을 생성합니다. 높은 품질 옵션은 BPTC/ASTC로 형식을 바꾸므로 호환성 검토 없이 켜지 않습니다. `compress/lossy_quality`는 이 GPU 코덱의 품질 조절 값이 아닙니다.

## 이미지 정책

`assets/data/texture_policy.json`의 10개 불투명 표면만 VRAM 압축(`compress/mode=2`)합니다.

- 건축: limestone·slate·timber·bark
- 숲: grass·paving
- 강·절벽: rock·water
- 동굴: floor·dark

원본 파일·UV·논리 해상도·크기 제한은 유지하고 밉맵을 사용합니다. 코덱의4px 저장 블록 정렬과 원본 논리 해상도를 구분합니다. UI·효과·잎·유리·현재 배우 텍스처는 기존 손실 임포트(`mode=1`)와 품질·밉맵·알파 설정을 보존합니다. 자동3D 감지는 꺼서 이후 임포트가 이 구분을 바꾸지 않게 합니다. 런타임에 `.bin`에서 만드는 배우 ImageTexture는 별도 경로입니다.

`tools/texture_policy.py --apply`는 임포트 설정만 고치며 이미지를 열거나 재인코딩하지 않습니다. `tools/import_project.sh`가 정책 적용→실제 Godot 재임포트→정책 검사를 수행합니다. 실제 remap·UID·플랫폼 파일은 Godot이 생성합니다. 기존 UID는 유지하고 없던 두 HUD UID는 엔진의 최초 할당을 기록합니다.

## 실행

저장소 루트에서:

```sh
tools/setup_godot.sh
sjrpg_3d/tools/export_web.sh

# JDK17 이상, Linux/CI 도구 설치
sjrpg_3d/tools/setup_android.sh
sjrpg_3d/tools/export_android.sh
# release는 기존 본인 서명 키 환경 변수를 사용
sjrpg_3d/tools/export_android.sh --release
```

웹은 `sjrpg_3d/build/web/`, APK는 `sjrpg_3d/build/android/`에 만듭니다. `tools/check_platform_exports.py`가 실제 PCK/APK를 읽어 Web의 양쪽 형식과 Android의 ETC2 전용 리소스, 텍스처 헤더·밉맵·논리/저장 크기를 검사합니다. [Android 설치와 서명](android.md)을 함께 참조합니다.

## 비용과 검수

두 GPU 형식을 포함하면 Web PCK 다운로드는 WebP 임포트만 사용할 때보다 커질 수 있습니다. GPU 압축은 실행 중 텍스처 저장 공간과 대역폭을 줄이는 설정이며 다운로드 압축과 구분합니다.

현재10개 표면의 실제 압축 블록은 형식당2,363,568바이트입니다. 같은 논리 크기·밉맵의 RGBA8 산술 예산은18,868,056바이트이며 실제 브라우저 전체 메모리와 다릅니다. 고품질 마을의 Godot 텍스처 집계는185,324,592→175,284,716바이트였습니다. 전체 기기의 RAM/VRAM이나 FPS 측정으로 해석하지 않습니다.

검수 하네스는 실제 PC 형식과 ETC2를 지원하는 WebGL2 컨텍스트에서 선택된 CTEX 경로·압축 업로드·크기를 확인합니다. 일반 화면을 먼저 촬영하고, 미사용 리소스를 명시적으로 읽는10장 통제 측정을 별도로 기록합니다. 기존 동굴 촬영 fixture는 일시정지된 사진이며 마을·강은 실행 중입니다.

비교 캡처와 측정 JSON은 검수 Actions 아티팩트에 보관합니다. 동일 카메라·해상도의 대응 사진만 화질 비교에 사용하며, 전투 중 카메라가 움직인 장면은 보조 자료로 구분합니다. UI·알파 경계·타일 디테일을 양 형식에서 확인합니다.

`Build Android APK` 워크플로는 빌드·서명·패키지 검증과 APK 아티팩트를 만듭니다. `Review Web and Android texture compression`은 임포트와 실제 GPU 촬영을, `Compose verified GPU texture review`는 같은 런타임 소스의 촬영 자료만 재사용해 비교를 만듭니다. 정상 웹 배포는 전체 테스트와 저장·로딩·패드·음악 브라우저 검사를 유지합니다.
