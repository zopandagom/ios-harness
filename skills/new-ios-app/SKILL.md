---
name: new-ios-app
description: ios-harness 템플릿으로 새 iOS 또는 macOS 앱 프로젝트를 만든다. Tuist 모듈러 구조(App · Home Feature · Core), 단방향 MV 규칙과 lint, Claude Code 하네스(/verify · /arch-review · /micro-commit · /pr, 훅), git 훅, GitHub Actions(CI · Claude Review), 문서를 갖춘 프로젝트를 생성하고, 앱 설명으로 문서를 채운 뒤 검증하고 GitHub 레포까지 설정한다. 사용자가 새 iOS·Mac 앱 프로젝트 시작, 프로젝트 세팅, /new-ios-app 을 요청할 때 사용한다.
argument-hint: "[앱 설명]"
---

# new-ios-app

현재 대화에서 실행된다. 이 스킬 디렉터리(스킬을 불러올 때 표시되는 base directory)의 두 단계 위가 하네스 루트다. 아래에서 `<harness>` 는 그 경로다.

| 파일 | 하는 일 |
|---|---|
| `<harness>/scripts/new-app.sh` | `template/` 을 복사하고 앱 이름·번들 ID 등 토큰 치환 (git·GitHub 은 건드리지 않음) |
| `<harness>/scripts/publish.sh` | 첫 커밋 → GitHub 레포 생성·push → `setup-github.sh` → git 훅 연결 |
| `<harness>/scripts/setup-github.sh` | 머지 방식(Merge commit 만), 유형 라벨 9종, main 룰셋(필수 체크 `ci-result`), 시크릿 확인 |

사용자에게 보이는 출력은 한국어로 쓴다.

## 1. 입력 받기
`$ARGUMENTS` 에 앱 설명이 있으면 그것을 쓰고, 없으면 "어떤 앱인지(무엇을, 누구에게), 꼭 지킬 약속(예: 데이터가 기기 밖으로 나가지 않음)"을 먼저 묻는다.

설명을 바탕으로 아래 값의 기본안을 만든 뒤, **한 번에 표로 보여 주고 확인받는다** (AskUserQuestion: "이대로 진행" / "수정할게요"). 수정하면 고친 값으로 다시 표를 보여 준다.

| 항목 | 규칙 | 기본안 |
|---|---|---|
| 플랫폼 `--platform` | `ios`(iPhone) 또는 `macos`(Mac). 하나만 고른다 | 설명에 Mac·데스크톱 앱이면 `macos`, 아니면 `ios` |
| 앱 이름 `--name` | 영문 PascalCase. 타깃·워크스페이스·`<Name>App` 타입 이름에 쓰인다 | 설명에서 짓는다 |
| 표시 이름 `--display-name` | 홈 화면·Dock 에 보이는 이름. 한국어 가능, 따옴표·역슬래시 불가 | 앱 이름 |
| 번들 ID `--bundle-id` | `com.<owner>.<소문자 앱 이름>` | `gh api user --jq .login` 으로 owner |
| 팀 ID `--team` | Apple Developer 팀 ID 10자리. 비우면 iOS 는 시뮬레이터·CI, macOS 는 이 Mac 에서 실행(ad-hoc 서명)·CI 만 | 비움 |
| 최소 OS `--os-version` | 고른 플랫폼의 버전. `26.0` 형식 | `26.0` (쓰려는 프레임워크가 더 높은 버전을 요구하면 그 버전) |
| 네트워크 | 서버·외부 API 를 쓰면 허용(`--allow-network`). 금지면 lint `no_network` 와 문서 규칙이 들어간다 | 설명에 서버·로그인·동기화가 없으면 금지 |
| 위치 | 프로젝트 디렉터리. 비어 있거나 없어야 한다 | 현재 작업 디렉터리의 상위 디렉터리 아래 `<소문자-앱-이름>-<플랫폼>` (`-ios`·`-macos`) |
| GitHub 레포 | `owner/repo`, 공개·비공개 | `<owner>/<소문자-앱-이름>-<플랫폼>`, 비공개 |

- 공개·비공개 차이를 한 줄로 알린다: 비공개 무료 플랜은 main 룰셋을 쓸 수 없고(로컬 훅만 막는다) macOS CI 분이 10배로 차감된다. 공개 레포는 둘 다 제약이 없다.

## 2. 생성
```bash
<harness>/scripts/new-app.sh --dest <위치> --name <Name> --display-name "<표시 이름>" \
  --bundle-id <번들 ID> --platform <ios|macos> [--team <팀 ID>] --os-version <버전> [--allow-network]
```
실패하면 메시지를 그대로 보여 주고 입력을 고쳐 다시 실행한다.

## 3. 앱 설명으로 문서 채우기
생성된 프로젝트에서 `grep -rn 'new-ios-app:' <위치>` 로 자리 표시 주석을 모두 찾는다. 각 주석이 지시하는 내용을 **사용자가 준 설명에서만** 채우고 주석을 지운다. 설명에 없는 기능·일정·수치는 지어내지 않는다. 모르는 칸은 "미정"으로 둔다.

| 파일 | 채울 것 |
|---|---|
| `CLAUDE.md` 첫 단락 | 앱 설명 한 줄 + **핵심 약속**(굵게) + 예외가 있으면 한 줄 |
| `README.md` | 설명·핵심 약속, MVP 기능 목록, 쓸 Apple 프레임워크 |
| `docs/DEVELOPMENT_PLAN.md` | 목표, MVP 기능 표, 로드맵(사용자가 말한 것만), 위험 |
| `docs/PRODUCT.md` §1 | 핵심 약속을 ✅/❌ 행으로. lint 로 막을 수 있는 것은 "강제" 열에 규칙 이름 |
| `docs/PRODUCT.md` §2 | 설명에서 정해진 기술 결정(저장소, 프레임워크, 외부 서비스 경계) |

그다음 일관성을 맞춘다.
- 쓸 부수효과 프레임워크(권한·저장·결제·알림·위치 등)가 `.swiftlint.yml` 의 `system_framework_only_in_impl` 목록에 없으면 추가하고, 쓰지 않을 것이 확실한 항목은 그대로 둔다(목록에 있어도 비용이 없다).
- 핵심 약속을 바꾸는 예외(예: 위치 좌표만 Apple 지도 서비스로 보냄)가 있으면 CLAUDE.md·PRODUCT §1·§2 에 같은 말로 적는다.
- macOS 면 배포 경로를 PRODUCT §2 에 한 행으로 적는다: Mac App Store(App Sandbox entitlements 필요) 또는 Developer ID 서명·공증(샌드박스 밖 동작 가능, 예: 다른 프로세스 실행). 설명에 없으면 "미정".
- 끝나면 `grep -rn 'new-ios-app:' <위치>` 결과가 비어 있어야 한다.
- `docs/harness/` 는 하네스 소유라 고치지 않는다 (자리 표시도 없다. 생성 시 `CHECKSUMS` 가 만들어지고 `make lint` 가 확인한다).

## 4. 검증
Bash `run_in_background: true`, `timeout: 1200000` 으로 실행한다 (클린 빌드가 10분을 넘을 수 있다).
```bash
cd <위치> && git init -q -b main && mise install && make lint && make test
```
- `make lint` 가 실패하면 `make format` 후 다시 돌린다. 템플릿 코드에서 실패하면 하네스 결함이므로 고치지 말고 보고한다.
- (iOS) 시뮬레이터를 못 찾으면 `xcrun simctl list devices available | grep iPhone` 으로 기기를 골라 `make test DESTINATION='platform=iOS Simulator,name=<기기>,OS=latest'`.
- 통과해야 다음 단계로 간다.

## 5. GitHub 레포 만들기 (확인 후)
레포를 만들고 push 하는 것은 밖으로 나가는 작업이다. 레포 이름·공개 여부·push 할 파일 수를 보여 주고 **사용자 확인을 받은 뒤** 실행한다. 사용자가 원하면 이 단계를 건너뛰고 로컬 프로젝트만 남긴다.
```bash
<harness>/scripts/publish.sh <위치> <owner/repo> <public|private>
```
- 스크립트의 ⚠ 줄은 그대로 사용자에게 전한다.
- 첫 커밋은 main 에 바로 올라간다. 그 뒤로는 git 훅(pre-commit·pre-merge-commit·pre-push)이 main 직접 커밋·머지 커밋·push 를 막는다.

## 6. 보고
아래를 한 블록으로 보고한다.
- 생성 위치, 레포 링크, 앱 이름·번들 ID·플랫폼과 최소 OS·네트워크 정책
- 검증 결과 (`lint ✓ · build ✓ · test ✓ (N개)`)
- 사용자가 직접 해야 할 것:
  1. **Claude GitHub App**: 새 레포에 설치돼 있어야 Claude Review 가 돈다. 모든 레포에 설치했다면 할 일 없음, 아니면 https://github.com/apps/claude 에서 레포 추가 (또는 새 프로젝트에서 `/install-github-app`).
  2. **시크릿**: ⚠ 가 나왔다면 `claude setup-token` → `gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner/repo>`.
  3. **팀 ID**: 비웠다면 실기기 실행·배포 전에 `Tuist/ProjectDescriptionHelpers/Project+Templates.swift` 의 `Env.developmentTeam` 에 입력.
  4. 새 프로젝트 디렉터리에서 Claude Code 를 다시 열어야 프로젝트 스킬(`/verify` 등)과 훅이 로드된다. `make generate` 로 Xcode 를 연다.
- 첫 작업 제안: `chore/…` 브랜치에서 작은 변경으로 `/pr` 을 한 번 돌려 CI·Claude Review·룰셋이 동작하는지 확인.
- 나중에 하네스가 업데이트되면 플러그인을 업데이트한 뒤 프로젝트에서 `/ios-harness:update-harness` 로 가져온다 (`.harness-version` 이 비교 기준이라 지우지 않는다).
