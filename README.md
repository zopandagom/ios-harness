# ios-harness

새 iOS 앱 프로젝트를 **앱 이름과 설명만 넣으면 바로 개발을 시작할 수 있는 상태**로 만들어 주는 Claude Code 플러그인이다.

## 만들어지는 것
| 영역 | 내용 |
|---|---|
| 프로젝트 구조 | Tuist 모듈러 아키텍처: `App`(조립 지점) · `Features/Home`(Model + View + Tests + Example 앱) · `Shared/Core`. Client(Interface / Impl / Testing) 추가 템플릿 |
| 아키텍처 규칙 | 규칙 기반 단방향 MV (`@Observable` Model, `private(set)` 상태, 이벤트 메서드), Swift 6 strict concurrency. SwiftLint custom rules 로 모듈 경계 강제 |
| 도구 | mise 로 버전 고정한 Tuist · SwiftLint · SwiftFormat · xcbeautify, `Makefile` (`bootstrap` `generate` `lint` `format` `test`) |
| Claude Code 하네스 | 스킬 `/verify` `/arch-review` `/micro-commit` `/pr`, 훅(Swift 자동 포맷, 고친 파일을 언급하는 문서 알림), 권한 설정. 작업 범위(In/Out·수용 확인)와 리뷰 기준·지적 처리 규칙(로컬·CI 리뷰 공통, `/pr` 이 CI 지적을 모아 답한다), 팀 구현 흐름(설계자·비판자·구현자·대조자) |
| git 훅 | pre-commit(main 커밋 차단·lint), pre-merge-commit(main 머지 커밋 차단), pre-push(main push 차단). `make test-hooks` 가 임시 레포에서 동작을 확인하고 `make test`·CI 에 포함 |
| GitHub | CI(Ubuntu lint + 줄 단위 어노테이션, macOS 빌드·테스트 + PR 코멘트 요약, `ci-result` 집계 체크), Claude Review 워크플로, PR 템플릿, Dependabot. 생성 시 머지 방식·유형 라벨·main 룰셋까지 설정 |
| 문서 | `CLAUDE.md`, `docs/ARCHITECTURE.md` · `CONVENTIONS.md` · `DEVELOPMENT_PLAN.md` — 앱 설명으로 제품 부분을 채운다 |

## 사용법
```text
# 처음 한 번: 마켓플레이스와 플러그인 설치 (Claude Code 안에서)
/plugin marketplace add zopandagom/ios-harness
/plugin install ios-harness@ios-harness

# 새 프로젝트를 만들 때
/ios-harness:new-ios-app 영수증 사진에서 지출을 정리하는 앱. 데이터는 기기 밖으로 나가지 않는다.
```
스킬이 앱 이름·번들 ID·레포 이름 같은 기본값을 제안하고, 확인을 받은 뒤 생성 → 문서 채우기 → `make lint && make test` → GitHub 레포 생성·설정까지 진행한다. 레포 생성 전에는 다시 확인을 받는다.

필요한 것: Xcode(iOS 26 SDK), [mise](https://mise.jdx.dev), [gh](https://cli.github.com)(로그인 상태), jq.

### 생성 후 직접 할 일
1. **Claude GitHub App** 을 새 레포에 설치 (모든 레포에 설치했다면 생략)
2. **`CLAUDE_CODE_OAUTH_TOKEN` 시크릿**: `claude setup-token` → `gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner/repo>`
3. 실기기에서 돌리기 전에 `Env.developmentTeam` 에 팀 ID 입력
4. (선택) 팀 구현(CONVENTIONS §6)을 Agent Teams 로 하려면 Claude Code 사용자 설정에 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. 없으면 서브에이전트로 대신한다

### 스크립트만 쓰기
```bash
scripts/new-app.sh --dest ../my-app-ios --name MyApp --bundle-id com.me.myapp [--display-name 내앱] [--team ABCDE12345] [--ios 26.0] [--allow-network]
scripts/publish.sh ../my-app-ios me/my-app-ios private    # 첫 커밋 · 레포 생성 · 설정 · git 훅
scripts/setup-github.sh me/my-app-ios                     # 레포 설정만 다시
```
`new-app.sh` 로 만든 문서에는 `<!-- new-ios-app: … -->` 자리 표시가 남는다. 스킬을 쓰면 Claude 가 채운다.

## 구조
```
.claude-plugin/        plugin.json · marketplace.json (이 레포가 곧 마켓플레이스이자 플러그인)
skills/new-ios-app/    생성 스킬
scripts/               new-app.sh · publish.sh · setup-github.sh · test-template.sh
template/              생성될 프로젝트 원본 (토큰: __APP_NAME__ __DISPLAY_NAME__ __BUNDLE_ID__ __TEAM_ID__ __IOS_VERSION__)
.github/workflows/     template.yml — 템플릿으로 샘플 앱을 만들어 lint · 빌드 · 테스트
```

## 라이선스
MIT
