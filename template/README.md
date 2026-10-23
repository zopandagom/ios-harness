# __DISPLAY_NAME__

<!-- new-ios-app: 앱 설명 한두 문장과 핵심 약속을 적고 이 주석을 지운다 -->

## 핵심 기능 (MVP)
<!-- new-ios-app: DEVELOPMENT_PLAN 의 MVP 기능을 목록으로 요약하고 이 주석을 지운다 -->

## 기술 스택
<!-- >>> ios -->
- SwiftUI (규칙 기반 단방향 MV), Swift 6 strict concurrency, iOS __OS_VERSION__+ (iPhone)
<!-- <<< ios -->
<!-- >>> macos -->
- SwiftUI (규칙 기반 단방향 MV), Swift 6 strict concurrency, macOS __OS_VERSION__+
<!-- <<< macos -->
- Tuist 모듈러 아키텍처 (Feature / Client Interface·Impl·Testing / Shared)
<!-- new-ios-app: 앱이 쓸 Apple 프레임워크를 줄로 추가하고 이 주석을 지운다 -->

## 시작하기
```bash
make bootstrap   # mise 로 tuist·swiftlint·swiftformat·xcbeautify 설치, git 훅(pre-commit: main 커밋 차단·lint, pre-merge-commit: main 머지 커밋 차단, pre-push: main push 차단) 연결
make generate    # __APP_NAME__.xcworkspace 생성 후 Xcode 로 열기
make test        # 전체 모듈 빌드 + 테스트 + git 훅 테스트
make test-hooks  # git 훅 동작 테스트만 (임시 레포에서 main 커밋·머지 커밋·push 차단과 기능 브랜치 통과 확인)
make lint        # 포맷·아키텍처 규칙 검사 (make format 으로 자동 수정)
```

## 문서
- [제품 결정: 약속·기술 결정·프로젝트 규칙](docs/PRODUCT.md)
- [아키텍처](docs/harness/ARCHITECTURE.md)
- [개발 규칙: 해야 할 것 / 하지 말아야 할 것](docs/harness/CONVENTIONS.md)
- [개발 계획과 로드맵](docs/DEVELOPMENT_PLAN.md)
- [Claude Code 작업 안내](CLAUDE.md)

이 프로젝트는 [ios-harness](https://github.com/zopandagom/ios-harness) 템플릿으로 만들었다 (`.harness-version`). 하네스 변경은 플러그인을 업데이트한 뒤 `/ios-harness:update-harness` 로 가져온다.
