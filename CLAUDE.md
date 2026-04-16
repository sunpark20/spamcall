# 프로젝트: SpamCall070

## 기술 스택
- iOS (최소 지원 버전: iOS 16)
- Swift 5.9+
- CallKit (CXCallDirectoryExtension)
- SwiftUI (메인 앱 UI)
- xcodegen (프로젝트 생성)

## 확정 파라미터
- K = 1,750,000 (익스텐션당 등록 건수)
- N = 58 (익스텐션 수)
- maxConcurrent = 1 (순차 reload 확정, 병렬 금지)
- 총 등록: 1억 150만, Reload 소요: ~16분

## 아키텍처 규칙
- CRITICAL: 모든 익스텐션은 `CallBlockBase/CallDirectoryHandler.swift` 하나를 공유한다. 익스텐션별 코드 복사본을 만들지 말 것
- CRITICAL: 차단 번호는 반드시 E.164 Int64 오름차순으로 등록해야 한다 (CallKit 요구사항)
- CRITICAL: addBlockingEntry 루프에서 힙 할당(Array, String 등)을 하지 말 것. Int64 값 타입만 사용
- CRITICAL: 익스텐션 reload는 반드시 1개씩 순차 실행. 병렬 시 SQLite lock 경합으로 실패
- 각 익스텐션은 번들 ID 접미사로 자기 담당 번호 구간을 자동 계산한다
- 앱 삭제 → 재설치 시 반드시 기기 재시작 필요 (시스템 DB 정리)

## 개발 프로세스
- 커밋 메시지는 conventional commits 형식을 따를 것 (feat:, fix:, docs:, refactor:)
- 실제 기기 테스트 필수 (시뮬레이터는 CallKit 미지원)

## 명령어
```bash
xcodegen generate          # Xcode 프로젝트 생성 (project.yml → xcodeproj)
xcodebuild build -project SpamCall070.xcodeproj -scheme SpamCall070 -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO   # 빌드 검증
xcodebuild test -project SpamCall070.xcodeproj -scheme SpamCall070 -destination 'platform=iOS Simulator,name=iPhone 16'           # 테스트 (순수 로직만)
python3 scripts/execute.py <phase-dir>          # 하네스 파이프라인 실행
python3 scripts/execute.py <phase-dir> --push   # 실행 후 push
python3 -m pytest scripts/                      # execute.py 단위 테스트
```

## 디버깅 워크플로우
```
에러 발생 → 앱 내 "에러 리포트 복사" → /debug-error + 리포트 붙여넣기
  → 파싱(DEBUG_LOOP.md) → 매칭(KNOWN_ERRORS.md) → 수정 → 빌드 → 사용자 확인
```
- 에러 리포트 형식: [ERROR_REPORT.md](docs/ERROR_REPORT.md)
- 파싱/분석 스킬: `.claude/commands/debug-error.md`
- 에러 패턴 DB: [KNOWN_ERRORS.md](docs/KNOWN_ERRORS.md)
- 전체 루프 설계: [DEBUG_LOOP.md](docs/DEBUG_LOOP.md)

## 참조 문서
- [아키텍처](docs/ARCHITECTURE.md)
- [ADR](docs/ADR.md)
- [PRD](docs/PRD.md)
- [Phase 0 테스트 로그](docs/PHASE0_TEST_LOG.md)
- [알려진 에러 패턴](docs/KNOWN_ERRORS.md)
- [에러 리포트 설계](docs/ERROR_REPORT.md)
- [디버깅 자동화 루프](docs/DEBUG_LOOP.md)
