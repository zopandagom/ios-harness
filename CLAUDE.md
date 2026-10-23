# ios-harness

새 iOS·macOS 앱 프로젝트를 만드는 Claude Code 플러그인이다. 사용자 문서는 [README.md](README.md).

## 구조
- `template/` — 생성될 프로젝트 원본. 그 안의 `CLAUDE.md`·`.claude/`·`docs/` 는 **생성될 프로젝트용**이다. 이 레포 작업 규칙으로 읽지 않는다.
- `scripts/new-app.sh` — 복사 + 토큰 치환 + 블록 처리(`>>> no-network`, `>>> ios`·`>>> macos`) + `.harness-version` 기록.
- `skills/new-ios-app/SKILL.md` — 입력 받기 → 생성 → 문서 채우기 → 검증 → 레포 생성.
- `scripts/update-app.sh` · `skills/update-harness/SKILL.md` — 만든 프로젝트에 하네스 변경을 가져온다. `.harness-version` 의 버전·입력으로 옛·새 템플릿을 각각 만들어 그 차이를 3-way 로 합친다.
- `.claude/skills/` — **이 레포 작업용** 스킬 (`/micro-commit`, `/pr`). 플러그인으로 배포되지 않는다.

## 작업 흐름
1. `feat|fix|chore/<요약>` 브랜치에서 작업한다. main 에 직접 커밋·push 하지 않는다.
2. 템플릿·스크립트를 바꿨으면 `scripts/test-template.sh` 로 확인한다.
3. `/micro-commit` — **사용자가 지시할 때만.** 목적별 커밋만 한다 (서브에이전트).
4. `/pr [draft]` — **사용자가 지시할 때만.** 마지막 커밋 검증(`verify-head.sh`: 템플릿 테스트·버전 확인·JSON/YAML/셸 문법) + 레포 규칙 리뷰 → PR. 실패·지적이 있으면 멈춘다. PR 에는 CI Claude 리뷰(`.github/workflows/claude-review.yml`)가 같은 기준(`.claude/skills/pr/review-criteria.md`)으로 돌고, 열린 PR 에서 `/pr` 을 다시 실행하면 그 지적도 모은다.
- 커밋 서명 줄은 `Co-Authored-By: Claude Code <noreply@anthropic.com>` 이다.

## 규칙
- 템플릿을 바꾸면 `scripts/test-template.sh` 로 확인한다 (샘플 앱 생성 → `make lint` → `make test`). CI 의 `Template` 워크플로도 같은 스크립트를 쓴다.
- 토큰은 `__APP_NAME__` `__DISPLAY_NAME__` `__BUNDLE_ID__` `__TEAM_ID__` `__OS_VERSION__` 다섯 개뿐이다. 새 토큰을 만들면 `new-app.sh` 의 치환·잔여 검사와 README 를 함께 고친다.
- 플랫폼마다 다른 줄은 `>>> ios` / `>>> macos` 블록으로 감싸고(표시 줄은 생성 시 지워진다), 공통 문장은 플랫폼 중립으로 쓴다. 플랫폼 분기를 바꾸면 `test-template.sh` 의 두 변형이 모두 통과해야 한다.
- 제품마다 다른 내용은 템플릿에 넣지 않고 `<!-- new-ios-app: … -->` 자리 표시로 남겨 스킬이 앱 설명으로 채우게 한다. 자리 표시를 추가·삭제하면 SKILL.md §3 표도 맞춘다.
- `template/docs/harness/` 는 생성된 프로젝트에서 하네스 소유(고치지 않고 업데이트 때 통째로 바뀜)다. 제품마다 다른 내용과 자리 표시는 넣지 않고 프로젝트 소유 문서(`template/docs/PRODUCT.md`·`DEVELOPMENT_PLAN.md`·`CLAUDE.md`)에 둔다 (`new-app.sh` 가 자리 표시가 있으면 실패한다). 하네스 소유 경로를 바꾸면 `update-app.sh` 의 `owned`, `new-app.sh` 의 자리 표시 거부·`CHECKSUMS` 생성, 템플릿 훅·Makefile·CI 의 `docs/harness`, `test-template.sh` 의 업데이트·보호 검사를 함께 고친다.
- 사용자에게 보이는 변경(스킬·스크립트·템플릿)을 배포할 때는 `.claude-plugin/plugin.json` 의 `version` 을 올린다. 설치된 플러그인은 버전이 바뀌어야 갱신된다. main 에 들어오면 `tag-version.yml` 이 `ios-harness--v<version>` 태그를 단다 (`update-app.sh` 가 옛 템플릿을 찾는 기준이라 지우거나 옮기지 않는다).
- `new-app.sh` 의 인자를 바꾸면 `update-app.sh` 가 옛 `new-app.sh` 에도 같은 인자를 넘기므로, 옛 이름(`--ios` 등)은 계속 받는다. `.harness-version` 의 키를 바꾸면 `update-app.sh` 의 읽기도 맞춘다.
- 생성된 프로젝트에서 개선한 하네스(스킬·훅·CI)를 가져올 때는 제품 고유 내용(앱 이름, 제품 약속, 고유 lint 규칙)을 걷어 내고 넣는다.
- 공개 레포다. 팀 ID·개인 번들 ID·비밀값을 넣지 않는다.
