#!/bin/bash
# 생성한 프로젝트의 GitHub 레포 설정을 맞춘다. 여러 번 실행해도 된다.
#   - 머지 방식: Merge commit 만 (마이크로 커밋 hash 를 그대로 남긴다), 머지 후 브랜치 삭제
#   - 유형 라벨 9종 (/pr 스킬이 커밋 type 으로 단다)
#   - main 룰셋: 삭제·force push 금지, PR 필수(merge 만 허용), 필수 체크 ci-result
#   - CLAUDE_CODE_OAUTH_TOKEN 시크릿 확인 (Claude Review 워크플로가 쓴다)
# 사용: setup-github.sh <owner/repo>
set -uo pipefail

repo="${1:?owner/repo 가 필요합니다}"
warnings=()

gh repo edit "$repo" --enable-merge-commit --enable-squash-merge=false --enable-rebase-merge=false \
  --delete-branch-on-merge >/dev/null && echo "✓ 머지 방식: Merge commit 만, 머지 후 브랜치 삭제" ||
  warnings+=("머지 방식 설정 실패")

while IFS='|' read -r name color desc; do
  gh label create "$name" --repo "$repo" --color "$color" --description "$desc" --force >/dev/null ||
    warnings+=("라벨 $name 생성 실패")
done <<'LABELS'
feat|1D76DB|새 기능
fix|D73A4A|버그 수정
refactor|8250DF|동작 변경 없는 구조 개선
test|0E8A16|테스트 추가·보강
build|FBCA04|빌드 도구, Tuist, Makefile
style|BFD4F2|포맷·lint 설정
ci|F9A03F|GitHub Actions, PR 템플릿
docs|0075CA|문서
chore|C5DEF5|하네스(Claude Code, git 훅)
LABELS
echo "✓ 유형 라벨 9종"

# 같은 이름의 룰셋이 있으면 갱신, 없으면 만든다. integration_id 15368 은 GitHub Actions 앱이다.
ruleset=$(
  cat <<'JSON'
{
  "name": "main 보호",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false, "require_last_push_approval": false,
        "required_review_thread_resolution": false, "allowed_merge_methods": ["merge"] } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": false, "do_not_enforce_on_create": false,
        "required_status_checks": [{ "context": "ci-result", "integration_id": 15368 }] } }
  ]
}
JSON
)
existing=$(gh api "repos/$repo/rulesets" --jq '.[] | select(.name == "main 보호") | .id' 2>/dev/null | head -1)
if [[ -n "$existing" ]]; then
  gh api -X PUT "repos/$repo/rulesets/$existing" --input - <<<"$ruleset" >/dev/null
else
  gh api -X POST "repos/$repo/rulesets" --input - <<<"$ruleset" >/dev/null
fi && echo "✓ main 룰셋 (PR 필수 · merge 만 · 필수 체크 ci-result)" ||
  warnings+=("main 룰셋 설정 실패: 비공개 레포는 GitHub Pro 이상에서만 룰셋을 쓸 수 있습니다. 로컬 훅(.githooks, .claude/hooks)이 main 직접 커밋·push 를 막습니다")

if gh secret list --repo "$repo" 2>/dev/null | grep -q '^CLAUDE_CODE_OAUTH_TOKEN'; then
  echo "✓ CLAUDE_CODE_OAUTH_TOKEN 시크릿 있음"
else
  warnings+=("CLAUDE_CODE_OAUTH_TOKEN 시크릿 없음: 'claude setup-token' 으로 토큰을 만든 뒤 'gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo $repo' 로 등록하세요. 없으면 Claude Review 워크플로가 실패합니다")
fi

for w in "${warnings[@]}"; do echo "⚠ $w"; done
exit 0
