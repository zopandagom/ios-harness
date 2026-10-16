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
2. 도는 동안 리뷰를 Agent(`general-purpose`, 읽기 전용)에 맡긴다. 프롬프트에 범위 `git diff origin/main...HEAD` 와 기준 파일 `.claude/skills/pr/review-criteria.md`(CI 리뷰와 같은 기준)를 읽으라는 지시를 넣고, "파일을 수정하지 말 것, 결과는 🔴 필수 / 🟡 권장 표(파일:줄, 문제, 고칠 방법)로, 최종 보고는 한국어로"를 명시한다. 이 대화에서 이미 처리를 정한 지적이 있으면 그 목록도 넘겨 다시 보고하지 않게 한다.
3. 열린 PR 모드면 메인 대화가 직접 아래 "CI 리뷰 결과 모으기"로 CI 지적을 모은다. 로컬 리뷰와 같은 지적은 한 행으로 합친다.
4. 검증·로컬 리뷰·(열린 PR 모드면) CI 지적이 모두 모인 뒤 판단한다.
   - 검증이 FAIL 이거나 시간 초과면 PR 을 만들지 않고 push 도 하지 않는다. 원인을 보고한다.
   - 리뷰 지적(로컬·CI)이 1건이라도 있으면(🔴·🟡 모두) 멈추고 표와 항목별 고칠 방법을 보고한 뒤 사용자 결정을 기다린다. 이 스킬 안에서 파일을 수정하지 않는다.
   - 사용자가 수정을 지시하면 고친 뒤 커밋은 /micro-commit 지시를 기다린다. 보류를 지시하면(🔴 는 보류 불가) 본문 "검증 · 리뷰"에 "보류(이유)"로 적는다.
   - 다음 단계 조건: 검증 PASS·SKIP, 리뷰 지적 0건이거나 남은 지적이 모두 보류한 🟡.

### CI 리뷰 결과 모으기
`<N>` 은 §1 의 PR 번호다. 아래 gh 명령의 종료 코드가 0 이 아니면 출력을 쓰지 말고 오류와 함께 멈춘다 (예외: `gh pr checks` 의 `no checks reported` 는 체크 없음).
- 브랜치가 `.github/workflows/claude-review.yml` 을 바꿨으면 CI 리뷰는 워크플로 검증(main 의 파일과 같아야 한다)에 걸려 건너뛰고 `review` 체크는 통과로 보인다. 모으지 않고 본문 "검증 · 리뷰"에 "CI 리뷰는 워크플로 파일 변경으로 건너뜀 (로컬 리뷰로 갈음)"을 적는다.
1. 원격 head 의 `review` 잡 상태를 본다. 하나라도 대기 중이면 `pending`, 아니면 가장 늦게 시작한 실행이다.
   ```bash
   gh pr checks <N> --json name,bucket,startedAt --jq '[.[] | select(.name == "review")] | if length == 0 then empty elif any(.[]; .bucket == "pending") then "pending" else (sort_by(.startedAt) | last | "\(.bucket) \(.startedAt)") end'
   ```
   - `pass`: 2·3 으로 지적을 모은다. 요약이 없으면 아래 "그 밖"과 같다.
   - `pending`: 올릴 새 커밋이 있으면 CI 지적 없이 진행한다 (push 뒤 새 head 가 리뷰된다). 없으면 기다릴지 묻는다.
   - 그 밖(`fail`·`cancel`·`skipping`, 빈 출력): 상태를 보고에 적는다. 올릴 새 커밋이 없으면 Actions 에서 다시 돌릴지 이대로 진행할지 묻는다 (초안이면 `skipping` 이 정상이다).
2. 인라인 지적: `claude[bot]` 이 1 의 `startedAt` 뒤에 단 스레드 첫 글(`in_reply_to_id` 가 null).
   ```bash
   gh api --paginate 'repos/{owner}/{repo}/pulls/<N>/comments' --jq '.[] | {id, in_reply_to_id, user: .user.login, path, line, created_at, html_url, body}'
   ```
3. 요약: `claude[bot]` 이 1 의 `startedAt` 뒤에 단 가장 늦은 `## Claude 리뷰` 코멘트. 그 표에서 인라인 지적이 없는 행과 `범위 밖:` 줄도 지적으로 센다.
   ```bash
   gh api --paginate 'repos/{owner}/{repo}/issues/<N>/comments' --jq '.[] | {id, user: .user.login, created_at, html_url, body}'
   ```
- 이 대화에서 이미 처리를 정한 지적(답했거나 본문에 보류로 적은 것)은 다시 묻지 않는다.

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
PR 링크, 제목, 라벨, 검증·리뷰 요약(verify-head 결과, 필수 0 · 권장 N, 반영·보류)을 한 블록으로. push 했으면 "CI 리뷰 요약(`## Claude 리뷰`)이 올라오면 확인하고, 새 지적이 있으면 /pr 을 다시 실행해 처리한다"고 안내한다 (초안 PR 은 "준비 완료로 바꾼 뒤". 초안에서는 CI 리뷰가 돌지 않는다. `claude-review.yml` 을 바꾼 PR 은 CI 리뷰가 건너뛰어진다고 적는다). 머지는 하지 않는다. 머지 뒤 `/plugin marketplace update` 로 설치본이 갱신된다는 것을 덧붙인다.
