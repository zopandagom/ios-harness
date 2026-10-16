# ios-harness 리뷰 기준

`/pr` 의 로컬 리뷰(서브에이전트)와 CI 리뷰(`.github/workflows/claude-review.yml`)가 함께 쓴다. 기준을 바꿀 때는 이 파일만 고친다.
범위는 PR 변경분(`origin/main...HEAD`)이다. `template/` 안의 `CLAUDE.md`·`.claude/`·`docs/` 는 생성될 프로젝트용 문서이고, 이 레포 규칙은 루트 `CLAUDE.md` 다.

## 점검 항목
- **공개 레포**: 팀 ID·개인 번들 ID·이메일·비밀값·로컬 절대 경로가 들어가지 않았는가.
- **제품 고유 내용**: 생성 프로젝트에서 가져온 개선에 앱 이름·제품 약속·제품 전용 lint 규칙·프레임워크(예: Photos·MapKit 전용 규칙)가 남지 않았는가. 제품마다 다른 내용은 `<!-- new-ios-app: … -->` 자리 표시로 남겼는가.
- **토큰**: `__APP_NAME__` `__DISPLAY_NAME__` `__BUNDLE_ID__` `__TEAM_ID__` `__IOS_VERSION__` 외의 토큰이 생겼으면 `scripts/new-app.sh` 의 치환·잔여 검사와 README 가 함께 바뀌었는가.
- **자리 표시**: `new-ios-app:` 자리 표시를 추가·삭제했으면 `skills/new-ios-app/SKILL.md` §3 표가 맞는가.
- **`>>> no-network` 블록**: 새로 네트워크 관련 줄을 넣었다면 블록 안에 있고, `--allow-network` 변형에서 지워져도 문서·설정이 성립하는가.
- **문서 일치**: 바꾼 동작을 설명하는 다른 곳(템플릿 `CLAUDE.md`·`docs/`·`.claude/skills`, README, 루트 `CLAUDE.md`, `skills/new-ios-app/SKILL.md`, 스크립트 주석)이 같은 내용으로 맞춰졌는가. 같은 규칙을 다시 적은 줄(리뷰 스킬·CI 프롬프트)도 핵심 문구로 검색해 본다.
- **생성 프로젝트에서 동작**: 템플릿의 셸 스크립트·훅·워크플로가 토큰 치환 뒤에도 맞는가. `scripts/test-template.sh` 가 거치지 않는 경로(예: Client 모듈, `publish.sh`)가 있으면 그 점을 🟡 로 알린다.
- **플러그인 버전**: `template/`·`scripts/`·`skills/` 를 바꿨으면 `.claude-plugin/plugin.json` 의 `version` 을 올렸는가.

## 심각도
- 🔴 필수: 버그, 위 점검 항목 위반, 실패해도 통과하는 경로(재현을 들 수 있을 때), 바꾼 동작과 다르게 설명하는 문서.
- 🟡 권장: 정상 흐름에서 생기지 않는 드문 경우에만 생기는 문제, 같은 사실을 다르게 쓴 표현 차이, 자동 검증이 거치지 않는 경로, 그 밖의 개선.
- 모든 지적에 발생 조건(어떤 흐름에서, 드문 경우인지)과 영향을 적는다. 확신이 없으면 "확인 필요"로 표시한다.
- 지적하지 않는 것: 변경분 밖에 원래 있던 문제(따로 `범위 밖:` 줄로만 적는다), 취향 차이. 처리(보류·기각)는 리뷰어가 정하지 않는다.
