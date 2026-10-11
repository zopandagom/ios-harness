#!/bin/bash
# 템플릿이 깨지지 않았는지 확인한다. 로컬과 CI(.github/workflows/template.yml)가 같이 쓴다.
#   1. 네트워크 허용 변형: 생성만 하고 토큰·블록 표시가 남지 않는지, no_network 규칙이 빠졌는지 본다.
#   2. 기본 변형: 생성 → make lint → make test.
# 사용: test-template.sh [작업 디렉터리]   (기본: build/template-test)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="${1:-$root/build/template-test}"
rm -rf "$work"
mkdir -p "$work"

"$root/scripts/new-app.sh" --dest "$work/Networked" --name NetworkedApp --bundle-id com.example.networked --allow-network
if grep -q 'no_network' "$work/Networked/.swiftlint.yml"; then
  echo "FAIL: --allow-network 인데 no_network 규칙이 남았습니다." >&2
  exit 1
fi

"$root/scripts/new-app.sh" --dest "$work/Sample" --name SampleApp --display-name "샘플 앱" \
  --bundle-id com.example.sampleapp --ios 26.0
cd "$work/Sample"
grep -q 'no_network' .swiftlint.yml || { echo "FAIL: 기본 변형에 no_network 규칙이 없습니다." >&2; exit 1; }
git init -q -b main # SwiftFormat·doc-refs 처럼 git 루트를 기준으로 도는 도구를 위해
make lint
make test
echo "PASS: 템플릿 생성 · lint · 빌드 · 테스트"
