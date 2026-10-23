#!/bin/bash
# 템플릿이 깨지지 않았는지 확인한다. 로컬과 CI(.github/workflows/template.yml)가 같이 쓴다.
#   0. 하네스 업데이트: 사본 하네스로 만든 프로젝트에 다음 버전 변경을 update-app.sh 로 가져온다.
#   1. iOS 기본 변형(네트워크 금지): 생성 → no_network 규칙 확인 → make lint → make test.
#   2. macOS 네트워크 허용 변형: 생성 → no_network 규칙·iOS 블록이 빠졌는지 확인 → make lint → make test.
#   3. 나머지 조합(iOS 네트워크 허용, macOS 네트워크 금지): 생성만 하고 no_network 규칙 유무를 본다.
#      토큰·블록 표시 잔여는 new-app.sh 가 매번 검사한다.
# 사용: test-template.sh [작업 디렉터리]   (기본: build/template-test)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="${1:-$root/build/template-test}"
rm -rf "$work"
mkdir -p "$work"

check() { # <디렉터리>: SwiftFormat·doc-refs 처럼 git 루트를 기준으로 도는 도구를 위해 git init 후 lint·test
  (cd "$1" && git init -q -b main && make lint && make test)
}

# 하네스 업데이트: 하네스 사본(v1)으로 만든 프로젝트를 고친 뒤, 사본을 고쳐(v2) update-app.sh 로 가져온다.
# 프로젝트에서 고친 줄과 하네스에서 고친 줄이 모두 남고 충돌이 없어야 한다.
update_check() {
  local h="$work/harness" p="$work/Updated"
  local g=(git -c user.name=test -c user.email=test@example.com)
  mkdir -p "$h"
  cp -R "$root/template" "$root/scripts" "$root/.claude-plugin" "$h/"
  (cd "$h" && git init -q -b main && git add -A && "${g[@]}" commit -q -m v1)
  "$h/scripts/new-app.sh" --dest "$p" --name UpdatedApp --bundle-id com.example.updated --platform macos >/dev/null
  (cd "$p" && git init -q -b main && git add -A && "${g[@]}" commit -q -m init)
  perl -pi -e 'print "프로젝트 고유 줄\n" if $. == 1' "$p/docs/CONVENTIONS.md" # 하네스는 끝에, 프로젝트는 앞에 고친다
  (cd "$p" && "${g[@]}" commit -q -am project)
  echo "하네스 새 줄" >>"$h/template/docs/CONVENTIONS.md"
  jq '.version = "99.0.0"' "$h/.claude-plugin/plugin.json" >"$h/plugin.json" && mv "$h/plugin.json" "$h/.claude-plugin/plugin.json"
  (cd "$h" && "${g[@]}" commit -q -am v2)
  "$h/scripts/update-app.sh" "$p"
  grep -q '프로젝트 고유 줄' "$p/docs/CONVENTIONS.md" && grep -q '하네스 새 줄' "$p/docs/CONVENTIONS.md" ||
    { echo "FAIL: 업데이트 뒤 프로젝트 줄 또는 하네스 줄이 없습니다." >&2; exit 1; }
  grep -qx 'version=99.0.0' "$p/.harness-version" && grep -qx 'platform=macos' "$p/.harness-version" ||
    { echo "FAIL: .harness-version 이 새 버전·입력으로 바뀌지 않았습니다." >&2; exit 1; }
  [[ -z $(git -C "$p" diff --name-only --diff-filter=U) ]] || { echo "FAIL: 업데이트에 충돌이 남았습니다." >&2; exit 1; }
}
update_check

"$root/scripts/new-app.sh" --dest "$work/Sample" --name SampleApp --display-name "샘플 앱" \
  --bundle-id com.example.sampleapp --os-version 26.0
grep -q 'no_network' "$work/Sample/.swiftlint.yml" || { echo "FAIL: 기본 변형에 no_network 규칙이 없습니다." >&2; exit 1; }
check "$work/Sample"

"$root/scripts/new-app.sh" --dest "$work/MacSample" --name MacSampleApp --bundle-id com.example.macsample \
  --platform macos --allow-network
if grep -q 'no_network' "$work/MacSample/.swiftlint.yml"; then
  echo "FAIL: --allow-network 인데 no_network 규칙이 남았습니다." >&2
  exit 1
fi
if grep -rqI --exclude-dir=.git -E 'iPhone|UILaunchScreen|platform=iOS' "$work/MacSample"; then
  echo "FAIL: macOS 변형에 iOS 블록이 남았습니다." >&2
  exit 1
fi
check "$work/MacSample"

# 생성만 하는 조합. <디렉터리> <no_network 규칙이 있어야 하면 1> <new-app.sh 인자…>
generate_only() {
  local dir=$1 want=$2 has=0
  shift 2
  "$root/scripts/new-app.sh" --dest "$work/$dir" "$@"
  grep -q 'no_network' "$work/$dir/.swiftlint.yml" && has=1
  ((has == want)) || { echo "FAIL: $dir 의 no_network 규칙 유무가 기대($want)와 다릅니다." >&2; exit 1; }
}
generate_only NetworkedIOS 0 --name NetworkedApp --bundle-id com.example.networked --allow-network
generate_only OfflineMac 1 --name OfflineMacApp --bundle-id com.example.offlinemac --platform macos
echo "PASS: 템플릿 생성 · lint · 빌드 · 테스트 (iOS, macOS) + 생성 확인 (iOS 네트워크 허용, macOS 네트워크 금지)"
