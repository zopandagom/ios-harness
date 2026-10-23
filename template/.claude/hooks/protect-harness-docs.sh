#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit): docs/harness/ 편집을 막는다 (CONVENTIONS §6 "하네스 문서").
# 하네스 소유 문서는 /ios-harness:update-harness 로만 바뀐다. 그 스킬은 셸 스크립트로 쓰므로 이 훅에 걸리지 않는다.
# 막을 때는 exit 2 와 stderr 로 Claude 에게 이유와 쓸 곳을 알린다. 입력을 읽지 못하면 막지 않는다.
input=$(cat)
file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" 2>/dev/null)
root="$CLAUDE_PROJECT_DIR"
[[ -n "$file" && -n "$root" ]] || exit 0
case "$file" in
  "$root"/docs/harness/* | docs/harness/*)
    echo "docs/harness/ 는 하네스 소유 문서라 고치지 않습니다 (CONVENTIONS §6 \"하네스 문서\"). 이 앱의 약속·결정·규칙은 docs/PRODUCT.md 에 쓰고, 하네스 규칙을 바꿔야 하면 사용자에게 보고하세요." >&2
    exit 2
    ;;
esac
exit 0
