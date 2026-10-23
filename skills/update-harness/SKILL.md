---
name: update-harness
description: ios-harness 로 이미 만든 iOS·macOS 프로젝트에 그 뒤의 하네스 변경(스킬·훅·CI·git 훅·Makefile·문서 규칙)을 가져온다. 만들 때의 템플릿과 지금 템플릿의 차이만 3-way 로 합치므로 프로젝트에서 채우고 고친 내용은 남고, 겹치는 곳만 충돌로 정리한다. 사용자가 하네스 업데이트, 하네스 동기화, /update-harness 를 요청할 때 사용한다.
argument-hint: "[--from <ref>]"
---

# update-harness

현재 대화에서 실행된다. 이 스킬 디렉터리(스킬을 불러올 때 표시되는 base directory)의 두 단계 위가 하네스 루트다. 아래에서 `<harness>` 는 그 경로이고, 가져오는 버전은 `<harness>/.claude-plugin/plugin.json` 의 `version` 이다.

| 파일 | 하는 일 |
|---|---|
| `<harness>/scripts/update-app.sh` | `.harness-version` 의 버전·입력으로 옛 템플릿과 지금 템플릿을 각각 만들고, 그 차이를 프로젝트에 `git cherry-pick --no-commit` 으로 합친다. 두 생성본을 `refs/harness/base`·`refs/harness/target` 에 남긴다 |

사용자에게 보이는 출력은 한국어로 쓴다. 커밋·push 는 하지 않는다 (프로젝트의 `/micro-commit`·`/pr` 이 맡는다).

## 1. 준비
- 현재 작업 디렉터리가 프로젝트 루트여야 한다 (`.harness-version` 이 있다). 없으면 경로를 묻는다.
- 설치된 플러그인이 최신인지 사용자에게 한 줄로 알린다: 이 스킬은 설치된 버전으로 가져온다. 더 새 버전이 필요하면 `claude plugin marketplace update ios-harness` → `claude plugin update ios-harness@ios-harness` → Claude Code 재시작 뒤 다시 실행한다.
- `git status --porcelain` 이 비어 있어야 한다. 아니면 멈추고 정리를 요청한다.
- `main` 을 최신으로 받고 `chore/harness-<가져오는 버전>` 브랜치를 만든다 (`git fetch origin && git switch -c chore/harness-<버전> origin/main`).

## 2. 입력 확인
`.harness-version` 이 `key=value` 형식이면 그대로 쓴다. `$ARGUMENTS` 의 `--from` 은 그대로 넘긴다.

옛 한 줄 형식(커밋 SHA 나 버전만 있음)이면 입력을 프로젝트에서 찾아 표로 보여 주고 확인받는다 (AskUserQuestion: "이대로 진행" / "수정할게요").

| 인자 | 찾는 곳 |
|---|---|
| `--from` | 한 줄 값. SHA 면 그대로, 버전이면 태그 `ios-harness--v<버전>` 이 있는지 `git ls-remote --tags https://github.com/zopandagom/ios-harness` 로 확인하고, 없으면 그 버전 무렵 커밋을 사용자에게 묻는다 |
| `--name` · `--bundle-id` · `--team` · `--os-version` | `Tuist/ProjectDescriptionHelpers/Project+Templates.swift` 의 `Env` (`appName`, `bundleIdPrefix`, `developmentTeam`, `deploymentTargets` 버전). 팀 ID 는 생성 뒤 입력했을 수 있으므로 비어 있지 않아도 사용자에게 생성할 때 넣었는지 묻는다 |
| `--platform` | 같은 곳의 `destinations` 가 `[.mac]` 이면 `macos` |
| `--display-name` | `Projects/App/Project.swift` 의 `CFBundleDisplayName` |
| `--allow-network` | `.swiftlint.yml` 에 `no_network` 규칙이 없으면 준다 |

## 3. 가져오기
```bash
<harness>/scripts/update-app.sh . [--from <ref>] [2 의 인자…]
```
- "하네스 변경 없음"이면 `.harness-version` 만 바뀐다. 7 로 간다.
- 실패하면 메시지를 그대로 보여 주고 멈춘다.

## 4. 충돌 정리
출력의 "충돌" 파일마다 하네스가 바꾼 것(`git diff refs/harness/base refs/harness/target -- <파일>`)과 프로젝트가 바꾼 것(`git diff refs/harness/base HEAD -- <파일>`)을 함께 보고 둘 다 살린다.
- 하네스 쪽에서 가져오는 것: 규칙·절차·스크립트·설정의 변경.
- 프로젝트 쪽에서 지키는 것: 제품 내용(앱 설명, 핵심 약속, MVP·로드맵), 프로젝트가 더한 규칙·lint 규칙·스킬 단계, 지운 기능.
- 같은 줄을 서로 다른 뜻으로 고쳤거나(예: 프로젝트가 일부러 바꾼 규칙을 하네스도 바꿈) 어느 쪽이 맞는지 정할 수 없으면, 두 내용을 나란히 보여 주고 사용자에게 묻는다.
- 프로젝트가 지운 파일을 하네스가 고쳤으면(modify/delete) 기본은 지운 채로 두고 보고한다.
- 정리한 파일은 `git add` 한다. 끝나면 `git diff --name-only --diff-filter=U` 와 `grep -rn '^<<<<<<< \|^>>>>>>> ' .` 결과가 비어 있어야 한다.

## 5. 새 자리 표시 채우기
출력의 "하네스가 새로 넣은 자리 표시"가 있으면 `<!-- new-ios-app: … -->` 지시를 `/ios-harness:new-ios-app` 스킬 §3 처럼 채운다. 근거는 프로젝트에 이미 있는 문서(CLAUDE.md 첫 단락, DEVELOPMENT_PLAN, ARCHITECTURE §4, CONVENTIONS §4)뿐이고, 없는 내용은 지어내지 않고 "미정"으로 둔다.

## 6. 검증
Bash `run_in_background: true`, `timeout: 1200000` 으로 실행한다.
```bash
mise install && make lint && make test
```
- `make lint` 가 실패하면 `make format` 후 다시 돌린다. 그래도 실패하면 원인이 하네스 변경인지 프로젝트 코드인지 나눠 보고하고 멈춘다 (프로젝트 코드는 고치지 않는다).
- `.githooks` 가 바뀌었으면 `make test-hooks` 도 포함된다 (`make test`).

## 7. 정리와 보고
- `git update-ref -d refs/harness/base && git update-ref -d refs/harness/target`
- 아래를 한 블록으로 보고한다:
  - 가져온 버전 (`<from> → <버전>`), 바뀐 파일 수
  - 충돌 파일과 정리 방식 (파일마다 한 줄), 사용자에게 물어 정한 것
  - 채운 자리 표시
  - 검증 결과 (`lint ✓ · build ✓ · test ✓ (N개)`)
  - 바뀐 것 중 사용자가 직접 할 일이 있으면 (예: 새 시크릿, 워크플로 권한, 사용자 설정 환경 변수)
- 다음 단계 안내: 프로젝트의 `/micro-commit` 으로 커밋하고 `/pr` 로 PR 을 연다. 스킬·훅이 바뀌었으면 Claude Code 를 다시 열어야 새 내용이 로드된다.
