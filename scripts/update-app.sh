#!/bin/bash
# 이미 만든 프로젝트에 그 뒤의 하네스 변경을 가져온다. 커밋은 하지 않는다 (/ios-harness:update-harness 가 맡는다).
# 사용:
#   update-app.sh <프로젝트> [--from <ref>] [--name <AppName>] [--display-name <표시 이름>] [--bundle-id <번들 ID>]
#     [--platform ios|macos] [--team <팀 ID>] [--os-version <버전>] [--allow-network]
#   값은 프로젝트의 .harness-version 에서 읽고, 인자로 준 값이 우선한다 (옛 한 줄 형식은 인자로 채운다).
# 방법: 만들 때의 하네스(--from, 없으면 commit, 그것도 없으면 태그 ios-harness--v<version>)와 이 하네스로
#   같은 입력의 프로젝트를 각각 만들고, 그 차이를 프로젝트에 3-way 로 합친다 (git cherry-pick --no-commit).
#   프로젝트에서 고친 곳과 하네스 변경이 겹치는 파일만 충돌로 남는다. 두 생성본은 refs/harness/{base,target} 에 둔다.
#   하네스 소유 경로(docs/harness)는 합치지 않고 새 생성본으로 바꾼다.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "update-app: $1" >&2; exit 1; }
usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

(($#)) || usage
[[ "$1" != -* ]] || usage
proj="$(cd "$1" && pwd)" || fail "프로젝트 디렉터리가 없습니다: $1"
shift

# .harness-version: key=value 줄. 옛 형식은 커밋 SHA 나 버전 한 줄이다.
version="" commit="" name="" display="" bundle="" team="" platform="" os_version="" allow_network=""
file="$proj/.harness-version"
[[ -f "$file" ]] || fail ".harness-version 이 없습니다: $file"
if grep -q '=' "$file"; then
  while IFS='=' read -r key value; do
    case "$key" in
      version) version=$value ;; commit) commit=$value ;; name) name=$value ;;
      display_name) display=$value ;; bundle_id) bundle=$value ;; team) team=$value ;;
      platform) platform=$value ;; os_version) os_version=$value ;; allow_network) allow_network=$value ;;
    esac
  done < <(grep -v '^#' "$file")
else
  legacy=$(head -1 "$file")
  if [[ "$legacy" =~ ^[0-9a-f]{40}$ ]]; then commit=$legacy; else version=$legacy; fi
fi

from=""
while (($#)); do
  case "$1" in
    --from) from="${2:?}"; shift 2 ;;
    --name) name="${2:?}"; shift 2 ;;
    --display-name) display="${2:?}"; shift 2 ;;
    --bundle-id) bundle="${2:?}"; shift 2 ;;
    --platform) platform="${2:?}"; shift 2 ;;
    --team) team="${2-}"; shift 2 ;;
    --os-version) os_version="${2:?}"; shift 2 ;;
    --allow-network) allow_network=1; shift ;;
    -h | --help) usage ;;
    *) echo "알 수 없는 인자: $1" >&2; usage ;;
  esac
done
platform=${platform:-ios} allow_network=${allow_network:-0}
[[ -n "$name" && -n "$bundle" && -n "$os_version" ]] ||
  fail "앱 이름·번들 ID·최소 OS 를 알 수 없습니다. 옛 .harness-version 이면 --name --bundle-id --os-version (필요하면 --platform --display-name --team --allow-network) 을 주세요."
display=${display:-$name}

cd "$proj"
git rev-parse -q --verify HEAD >/dev/null || fail "커밋이 있는 git 레포여야 합니다: $proj"
[[ "$(git rev-parse --show-toplevel)" == "$(pwd -P)" ]] || fail "프로젝트 디렉터리가 git 레포의 최상위여야 합니다: $proj"
[[ -z $(git status --porcelain) ]] || fail "커밋되지 않은 변경이 있습니다. 정리한 뒤 다시 실행하세요."

tmp=$(mktemp -d "${TMPDIR:-/tmp}/update-app.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# 만들 때의 하네스 원본. --from 이 없으면 commit, 그다음 버전 태그 순으로 찾는다 (commit 이 push 되지 않았을 수 있다).
# 이 하네스가 git 레포의 최상위이고 그 ref 를 가지면 그대로 쓰고, 아니면 공개 레포에서 받는다.
plugin=$(jq -r .name "$root/.claude-plugin/plugin.json")
if [[ -n "$from" ]]; then
  candidates=("$from")
else
  candidates=()
  [[ -n "$commit" ]] && candidates+=("$commit")
  [[ -n "$version" ]] && candidates+=("$plugin--v$version")
fi
((${#candidates[@]})) || fail ".harness-version 에 버전이 없습니다. --from <ref> 를 주세요."
ref=""
find_ref() { # <git 디렉터리>: candidates 중 처음 있는 것을 ref 에 넣는다
  local c
  for c in "${candidates[@]}"; do
    git -C "$1" cat-file -e "$c^{commit}" 2>/dev/null && { ref=$c; return 0; }
  done
  return 1
}
src="$root"
if ! { [[ "$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" == "$(cd "$root" && pwd -P)" ]] && find_ref "$root"; }; then
  src="$tmp/harness.git"
  git clone -q --bare "$(jq -r .repository "$root/.claude-plugin/plugin.json")" "$src"
  find_ref "$src" || fail "하네스 레포에서 ${candidates[*]} 를 찾을 수 없습니다. --from <커밋 또는 태그> 를 주세요."
fi
mkdir "$tmp/base-harness"
git -C "$src" archive "$ref" | tar -x -C "$tmp/base-harness"

# 같은 입력으로 두 번 만든다. --ios 는 옛 new-app.sh 도 받는 이름이다.
args=(--name "$name" --display-name "$display" --bundle-id "$bundle" --ios "$os_version")
[[ -n "$team" ]] && args+=(--team "$team")
[[ "$platform" == macos ]] && args+=(--platform macos)
((allow_network)) && args+=(--allow-network)
"$tmp/base-harness/scripts/new-app.sh" --dest "$tmp/base" "${args[@]}" >/dev/null
"$root/scripts/new-app.sh" --dest "$tmp/target" "${args[@]}" >/dev/null

# 두 생성본을 부모·자식 커밋으로 만든다.
gen() { git --git-dir="$tmp/gen.git" --work-tree="$1" -c user.name=ios-harness -c user.email=ios-harness@localhost "${@:2}"; }
git init -q --bare "$tmp/gen.git"
gen "$tmp/base" add -A
gen "$tmp/base" commit -q -m "harness base ($ref)"
gen "$tmp/target" add -A
gen "$tmp/target" commit -q --allow-empty -m "harness target"
git fetch -q "$tmp/gen.git" "+HEAD:refs/harness/target"
git update-ref refs/harness/base refs/harness/target^

to=$(jq -r .version "$root/.claude-plugin/plugin.json")
if git diff --quiet refs/harness/base refs/harness/target -- . ':!.harness-version'; then
  cp "$tmp/target/.harness-version" .harness-version
  echo "하네스 변경 없음 ($ref → $to). .harness-version 만 새 형식으로 바꿨다."
  exit 0
fi

# 하네스 변경을 3-way 로 합친다. .harness-version 은 생성 방식에 따라 기록이 달라질 수 있어 새 생성본으로 덮는다.
# 충돌이면 실패 코드로 끝나므로 충돌 파일이 없을 때만 실패로 본다.
if ! out=$(git cherry-pick --no-commit refs/harness/target 2>&1) && [[ -z $(git diff --name-only --diff-filter=U) ]]; then
  fail "하네스 변경을 합치지 못했습니다:
$out"
fi
git cherry-pick --quit 2>/dev/null || true
cp "$tmp/target/.harness-version" .harness-version
git add .harness-version

# 하네스 소유 경로(docs/harness)는 합치지 않고 새 생성본으로 바꾼다. 프로젝트가 그 안이나 하네스에서 없어진 파일을
# 고쳤던 내용은 사라지므로, 그 파일을 알려 프로젝트 문서(docs/PRODUCT.md 등)로 옮기게 한다 (옛 docs/CONVENTIONS.md 등).
owned=docs/harness
moved=$(git diff --name-status --diff-filter=AM refs/harness/base HEAD | while IFS=$'\t' read -r st f; do
  if [[ "$f" == "$owned"/* ]] || { [[ $st == M ]] && ! git cat-file -e "refs/harness/target:$f" 2>/dev/null; }; then echo "$f"; fi
done)
if git cat-file -e "refs/harness/target:$owned" 2>/dev/null; then
  git rm -rq --cached --ignore-unmatch -- "$owned"
  rm -rf "$owned"
  git checkout refs/harness/target -- "$owned"
fi

echo "하네스 $ref → $to"
git diff --stat refs/harness/base refs/harness/target -- . ':!.harness-version' | tail -1
conflicts=$(git diff --name-only --diff-filter=U)
if [[ -n "$conflicts" ]]; then
  echo "충돌 (프로젝트에서 고친 곳과 겹침):"
  sed 's/^/  /' <<<"$conflicts"
else
  echo "충돌 없음"
fi
placeholders=$(git diff refs/harness/base refs/harness/target | grep -E '^\+\+\+ |^\+.*new-ios-app:' | grep -B1 '^+[^+]' | grep -v '^--' || true)
[[ -z "$placeholders" ]] || { echo "하네스가 새로 넣은 자리 표시 (채워야 한다):"; sed 's/^/  /' <<<"$placeholders"; }
[[ -z "$moved" ]] || {
  echo "프로젝트가 고치거나 더했는데 하네스 소유이거나 하네스에서 없어진 파일 (고친 내용: git diff refs/harness/base HEAD -- <파일>. 프로젝트 문서로 옮긴다):"
  sed 's/^/  /' <<<"$moved"
}
echo "하네스 변경만 보기: git diff refs/harness/base refs/harness/target"
