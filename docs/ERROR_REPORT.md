# 에러 리포트 기능 설계

## 목적
사용자 기기에서 에러 발생 시, 디버깅에 필요한 정보를 구조화된 텍스트로 생성하여 공유한다. 네트워크 통신 없이 클립보드 복사만으로 동작한다.

## 리포트 형식

```
=== SpamCall070 에러 리포트 ===

[기기]
모델: iPhone 15 Pro
iOS: 26.3.1
저장공간: 42GB / 128GB

[익스텐션]
활성화: 55 / 58
미활성: Block 042, Block 043, Block 044

[Reload 결과]
성공: 52 / 58
실패:
  Block 007 — loadingInterrupted: 로딩 중단됨
  Block 021 — sqlite:19: SQLITE_CONSTRAINT
  Block 033 — unknown: 알 수 없는 오류
소요: 18분 32초

[앱 상태]
로딩 완료: false
버전: 1.0 (1)
```

## 포함 정보

| 항목 | 소스 | 비고 |
|------|------|------|
| 기기 모델 | `UIDevice.current.model` + `utsname` | iPhone15,3 등 |
| iOS 버전 | `ProcessInfo.processInfo.operatingSystemVersionString` | |
| 저장공간 | `FileManager.default.attributesOfFileSystem` | 남은/전체 |
| 활성화 수 | `ExtensionManager.enabledCount` | |
| 미활성 목록 | enabled 상태 조회 결과에서 추출 | |
| Reload 성공/실패 수 | `ExtensionManager.reloadErrors` | |
| 실패 상세 | 에러 코드 + 메시지 | |
| 소요 시간 | `ExtensionManager.reloadDuration` | |
| 로딩 완료 여부 | `ExtensionManager.isLoaded` | |
| 앱 버전 | `Bundle.main.infoDictionary` | |

## UI

### 위치
실패 섹션 (Step 2에서 에러 발생 시) + 하단 초기화 섹션 근처

### 버튼
"에러 리포트 복사" → 클립보드에 텍스트 복사 → 완료 피드백

### 동작
1. 버튼 탭
2. `ExtensionManager.generateReport()` 호출
3. `UIPasteboard.general.string = report`
4. 버튼 텍스트 일시적으로 "복사됨" 표시 (2초)

## 구현 위치

| 파일 | 변경 내용 |
|------|-----------|
| `SpamCall070/ExtensionManager.swift` | `generateReport() -> String` 메서드 추가 |
| `SpamCall070/ContentView.swift` | 실패 섹션에 "에러 리포트 복사" 버튼 추가 |
