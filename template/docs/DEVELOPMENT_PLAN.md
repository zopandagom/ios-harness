# 개발 계획

프로젝트 소유 문서다. 작업 진행 방식과 완료 기준은 하네스 문서 [docs/harness/WORKFLOW.md](harness/WORKFLOW.md) 에 있다.

## 목표
<!-- new-ios-app: 앱 설명에서 제품 목표(무엇을, 누구에게)와 출시 목표가 있으면 적고 이 주석을 지운다 -->

## 핵심 기능 (MVP)
<!-- new-ios-app: 앱 설명에서 MVP 기능을 표(영역 · 기능 · 기술 메모)로 적고 이 주석을 지운다 -->

## 로드맵
<!-- new-ios-app: 사용자와 정한 단계가 있으면 표(단계 · 기간 · 목표 · 완료 기준)로 적는다. 없으면 "첫 단계: 하네스 확인과 첫 화면"만 두고 이 주석을 지운다 -->

## 출시 전 준비 체크리스트 (코드 외)
| 항목 | 필요 시점 | 상태 |
|---|---|---|
<!-- >>> ios -->
| Apple Developer Program 가입, 팀 ID 를 `Env.developmentTeam` 에 입력 | 실기기 테스트 전 | ☐ |
| App ID `__BUNDLE_ID__` 등록 | 실기기 테스트 전 | ☐ |
<!-- <<< ios -->
<!-- >>> macos -->
| Apple Developer Program 가입, 팀 ID 를 `Env.developmentTeam` 에 입력 | 배포 전 | ☐ |
| App ID `__BUNDLE_ID__` 등록 | 배포 전 | ☐ |
<!-- <<< macos -->
| App Store Connect 앱 생성, 앱 이름 선점 ("__DISPLAY_NAME__") | 가능한 빨리 | ☐ |
| `PrivacyInfo.xcprivacy`, 개인정보 처리방침 페이지 | 출시 전 | ☐ |
| 스토어 스크린샷·설명·키워드 (ASO) | 출시 전 | ☐ |

## 위험과 대응
| 위험 | 대응 |
|---|---|
| CI macOS 분 소진 (비공개 무료 플랜 2,000분, macOS 10배) | 문서만 바뀐 PR 은 CI 생략, lint 는 Ubuntu. 부족하면 셀프 호스트 러너나 레포 공개 검토 |
<!-- new-ios-app: 앱 설명에서 보이는 기술·일정 위험이 있으면 행으로 추가하고 이 주석을 지운다 -->
