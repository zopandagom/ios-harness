#!/bin/bash
# 생성한 프로젝트로 첫 커밋을 만들고 GitHub 레포를 만들어 main 을 push 한 뒤 레포 설정과 git 훅을 연결한다.
# main 에 직접 커밋·push 하는 것은 이 첫 커밋뿐이다. 그래서 git 훅(core.hooksPath)은 push 뒤에 연결한다.
# 사용: publish.sh <프로젝트 디렉터리> <owner/repo> <public|private>
set -euo pipefail

dir="${1:?프로젝트 디렉터리가 필요합니다}"
repo="${2:?owner/repo 가 필요합니다}"
visibility="${3:?public 또는 private}"
[[ "$visibility" == public || "$visibility" == private ]] || { echo "public 또는 private 만 됩니다: $visibility" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
cd "$dir"

if gh repo view "$repo" >/dev/null 2>&1; then
  echo "이미 있는 레포입니다: $repo. 다른 이름을 쓰거나 직접 정리하세요." >&2
  exit 1
fi
[[ -d .git ]] || git init -q -b main
[[ $(git branch --show-current) == main ]] || { echo "main 브랜치가 아닙니다." >&2; exit 1; }
if ! git rev-parse -q --verify HEAD >/dev/null; then
  git add -A
  git commit -q -F - <<'MSG'
chore: ios-harness 템플릿으로 프로젝트 생성

Tuist 모듈러 구조(App · Home Feature · Core), Claude Code 하네스
(.claude 스킬·훅), git 훅, GitHub Actions(CI · Claude Review),
문서(CLAUDE.md, docs/)를 템플릿에서 가져와 앱 정보로 채웠다.
만든 하네스 버전은 .harness-version 에 있다.

Co-Authored-By: Claude Code <noreply@anthropic.com>
MSG
fi

gh repo create "$repo" "--$visibility" --source . --remote origin --push
"$here/setup-github.sh" "$repo"
git config core.hooksPath .githooks
echo "✓ git 훅 연결 (.githooks)"
echo "레포: https://github.com/$repo"
