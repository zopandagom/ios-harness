---
name: pr
description: 현재 기능 브랜치로 ios-harness PR 을 만들거나, 이미 열린 PR 에 후속 커밋을 올린다. PR 전에 마지막 커밋 검증(verify-head.sh — 템플릿 생성·lint·빌드·테스트, 플러그인 버전 확인)과 레포 규칙 리뷰(서브에이전트)를 돌리고, 실패나 지적이 있으면 멈춰서 보고한다. 사용자가 /pr 을 지시할 때만 사용한다.
argument-hint: "[draft]"
---

# pr

현재 대화에서 실행된다. PR 본문의 "왜"는 이 대화의 맥락과 커밋을 바탕으로 쓴다.
`template/.claude/skills/pr` 은 생성될 프로젝트용이다. 이 레포에는 이 문서를 쓴다.

인자: `$ARGUMENTS` — `draft` 가 있으면 초안 PR 로 만든다.

## 1. 사전 확인 — 하나라도 어긋나면 멈추고 보고
```bash
git fetch -q origin
git branch --show-current          # main 이면 중단
git status --short                 # 비어 있어야 한다
git log --oneline origin/main..HEAD
gh pr list --head "$(git branch --show-current)" --state open --json number,url
```
- 커밋되지 않은 변경이 있으면 중단하고 "커밋이 필요합니다 (/micro-commit 지시 필요)"라고 보고한다. 직접 커밋하지 않는다.
- origin/main 이후 커밋이 없으면 중단한다.
- `gh pr list` 에 PR 이 있으면 **열린 PR 모드**, `[]` 면 새 PR 모드다. 두 모드 모두 §2 를 거치고, 열린 PR 모드는 §3·§4 를 건너뛰어 §5 "열린 PR 모드"로 push 한다. `gh pr list` 자체가 실패하면 멈추고 보고한다.

## 2. 검증과 리뷰 (동시에)
1. 검증을 Bash `run_in_background: true`, `timeout: 1800000`(30분)으로 띄운다. 템플릿 생성 후 클린 빌드·테스트라 수 분 걸린다.
   ```bash
   .claude/skills/pr/verify-head.sh origin/main
   ```
2. 도는 동안 리뷰를 Agent(`general-purpose`, 읽기 전용)에 맡긴다. 프롬프트에 범위 `git diff origin/main...HEAD` 와 아래 기준을 넣고, "파일을 수정하지 말 것, 결과는 🔴 필수 / 🟡 권장 표(파일:줄, 문제, 고칠 방법)로, 최종 보고는 한국어로"를 명시한다.
   - **공개 레포**: 팀 ID·개인 번들 ID·이메일·비밀값·로컬 절대 경로가 들어가지 않았는가.
   - **제품 고유 내용**: 생성 프로젝트에서 가져온 개선에 앱 이름·제품 약속·제품 전용 lint 규칙·프레임워크(예: Photos·MapKit 전용 규칙)가 남지 않았는가. 제품마다 다른 내용은 `<!-- new-ios-app: … -->` 자리 표시로 남겼는가.
   - **토큰**: `__APP_NAME__` `__DISPLAY_NAME__` `__BUNDLE_ID__` `__TEAM_ID__` `__IOS_VERSION__` 외의 토큰이 생겼으면 `scripts/new-app.sh` 의 치환·잔여 검사와 README 가 함께 바뀌었는가.
   - **자리 표시**: `new-ios-app:` 자리 표시를 추가·삭제했으면 `skills/new-ios-app/SKILL.md` §3 표가 맞는가.
   - **`>>> no-network` 블록**: 새로 네트워크 관련 줄을 넣었다면 블록 안에 있고, `--allow-network` 변형에서 지워져도 문서·설정이 성립하는가.
   - **문서 일치**: 바꾼 동작을 설명하는 다른 곳(템플릿 `CLAUDE.md`·`docs/`·`.claude/skills`, README, 루트 `CLAUDE.md`)이 같은 내용으로 맞춰졌는가. 같은 규칙을 다시 적은 줄(리뷰 스킬·CI 프롬프트)도 핵심 문구로 검색해 본다.
   - **생성 프로젝트에서 동작**: 템플릿의 셸 스크립트·훅·워크플로가 토큰 치환 뒤에도 맞는가, `scripts/test-template.sh` 가 거치지 않는 경로(예: Client 모듈)가 있으면 그 점을 🟡 로 알린다.
3. 두 결과가 모두 온 뒤 판단한다.
   - 검증이 FAIL 이거나 시간 초과면 PR 을 만들지 않고 push 도 하지 않는다. 원인을 보고한다.
   - 리뷰 지적이 1건이라도 있으면(🔴·🟡 모두) 멈추고 표와 항목별 고칠 방법을 보고한 뒤 사용자 결정을 기다린다. 이 스킬 안에서 파일을 수정하지 않는다.
   - 사용자가 수정을 지시하면 고친 뒤 커밋은 /micro-commit 지시를 기다린다. 보류를 지시하면(🔴 는 보류 불가) 본문 "검증 · 리뷰"에 "보류(이유)"로 적는다.
   - 다음 단계 조건: 검증 PASS·SKIP, 리뷰 지적 0건이거나 남은 지적이 모두 보류한 🟡.

## 3. 라벨
```bash
git log --format=%s origin/main..HEAD | sed -E 's/^([a-z]+)(\([^)]*\))?!?:.*/\1/' | sort -u
gh label list --json name --jq '.[].name'
```
커밋 type(`feat` `fix` `refactor` `test` `build` `style` `ci` `docs` `chore`) 중 레포에 있는 라벨만 단다. 없는 라벨은 만들지 않고 보고에 "라벨 없음: …"으로 적는다.

## 4. 제목과 본문
- 제목: `<대표 type>: <한국어 요약>`, 50자 이내. 대표 type 은 PR 의 주 목적 (보통 feat/fix > refactor > 나머지).
- 본문 (임시 파일로 써서 `--body-file` 로 넘긴다):
  ```
  ## 무엇을 / 왜
  <한두 문장. 생성 프로젝트에서 가져온 개선이면 출처>

  ## 변경 사항
  - <생성될 프로젝트·플러그인 사용자 관점 변화 3~6줄>
  - 플러그인 버전: <이전> → <이후> (바꾸지 않았으면 "변경 없음 (사용자 영향 없음)")

  ## 검증 · 리뷰
  - verify-head.sh: <PASS(검사 항목) 또는 SKIP>
  - 리뷰: 필수 0 · 권장 N
  - <반영: 이 대화에서 확인된 리뷰 지적과 고친 내용 / 보류: 항목과 이유 / 추가로 직접 확인한 것>
  ```

## 5. push 와 PR 생성
```bash
git push -u origin HEAD
gh pr create --base main --title "<제목>" --body-file <본문 파일> [--label <type> …] [--draft]
```

### 열린 PR 모드
```bash
git push origin HEAD
```
- 본문·라벨은 원칙적으로 고치지 않는다. 예외: 새 type 의 라벨(`gh pr edit --add-label`), 본문 "검증 · 리뷰"의 verify-head 결과 줄과 보류 목록. `gh pr view --json body` 로 받아 해당 줄만 바꿔 `gh pr edit --body-file` 로 올린다.
- push 가 non-fast-forward 로 거절되면 멈추고 보고한다. force push 는 사용자가 허락한 뒤에만 `--force-with-lease` 로 한다.
- 리뷰 코멘트에 대응한 커밋이면 그 스레드에 Reply 로 반영(커밋 해시)·보류(이유)를 답한다.
  ```bash
  gh api -X POST repos/<owner>/<repo>/pulls/<N>/comments/<comment id>/replies -f body=<내용>
  ```

## 6. 보고
PR 링크, 제목, 라벨, 검증·리뷰 요약(verify-head 결과, 필수 0 · 권장 N, 반영·보류)을 한 블록으로. 머지는 하지 않는다. 머지 뒤 `/plugin marketplace update` 로 설치본이 갱신된다는 것을 덧붙인다.
