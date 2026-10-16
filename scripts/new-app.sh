#!/bin/bash
# template/ 을 복사해 새 iOS·macOS 앱 프로젝트를 만들고 토큰을 치환한다. git·GitHub 은 건드리지 않는다 (publish.sh 가 맡는다).
# 사용:
#   new-app.sh --dest <디렉터리> --name <AppName> --bundle-id <com.example.app> [--platform ios|macos] \
#     [--display-name <표시 이름>] [--team <팀 ID>] [--os-version <최소 버전>] [--allow-network]
#   --ios <버전> 은 --os-version 의 이전 이름이다.
# 토큰: __APP_NAME__ __DISPLAY_NAME__ __BUNDLE_ID__ __TEAM_ID__ __OS_VERSION__
# 블록 표시: ">>> <이름>" ~ "<<< <이름>" 줄 사이. 남길 블록은 표시 줄만, 아니면 블록째 지운다.
#   no-network: --allow-network 면 지운다. ios·macos: --platform 과 다른 쪽을 지운다.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="" name="" display="" bundle="" team="" platform="ios" os_version="26.0" allow_network=0

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
while (($#)); do
  case "$1" in
    --dest) dest="${2:?}"; shift 2 ;;
    --name) name="${2:?}"; shift 2 ;;
    --display-name) display="${2:?}"; shift 2 ;;
    --bundle-id) bundle="${2:?}"; shift 2 ;;
    --team) team="${2-}"; shift 2 ;;
    --platform) platform="${2:?}"; shift 2 ;;
    --os-version | --ios) os_version="${2:?}"; shift 2 ;;
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
[[ "$platform" == ios || "$platform" == macos ]] || fail "--platform 은 ios 또는 macos 입니다: $platform"
[[ "$os_version" =~ ^[0-9]+\.[0-9]+$ ]] || fail "--os-version 은 26.0 같은 형식입니다: $os_version"
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
export APP_NAME="$name" DISPLAY_NAME="$display" BUNDLE_ID="$bundle" TEAM_ID="$team" OS_VERSION="$os_version"
grep -rlI --exclude-dir=.git -e '__[A-Z_]*__' . | while IFS= read -r file; do
  perl -pi -e 's/__APP_NAME__/$ENV{APP_NAME}/g; s/__DISPLAY_NAME__/$ENV{DISPLAY_NAME}/g;
    s/__BUNDLE_ID__/$ENV{BUNDLE_ID}/g; s/__TEAM_ID__/$ENV{TEAM_ID}/g; s/__OS_VERSION__/$ENV{OS_VERSION}/g' "$file"
done

# 선택 블록. 표시 뒤에 이름이 이어지는 경우(no-network-x)와 구분하려고 이름 끝을 확인한다.
block() {
  local tag=$1 keep=$2
  export TAG="$tag"
  { grep -rlI --exclude-dir=.git -E ">>> $tag([^A-Za-z0-9-]|$)" . || true; } | while IFS= read -r file; do
    if ((keep)); then
      perl -ni -e 'print unless /(>>>|<<<) \Q$ENV{TAG}\E(?![\w-])/' "$file"
    else
      perl -ni -e 'print unless />>> \Q$ENV{TAG}\E(?![\w-])/ .. /<<< \Q$ENV{TAG}\E(?![\w-])/' "$file"
    fi
  done
}
block no-network $((!allow_network))
block ios $([[ "$platform" == ios ]] && echo 1 || echo 0)
block macos $([[ "$platform" == macos ]] && echo 1 || echo 0)

# 어느 하네스 버전에서 만들었는지 남긴다 (나중에 하네스 개선분을 가져올 때 비교 기준)
if git -C "$root" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  version=$(git -C "$root" rev-parse HEAD)
else
  version=$(jq -r '.version' "$root/.claude-plugin/plugin.json")
fi
printf '%s\n' "$version" >.harness-version

left=$(grep -rnI --exclude-dir=.git -E '__(APP_NAME|DISPLAY_NAME|BUNDLE_ID|TEAM_ID|OS_VERSION)__|(>>>|<<<) (no-network|ios|macos)([^A-Za-z0-9-]|$)' . || true)
[[ -z "$left" ]] || fail "치환되지 않은 토큰이 남았습니다:
$left"

os_label=$([[ "$platform" == ios ]] && echo iOS || echo macOS)
echo "생성 완료: $dest ($name, $bundle, $os_label $os_version, 네트워크 $( ((allow_network)) && echo 허용 || echo 금지))"
