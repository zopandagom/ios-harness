#!/bin/bash
# template/ 을 복사해 새 iOS 앱 프로젝트를 만들고 토큰을 치환한다. git·GitHub 은 건드리지 않는다 (publish.sh 가 맡는다).
# 사용:
#   new-app.sh --dest <디렉터리> --name <AppName> --bundle-id <com.example.app> \
#     [--display-name <홈 화면 이름>] [--team <팀 ID>] [--ios <최소 버전>] [--allow-network]
# 토큰: __APP_NAME__ __DISPLAY_NAME__ __BUNDLE_ID__ __TEAM_ID__ __IOS_VERSION__
# 블록 표시: ">>> no-network" ~ "<<< no-network" 줄 사이. --allow-network 면 블록을 지우고, 아니면 표시 줄만 지운다.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="" name="" display="" bundle="" team="" ios="26.0" allow_network=0

usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
while (($#)); do
  case "$1" in
    --dest) dest="${2:?}"; shift 2 ;;
    --name) name="${2:?}"; shift 2 ;;
    --display-name) display="${2:?}"; shift 2 ;;
    --bundle-id) bundle="${2:?}"; shift 2 ;;
    --team) team="${2-}"; shift 2 ;;
    --ios) ios="${2:?}"; shift 2 ;;
    --allow-network) allow_network=1; shift ;;
    -h | --help) usage ;;
    *) echo "알 수 없는 인자: $1" >&2; usage ;;
  esac
done
[[ -n "$dest" && -n "$name" && -n "$bundle" ]] || usage
display="${display:-$name}"

fail() { echo "new-app: $1" >&2; exit 1; }
[[ "$name" =~ ^[A-Z][A-Za-z0-9]*$ ]] || fail "--name 은 영문 대문자로 시작하는 PascalCase 여야 합니다 (타깃·타입 이름에 쓰임): $name"
[[ "$bundle" =~ ^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*)+$ ]] || fail "--bundle-id 형식이 올바르지 않습니다: $bundle"
[[ -z "$team" || "$team" =~ ^[A-Z0-9]{10}$ ]] || fail "--team 은 10자리 영문 대문자·숫자입니다: $team"
[[ "$ios" =~ ^[0-9]+\.[0-9]+$ ]] || fail "--ios 는 26.0 같은 형식입니다: $ios"
[[ "$display" != *[\"\\]* ]] || fail "--display-name 에 따옴표나 역슬래시를 쓸 수 없습니다"
if [[ -e "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
  fail "대상 디렉터리가 비어 있지 않습니다: $dest"
fi

mkdir -p "$dest"
cp -R "$root/template/." "$dest/"
cd "$dest"

# 경로에 든 토큰 (깊은 경로부터 바꿔야 상위 디렉터리 이름 변경이 하위 경로를 깨지 않는다)
find . -depth -name '*__APP_NAME__*' | while IFS= read -r path; do
  base=$(basename "$path")
  mv "$path" "$(dirname "$path")/${base//__APP_NAME__/$name}"
done

# 내용의 토큰. 치환 값은 정규식이 아닌 글자 그대로 넣는다.
export APP_NAME="$name" DISPLAY_NAME="$display" BUNDLE_ID="$bundle" TEAM_ID="$team" IOS_VERSION="$ios"
grep -rlI --exclude-dir=.git -e '__[A-Z_]*__' . | while IFS= read -r file; do
  perl -pi -e 's/__APP_NAME__/$ENV{APP_NAME}/g; s/__DISPLAY_NAME__/$ENV{DISPLAY_NAME}/g;
    s/__BUNDLE_ID__/$ENV{BUNDLE_ID}/g; s/__TEAM_ID__/$ENV{TEAM_ID}/g; s/__IOS_VERSION__/$ENV{IOS_VERSION}/g' "$file"
done

# 선택 블록
grep -rlI --exclude-dir=.git -e '>>> no-network' . | while IFS= read -r file; do
  if ((allow_network)); then
    perl -ni -e 'print unless />>> no-network/ .. /<<< no-network/' "$file"
  else
    perl -ni -e 'print unless /(>>>|<<<) no-network/' "$file"
  fi
done

# 어느 하네스 버전에서 만들었는지 남긴다 (나중에 하네스 개선분을 가져올 때 비교 기준)
if git -C "$root" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  version=$(git -C "$root" rev-parse HEAD)
else
  version=$(jq -r '.version' "$root/.claude-plugin/plugin.json")
fi
printf '%s\n' "$version" >.harness-version

left=$(grep -rnI --exclude-dir=.git -E '__(APP_NAME|DISPLAY_NAME|BUNDLE_ID|TEAM_ID|IOS_VERSION)__|(>>>|<<<) no-network' . || true)
[[ -z "$left" ]] || fail "치환되지 않은 토큰이 남았습니다:
$left"

echo "생성 완료: $dest ($name, $bundle, iOS $ios, 네트워크 $( ((allow_network)) && echo 허용 || echo 금지))"
