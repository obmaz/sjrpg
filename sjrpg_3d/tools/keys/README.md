# Android 공용 디버그 키

`debug-keystore.jks`는 [obmaz/commuzip의 시험 설치용 키](https://github.com/obmaz/commuzip/blob/3c46620b960093f880c5661a576e3c1773d62613/android/app/debug-keystore.jks)를 그대로 사용합니다.
`setup_android.sh`가 이 파일을 기본으로 설정하므로 작업 환경마다 다른 서명이 생성되지 않습니다.

- 원본 Git blob: `7062c67d85c42a18ed1952248e83e5fa6348f727`
- 파일 SHA-256: `7a48a6d7e2a933abd052269a32d2a893757f479eff434f5fb8e9789c1e2d5950`
- 인증서 SHA-256: `5870487504e72ca08671d3229ade28b3136174235309f39afe17d7bee48f02ba`
- alias: `androiddebugkey`, 저장소·키 비밀번호: Android 디버그 표준값 `android`

공개 시험 키이며 정식 배포용 키로 사용하지 않습니다. 릴리스 키는 외부 환경 변수로만 설정합니다.
이 폴더는 내보내기 프리셋의 `tools/*` 제외 규칙으로 게임 패키지에 포함되지 않습니다.
기존 SJRPG의 환경별 디버그 키로 서명한 설치본과는 서명이 다릅니다.
