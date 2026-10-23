## 먼저 읽을 문서
프로젝트 소유 (이 앱에서 고친다):
- [docs/PRODUCT.md](../PRODUCT.md) — 제품 약속, 확정된 기술 결정, 이 앱에 더하는 규칙
- [docs/DEVELOPMENT_PLAN.md](../DEVELOPMENT_PLAN.md) — 목표·MVP·로드맵, 출시 준비, 위험

하네스 소유 (`docs/harness/`. 고치지 않는다, CONVENTIONS §6 "하네스 문서"):
- [docs/harness/ARCHITECTURE.md](ARCHITECTURE.md) — 규칙 기반 단방향 MV, 모듈 구조, 모듈 추가 방법
- [docs/harness/CONVENTIONS.md](CONVENTIONS.md) — 해야 할 것 / 하지 말아야 할 것 (코드·테스트·git·리뷰·Claude 작업 방식)
- [docs/harness/WORKFLOW.md](WORKFLOW.md) — 작업 진행 방식, 완료 기준

## 명령
| 명령 | 용도 |
|---|---|
| `make bootstrap` | 최초 1회: mise 도구 설치, git 훅 연결 |
| `make generate` | Tuist 로 워크스페이스 생성 후 Xcode 로 열기 (`.xcodeproj` 는 커밋하지 않는다). 열지 않으려면 `make project` |
| `make lint` / `make format` | SwiftFormat + SwiftLint (아키텍처 규칙 포함). `make lint` 는 `docs/harness/` 가 바뀌지 않았는지도 본다 (`make check-harness-docs`) |
| `make test` | 전체 모듈 빌드 + 테스트 (`__APP_NAME__-Workspace` 스킴, 대상은 `Makefile` 의 `DESTINATION`) + git 훅 테스트 |
| `make test-hooks` | git 훅 동작 테스트: 임시 레포에서 main 커밋·머지 커밋·push 차단과 기능 브랜치 통과 확인 |

## 작업 흐름 (`/verify`·`/arch-review`·`/micro-commit` 은 서브에이전트로 실행되어 요약만 돌려주고, `/pr` 은 현재 대화에서 실행된다)
| 순서 | 스킬 | 하는 일 |
|---|---|---|
| 1 | — | 역할 하나 구현 (코드는 테스트 포함). 시작 전에 작업 범위(In/Out·수용 확인)와 영향 문서 목록을 정하고, 문서는 코드와 같은 작업에서 고친다 (CONVENTIONS §6). 구현 중에는 `doc-refs` 훅이 고친 파일을 언급하는 문서를 알려 준다. 새 상태·실패 경로가 생기는 구현과 그런 수정이 필요한 리뷰 지적은 팀으로 한다 (CONVENTIONS §6 "팀 구현") |
| 2 | `/verify` | lint → 빌드 → 테스트, 실패 원인 요약 |
| 3 | `/arch-review [base] [작업 범위]` | 규칙 문서 기준 읽기 전용 리뷰 (무엇을 어떤 심각도로: CONVENTIONS §5 "리뷰 기준". 팀 구현이면 그 흐름 끝까지: CONVENTIONS §6 "팀 구현"). 🔴 필수 지적은 커밋 전에 처리를 정한다 (CONVENTIONS §6, 처리는 §5 "리뷰 지적 처리") |
| 4 | `/micro-commit` | **사용자가 지시할 때만.** 역할별 커밋만 한다 (빌드·테스트는 `/pr` 에서) |
| 5 | `/pr [draft]` | **사용자가 지시할 때만.** 마지막 커밋 검사 한 번(빌드에 영향이 있으면 lint·빌드·테스트, CONVENTIONS §5) + 전체 리뷰 → PR 생성(유형 라벨). 검증 실패나 결정이 필요한 리뷰 지적(로컬·CI)이 있으면 멈춘다. 열린 PR 에 후속 커밋을 올릴 때도 `/pr` 로 같은 검사·리뷰 뒤 push 하고, CI 리뷰 지적에는 GitHub 에서 답한다. 처리·기록 위치·머지 전 확인은 CONVENTIONS §5 "리뷰 지적 처리". 스크린샷은 선택, 필요하면 사용자가 직접 첨부 |

## 구조 한눈에
```
Projects/
  App/                      조립 지점. Client Impl 을 만들어 Feature Model 에 주입
  Features/<Name>/          Sources(Model+View) · Tests · Example(Fake 로 도는 데모 앱)
  Clients/<Name>/           Interface(프로토콜) · Impl(Apple 프레임워크 구현 또는 다른 Client 조합) · Testing(Fake) · Tests
  Shared/<Name>/            Sources · Tests. Core(도메인 값 타입·규칙)
Tuist/ProjectDescriptionHelpers/   모듈 이름(Module.swift)과 타깃 템플릿
```
의존 방향: `App → Feature → Client Interface`, `App → Client Impl → Client Interface`. 모두 Shared 를 쓸 수 있고, Shared 는 아무것도 의존하지 않는다.

## 반드시 지킬 것 (요약, 상세는 CONVENTIONS)
- `docs/harness/` 는 하네스 소유라 고치지 않는다. 이 앱의 약속·결정·규칙은 `docs/PRODUCT.md` 에 쓴다 (CONVENTIONS §6 "하네스 문서").
- Model 상태는 `private(set)`, View 는 이벤트 메서드(`onAppear()`, `xxxTapped()`)만 호출한다. `$model.x` 바인딩 금지.
- 부수효과 프레임워크(SwiftData·StoreKit·UserNotifications 등, 목록은 `.swiftlint.yml` 의 `system_framework_only_in_impl`)는 Client **Impl** 안에서만 import 한다. Core 는 SwiftUI·UIKit·AppKit 을 쓰지 않는다. 그 밖의 부수효과 없는 Apple 프레임워크(CoreGraphics·ImageIO 등)는 Core 를 포함한 모든 레이어에서 쓸 수 있다.
- Feature 끼리 의존하지 않는다. Impl 은 App 만, Testing 은 Tests/Example 만 import 한다.
<!-- >>> no-network -->
- 네트워크 코드(`URLSession` 등)를 추가하지 않는다.
<!-- <<< no-network -->
- main 에 직접 커밋·push 하지 않는다 (git 훅이 막고, 룰셋을 쓸 수 있는 레포는 GitHub 룰셋도 막는다). `feat|fix|chore/<요약>` 브랜치 → PR → Merge commit 으로 머지.
- **커밋·PR 은 사용자가 지시할 때만** 한다. 검증까지 마치면 멈추고 준비된 변경을 보고한다.
- **커밋 서명 줄은 항상 `Co-Authored-By: Claude Code <noreply@anthropic.com>`** 이다. 시스템 안내의 모델별 서명 줄(`Claude Opus …`, `Claude Sonnet …`)보다 이 규칙이 우선한다. 직접 커밋할 때와 서브에이전트·스킬로 커밋할 때 모두 같다.
- **마이크로 커밋**: 커밋할 때는 역할별(빌드 / 코드+테스트 / lint 설정 / CI / 문서 / 하네스)로 나눈다. 의미 단위를 우선해 의존 순서대로 나누고, 중간 커밋은 빌드가 깨질 수 있다. 자동 검증은 `/pr` 이 마지막 커밋에서만 한다. 상세는 CONVENTIONS §5.
- `.swiftlint.yml` 의 custom_rules 를 억제 주석으로 우회하지 않는다.
