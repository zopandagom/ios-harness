# 개발 계획

## 목표
<!-- new-ios-app: 앱 설명에서 제품 목표(무엇을, 누구에게)와 출시 목표가 있으면 적고 이 주석을 지운다 -->

## 핵심 기능 (MVP)
<!-- new-ios-app: 앱 설명에서 MVP 기능을 표(영역 · 기능 · 기술 메모)로 적고 이 주석을 지운다 -->

## 로드맵
<!-- new-ios-app: 사용자와 정한 단계가 있으면 표(단계 · 기간 · 목표 · 완료 기준)로 적는다. 없으면 "첫 단계: 하네스 확인과 첫 화면"만 두고 이 주석을 지운다 -->

## 작업 진행 방식
1. 로드맵의 단계 목표와 완료 기준을 확인 → 작업 단위로 쪼갠다.
2. `feat|fix|chore/<요약>` 브랜치 생성 (일정 표시 없이, CONVENTIONS §5).
3. Client 가 필요하면 **Interface 먼저** 설계(프로토콜 + 값 타입) → Fake → Feature Model + 테스트 → Impl 순서. Impl 없이도 Example 앱으로 화면을 확인할 수 있다.
4. 역할 단위로 구현 → `/verify` → `/arch-review`. 새 상태·실패 경로가 생기는 구현과 그 리뷰 지적 수정은 팀으로 한다 (CONVENTIONS §6 "팀 구현"). 커밋은 사용자 지시로 `/micro-commit` (CONVENTIONS §5).
5. 사용자 지시로 `/pr` (마지막 커밋 검사(빌드에 영향이 있으면 lint·빌드·테스트) + 전체 `/arch-review` → PR 생성, 유형 라벨) → CI + Claude 리뷰 → 리뷰 반영 커밋도 `/pr` 로 push (CI 지적에 답) → 머지 전 확인 뒤 Merge commit 으로 머지 (CONVENTIONS §5 "리뷰 지적 처리").
6. 결정이 바뀌었으면 문서 갱신을 같은 PR 에 포함한다 (별도 커밋, type 은 CONVENTIONS §5 마이크로 커밋 표).

## 완료 기준 (Definition of Done)
- [ ] `/pr` 의 마지막 커밋 검사 PASS·SKIP, 필수 체크 `ci-result` 통과, 머지 전 확인 충족 (CONVENTIONS §5 "리뷰 지적 처리")
- [ ] CONVENTIONS §3 이 요구하는 테스트 (미뤘으면 그 보류 기록, CONVENTIONS §5 "리뷰 지적 처리")
- [ ] Example 앱에서 주요 상태(정상/빈 상태/권한 거부/오류) 확인
- [ ] 제품 약속(CONVENTIONS §4) 위반 없음
- [ ] 실제 기기에서 한 번 이상 확인 (권한·시스템 프레임워크는 시뮬레이터와 동작이 다를 수 있음)

## 출시 전 준비 체크리스트 (코드 외)
| 항목 | 필요 시점 | 상태 |
|---|---|---|
| Apple Developer Program 가입, 팀 ID 를 `Env.developmentTeam` 에 입력 | 실기기 테스트 전 | ☐ |
| App ID `__BUNDLE_ID__` 등록 | 실기기 테스트 전 | ☐ |
| App Store Connect 앱 생성, 앱 이름 선점 ("__DISPLAY_NAME__") | 가능한 빨리 | ☐ |
| `PrivacyInfo.xcprivacy`, 개인정보 처리방침 페이지 | 출시 전 | ☐ |
| 스토어 스크린샷·설명·키워드 (ASO) | 출시 전 | ☐ |

## 위험과 대응
| 위험 | 대응 |
|---|---|
| CI macOS 분 소진 (비공개 무료 플랜 2,000분, macOS 10배) | 문서만 바뀐 PR 은 CI 생략, lint 는 Ubuntu. 부족하면 셀프 호스트 러너나 레포 공개 검토 |
<!-- new-ios-app: 앱 설명에서 보이는 기술·일정 위험이 있으면 행으로 추가하고 이 주석을 지운다 -->
