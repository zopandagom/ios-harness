# 로컬·CI·Claude Code 가 모두 이 타깃을 쓴다. 명령을 바꿀 때는 여기만 고친다.
SHELL := /bin/bash
MISE := mise exec --

WORKSPACE := __APP_NAME__.xcworkspace
SCHEME ?= __APP_NAME__-Workspace
# >>> ios
DESTINATION ?= platform=iOS Simulator,name=iPhone 17,OS=latest
# <<< ios
# >>> macos
DESTINATION ?= platform=macOS,arch=$(shell uname -m)
# <<< macos
RESULT_BUNDLE := build/TestResults.xcresult

.PHONY: bootstrap generate project build test test-hooks lint check-harness-docs format clean

## 최초 1회: 도구 설치 + git 훅 연결
bootstrap:
	mise install
	git config core.hooksPath .githooks

## 워크스페이스를 생성하고 Xcode 로 연다 (사람이 쓰는 타깃)
generate:
	$(MISE) tuist generate

## 생성만 하고 열지 않는다. build·test·CI 는 이 타깃을 거친다
project:
	$(MISE) tuist generate --no-open

BUILD = $(MISE) xcodebuild build -workspace $(WORKSPACE) -scheme $(SCHEME) -destination '$(DESTINATION)' \
	CODE_SIGNING_ALLOWED=NO

## BUILD_LOG=<경로> 를 주면 빌드 로그는 그 파일에 쓰고 종료 코드와 실패 줄(최대 20줄)만 출력한다 (팀 구현의 구현자, CONVENTIONS §6).
## 앞서 도는 project 의 출력은 그대로 나오고, 생성이 실패하면 exit 줄 없이 tuist 오류로 끝난다
build: project
ifdef BUILD_LOG
	@mkdir -p '$(dir $(BUILD_LOG))'; set -o pipefail; $(BUILD) 2>&1 | $(MISE) xcbeautify >'$(BUILD_LOG)' 2>&1; status=$$?; \
		echo "exit $$status"; grep -m 20 -e '❌' -e 'error:' '$(BUILD_LOG)'; exit $$status
else
	set -o pipefail && $(BUILD) | $(MISE) xcbeautify
endif

test: project
	rm -rf $(RESULT_BUNDLE)
	$(MAKE) --no-print-directory test-hooks
	set -o pipefail && $(MISE) xcodebuild test \
		-workspace $(WORKSPACE) -scheme $(SCHEME) -destination '$(DESTINATION)' \
		-resultBundlePath $(RESULT_BUNDLE) \
		CODE_SIGNING_ALLOWED=NO | $(MISE) xcbeautify

## git 훅 동작 테스트: 임시 레포에서 main 커밋·머지 커밋·push 차단과 기능 브랜치 통과 확인 (make test 가 포함)
test-hooks:
	./.githooks/test-hooks.sh

## docs/harness 는 하네스 소유라 생성·업데이트한 그대로여야 한다 (CONVENTIONS §6 "하네스 문서"): 문서(*.md) 내용과 목록이 CHECKSUMS 와 같은지 (.DS_Store 같은 OS 파일은 보지 않는다). CI harness-docs 잡도 같은 파일로 본다
check-harness-docs:
	@cd docs/harness && shasum -a 256 -c --quiet CHECKSUMS && \
		[[ "$$(find . -type f -name '*.md' | LC_ALL=C sort)" == "$$(awk '{print $$2}' CHECKSUMS)" ]] || { echo "docs/harness 는 하네스 소유라 고치지 않습니다. 이 앱의 규칙은 docs/PRODUCT.md 에 쓰고, 되돌리려면 git checkout -- docs/harness" >&2; exit 1; }

lint: check-harness-docs
	$(MISE) swiftformat --lint .
	$(MISE) swiftlint lint --strict --quiet

format:
	$(MISE) swiftformat .
	$(MISE) swiftlint lint --fix --quiet

clean:
	$(MISE) tuist clean
	rm -rf build *.xcworkspace
	find . -path ./.git -prune -o \( -name '*.xcodeproj' -o -name Derived \) -prune -exec rm -rf {} +
