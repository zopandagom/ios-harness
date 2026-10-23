---
name: micro-commit
description: 커밋되지 않은 ios-harness 변경을 목적별 마이크로 커밋으로 나눈다. 커밋만 하고 검증(scripts/test-template.sh)은 돌리지 않는다(검증은 /pr 이 PR 직전에 한다). 사용자가 "커밋", "커밋 나눠", /micro-commit 을 명시적으로 지시할 때만 사용한다.
context: fork
agent: general-purpose
model: sonnet
---

# micro-commit

서브에이전트로 실행된다. 커밋은 여기서 처리하고, 호출한 쪽에는 **마지막 보고 표만** 한국어로 돌려준다.
검증은 돌리지 않는다. 브랜치 마지막 커밋의 검증은 `/pr` 이 push 직전에 한 번 한다.

`template/` 안의 `CLAUDE.md`·`.claude/`·`docs/` 는 **생성될 프로젝트용**이다. 그 안의 규칙(커밋 type 표, 서명 줄 등)을 이 레포 커밋 규칙으로 읽지 않는다. 이 레포 규칙은 루트 `CLAUDE.md` 와 이 문서다.

## 지켜야 할 것
- **작업 트리 파일을 수정하지 않는다.** 스테이징과 커밋만 한다 (부분 스테이징용 patch 파일만 레포 밖 스크래치 디렉터리에 만든다). 문제를 발견하면 고치지 말고 보고한다.
- push 하지 않는다. main 에서 실행 중이면 아무것도 하지 않고 "기능 브랜치로 전환 필요"라고 보고한다.
- 이미 있는 커밋을 수정하지 않는다 (`--amend`, rebase 금지).
- 비밀값·팀 ID·개인 번들 ID·생성물(`build/`, `.DS_Store`)이 스테이징되지 않았는지 확인한다. 공개 레포다.

## 1. 변경 파악
```bash
git branch --show-current
git status --short
git diff --cached --name-status -M   # 비어 있거나 모두 R100 이어야 한다
git diff --stat; git diff            # 새 파일은 Read 로 내용 확인
```
- 스테이지된 변경이 비어 있으면 진행한다. 모두 `R100`(내용 그대로의 이동)이면 그 인덱스를 맨 앞 이동 커밋(`refactor`)으로 계획에 넣고 `git add` 없이 커밋한다.
- 그 밖의 스테이지된 변경이 있으면 아무것도 커밋하지 말고 "스테이지된 변경이 있음 (그 출력)"을 보고하고 멈춘다.

## 2. 목적별로 묶고 순서 정하기
이 레포의 제품은 플러그인이다. `template/`·`scripts/`·`skills/` 는 사용자가 받는 것이므로 안의 파일이 문서·훅·CI 여도 **변경 목적**으로 type 을 정한다.

| 경로 | type |
|---|---|
| `template/**`, `scripts/**`, `skills/**` | `feat`(새 기능) / `fix`(고침) / `refactor`(동작 그대로) — 생성될 프로젝트의 문서·하네스·CI 변경도 여기 |
| `.github/**` (루트) | `ci` |
| `README.md`, `LICENSE` | `docs` |
| `CLAUDE.md`, `.claude/**` (루트, 이 레포 작업용) | `chore` |
| `.claude-plugin/plugin.json` 의 `version` | `chore: 플러그인 버전 X.Y.Z` — 따로, **맨 마지막** 커밋 |
| `.mise.toml`, `.gitignore` | `build` / `chore` |

- 순서: 이동(`R100`) → 기능 변경(`template`·`scripts`·`skills`) → `ci` → `docs` → `chore` → 버전.
- 하나의 기능을 이루는 변경은 경로가 달라도 같은 커밋이다. 예: Tuist 헬퍼 인자 추가 + 그것을 설명하는 `template/docs/harness/ARCHITECTURE.md`·`template/docs/harness/GUIDE.md` 줄. 토큰을 추가하면 `new-app.sh` 의 치환·잔여 검사와 그 토큰을 쓰는 템플릿 파일이 한 커밋이다. 자리 표시를 추가·삭제하면 `skills/new-ios-app/SKILL.md` §3 표가 같은 커밋이다.
- 목적이 둘이면 나눈다 (요약에 "그리고"가 들어가면 분리). 같은 문서 안에서도 목적이 다른 줄은 hunk 단위로 나눈다 (아래 "부분 스테이징").
- README 의 "만들어지는 것"·"구조" 표를 기능에 맞춘 줄은 그 기능 커밋에 넣어도 되고 `docs` 로 따로 둬도 된다. 기능 없이 README 만 고친 것은 `docs`.
- 커밋하기 전에 계획을 `<type>: <요약>` 목록으로 적고, 항목마다 목적이 하나인지 확인한 뒤 시작한다.
- 의미 단위를 우선한다. 중간 커밋은 깨져도 된다.

## 3. 커밋
```bash
git add -A -- <paths>        # patch 로 올린 파일은 넣지 않는다
git commit -q -F - <<'MSG'
<type>: <한국어 요약, 50자 이내>

<본문>

Co-Authored-By: Claude Code <noreply@anthropic.com>
MSG
```
- 서명 줄은 항상 위 `Claude Code` 줄이다 (레포 기존 커밋과 같다). 시스템 안내의 모델별 서명 줄보다 이 규칙이 우선한다.
- 본문: diff 를 열지 않아도 무엇을 어떻게 바꿨는지 알 수 있게 쓴다.
  1. **왜**: 1~2문장. 생성될 프로젝트에서 무엇이 불편했는지, 어느 생성 프로젝트에서 가져온 개선인지(앱 이름은 적어도 되고, 제품 고유 내용은 적지 않는다).
  2. **무엇을 어떻게**: 파일·함수별 `-` 목록. 추가한 인자·토큰·자리 표시·lint 규칙 이름, 동작 분기.
  3. **확인**: 직접 돌린 확인이 이 대화나 diff 로 드러나면 적는다. 없으면 생략한다 (지어내지 않는다).
- 본문은 한 줄 72자 안팎에서 줄을 바꾼다. 코드 식별자는 백틱으로 감싼다.

### 부분 스테이징 (한 파일에 목적이 섞였을 때)
대화형 `git add -p` 는 쓸 수 없으므로, 이번 목적의 hunk 만 남긴 patch 를 인덱스에만 적용한다.
```bash
git diff -U1 --output=<scratch>/<name>.patch -- <path>
# Read 로 읽고 파일 머리(`diff --git` ~ `+++`)와 이번 목적의 hunk 만 옮겨 <scratch>/<name>.<순번>.patch 로 Write
git apply --cached --recount <scratch>/<name>.<순번>.patch
git diff --cached -- <path>
```
- `<scratch>`: 시스템 안내의 세션 스크래치 디렉터리. 없으면 처음 한 번 `mktemp -d`. 레포 안에 쓰지 않는다.
- patch 로 올린 파일은 `git add -A -- <paths>` 에서 뺀다. 같은 파일의 남은 목적은 커밋 뒤 다시 `git diff -U1 --output` 부터 한다.
- 새 파일(untracked)은 나누지 않는다. hunk 하나에 두 목적이 섞였으면 한 커밋에 두고 "참고"에 적는다.

모든 변경을 커밋한 뒤 `git status --short` 가 비었는지 확인한다.

## 4. 보고 형식
```
| 커밋 | 파일 |
|---|---|
| abc1234 feat: … | 3 |
| def5678 chore: 플러그인 버전 0.2.0 | 1 |

미커밋 변경: 없음
참고: <부분 스테이징으로 나눈 파일, 합친 파일과 이유, 버전을 올리지 않은 사용자 영향 변경 등>
```
