# 작업 흐름과 완료 기준

하네스 소유 문서다 (CONVENTIONS §6 "하네스 문서"). 목표·로드맵은 프로젝트 문서 [docs/DEVELOPMENT_PLAN.md](../DEVELOPMENT_PLAN.md) 에 있다.

## 작업 진행 방식
1. 로드맵의 단계 목표와 완료 기준을 확인 → 작업 단위로 쪼갠다.
2. `feat|fix|chore/<요약>` 브랜치 생성 (일정 표시 없이, CONVENTIONS §5).
3. Client 가 필요하면 **Interface 먼저** 설계(프로토콜 + 값 타입) → Fake → Feature Model + 테스트 → Impl 순서. Impl 없이도 Example 앱으로 화면을 확인할 수 있다.
4. 역할 단위로 작업 범위·수용 확인을 정하고 구현 → `/verify` → `/arch-review`. 새 상태·실패 경로가 생기는 구현과 그런 수정이 필요한 리뷰 지적은 팀으로 한다 (CONVENTIONS §6 "팀 구현"). 커밋은 사용자 지시로 `/micro-commit` (CONVENTIONS §5).
5. 사용자 지시로 `/pr` (마지막 커밋 검사(빌드에 영향이 있으면 lint·빌드·테스트) + 전체 `/arch-review` → PR 생성, 유형 라벨) → CI + Claude 리뷰 → 리뷰 반영 커밋도 `/pr` 로 push (CI 지적에 답) → 머지 전 확인 뒤 Merge commit 으로 머지 (CONVENTIONS §5 "리뷰 지적 처리").
6. 결정이 바뀌었으면 문서 갱신을 같은 PR 에 포함한다 (별도 커밋, type 은 CONVENTIONS §5 마이크로 커밋 표).

## 완료 기준 (Definition of Done)
- [ ] `/pr` 의 마지막 커밋 검사 PASS·SKIP, 필수 체크 `ci-result` 통과, 머지 전 확인 충족 (CONVENTIONS §5 "리뷰 지적 처리")
- [ ] CONVENTIONS §3 이 요구하는 테스트 (미뤘으면 그 보류 기록, CONVENTIONS §5 "리뷰 지적 처리")
<!-- >>> ios -->
- [ ] 해당하는 수동 확인(Example 앱 주요 상태, 실기기) 완료 (CONVENTIONS §5 표 "수동 확인" 행)
<!-- <<< ios -->
<!-- >>> macos -->
- [ ] 해당하는 수동 확인(Example 앱 주요 상태, 배포 서명 빌드) 완료 (CONVENTIONS §5 표 "수동 확인" 행)
<!-- <<< macos -->
- [ ] 제품 약속(PRODUCT §1)과 프로젝트 규칙(PRODUCT §3) 위반 없음
