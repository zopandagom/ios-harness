#!/bin/bash
# 템플릿이 깨지지 않았는지 확인한다. 로컬과 CI(.github/workflows/template.yml)가 같이 쓴다.
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

"$root/scripts/new-app.sh" --dest "$work/Sample" --name SampleApp --display-name "샘플 앱" \
  --bundle-id com.example.sampleapp --os-version 26.0
grep -q 'no_network' "$work/Sample/.swiftlint.yml" || { echo "FAIL: 기본 변형에 no_network 규칙이 없습니다." >&2; exit 1; }
check "$work/Sample"

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
echo "PASS: 템플릿 생성 · lint · 빌드 · 테스트 (iOS, macOS)"
