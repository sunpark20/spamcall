# 프로젝트: SpamCall070

## 기술 스택
- iOS (최소 지원 버전: iOS 16)
- Swift 5.9+
- CallKit (CXCallDirectoryExtension)
- SwiftUI (메인 앱 UI)
- xcodegen (프로젝트 생성)

## 아키텍처 규칙
- CRITICAL: 모든 익스텐션은 `CallBlockBase/CallDirectoryHandler.swift` 하나를 공유한다. 익스텐션별 코드 복사본을 만들지 말 것
- CRITICAL: 차단 번호는 반드시 E.164 Int64 오름차순으로 등록해야 한다 (CallKit 요구사항)
- CRITICAL: addBlockingEntry 루프에서 힙 할당(Array, String 등)을 하지 말 것. Int64 값 타입만 사용
- 각 익스텐션은 번들 ID 접미사로 자기 담당 번호 구간을 자동 계산한다
- 익스텐션당 등록 건수는 테스트로 확정된 한도 K의 90%로 설정한다

## 개발 프로세스
- 커밋 메시지는 conventional commits 형식을 따를 것 (feat:, fix:, docs:, refactor:)
- 실제 기기 테스트 필수 (시뮬레이터는 CallKit 미지원)

## 명령어
xcodegen generate          # Xcode 프로젝트 생성
xcodebuild build           # 빌드
xcodebuild test            # 테스트
