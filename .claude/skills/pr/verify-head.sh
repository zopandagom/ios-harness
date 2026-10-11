#!/bin/bash
# base...HEAD(base 와 갈라진 지점 이후)에서 바뀐 파일을 보고, 마지막 커밋(HEAD) 시점만 한 번 검사한다.
# 중간 커밋은 의미 단위로 나눠 깨질 수 있으므로 검사하지 않는다. /pr 이 push 직전에 실행한다.
# 사용: verify-head.sh [base]   (기본: origin/main)
#   - template/·scripts/·.mise.toml: scripts/test-template.sh (샘플 앱 생성 → lint → 빌드 → 테스트)
#   - template/·scripts/·skills/ 가 바뀌었는데 plugin.json version 이 그대로면: FAIL (설치된 플러그인이 갱신되지 않는다)
#   - *.sh: bash -n, *.json(.claude-plugin·settings.json): jq, 워크플로: YAML 문법
#   - 그 외(README 등)만 바뀌었으면: SKIP
# 작업 트리에서 그대로 실행하므로 커밋되지 않은 변경이 없어야 HEAD 를 검사한 것이 된다.
set -uo pipefail

base="${1:-origin/main}"
cd "$(git rev-parse --show-toplevel)" || exit 1
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "base 를 찾을 수 없습니다: $base (git fetch 필요?)" >&2; exit 1; }
[[ -n $(git rev-list "$base"..HEAD) ]] || { echo "$base..HEAD 에 검증할 커밋이 없습니다." >&2; exit 1; }
[[ -z $(git status --porcelain) ]] || { echo "커밋되지 않은 변경이 있어 HEAD 만 검사할 수 없습니다." >&2; exit 1; }

subject=$(git log -1 --format='%h %s' HEAD)
files=$(git diff --name-only --diff-filter=d "$base"...HEAD)

if grep -Eq '^(template/|scripts/|skills/)' <<<"$files"; then
  old=$(git show "$base:.claude-plugin/plugin.json" 2>/dev/null | jq -r .version)
  new=$(jq -r .version .claude-plugin/plugin.json)
  if [[ "$old" == "$new" ]]; then
    echo "FAIL  $subject (plugin.json version 이 $base 와 같음: $new. 사용자에게 보이는 변경이면 올린다)"
    exit 1
  fi
fi

checks=()
grep -Eq '^(template/|scripts/|\.mise\.toml$)' <<<"$files" && checks+=("scripts/test-template.sh")
while IFS= read -r f; do checks+=("bash -n '$f'"); done < <(grep -E '\.sh$|^template/\.githooks/' <<<"$files")
while IFS= read -r f; do checks+=("jq empty '$f'"); done < <(grep -E '\.json$' <<<"$files" | grep -v '/Contents\.json$')
grep -Eq '(^|/)\.github/workflows/.*\.ya?ml$' <<<"$files" &&
  checks+=("ruby -ryaml -e 'Dir[\".github/workflows/*.y*ml\", \"template/.github/workflows/*.y*ml\"].each { |f| YAML.load_file(f) }'")

if ((${#checks[@]} == 0)); then
  echo "SKIP  $subject (검사할 파일 없음)"
  exit 0
fi

log=$(mktemp "${TMPDIR:-/tmp}/verify-head.XXXXXX")
trap 'rm -f "$log"' EXIT
for check in "${checks[@]}"; do
  if ! bash -c "$check" >>"$log" 2>&1; then
    echo "FAIL  $subject ($check)"
    grep -E 'error|✖|failed|Error|FAIL' "$log" | head -10 | sed 's/^/      /'
    exit 1
  fi
done
echo "PASS  $subject (${checks[*]})"
