# 아키텍처

## 디렉토리 구조
```
SpamCall070/
├── SpamCall070/                    # 메인 앱 타겟 (SwiftUI Lifecycle)
│   ├── SpamCall070App.swift        # @main SwiftUI 진입점
│   ├── ContentView.swift           # 상태 확인 + 설정 안내 (유일한 화면)
│   └── ExtensionManager.swift      # N개 익스텐션 reload/status 관리
├── CallBlockBase/                  # 공유 소스 디렉토리 (빌드 타겟 아님)
│   └── CallDirectoryHandler.swift  # 차단 로직 (모든 익스텐션 타겟의 Compile Sources에 포함)
├── CallBlock000/                   # Extension 타겟 0
│   └── Info.plist
├── CallBlock001/                   # Extension 타겟 1
│   └── Info.plist
├── ...
├── CallBlockNNN/                   # Extension 타겟 N-1
│   └── Info.plist
├── LimitTest/                      # Phase 0: 한도 탐색용 별도 프로젝트
│   ├── LimitTestApp/
│   │   ├── LimitTestApp.swift      # @main
│   │   └── ContentView.swift       # K값 설정 + 익스텐션 수 설정 + reload + 상태 표시
│   ├── LimitTestBase/
│   │   └── CallDirectoryHandler.swift  # K값을 App Group UserDefaults에서 읽어 사용
│   ├── LimitTestExt000~099/        # 최대 100개 익스텐션 (필요한 만큼만 활성화)
│   │   └── Info.plist
│   ├── project.yml                 # xcodegen 설정 (100개 익스텐션 포함)
│   └── generate_test_extensions.sh
├── project.yml                     # xcodegen 프로젝트 정의 (메인앱 + N개 익스텐션)
└── generate_extensions.sh          # N개 익스텐션 디렉토리/Info.plist 일괄 생성 스크립트
```

### 타겟 구성
| 타겟 | 타입 | 소스 | 번들 ID |
|------|------|------|---------|
| SpamCall070 | iOS Application | SpamCall070/*.swift | com.spamcall070.app |
| CallBlock000 | Call Directory Extension | CallBlockBase/CallDirectoryHandler.swift | com.spamcall070.CallBlock000 |
| CallBlock001 | Call Directory Extension | CallBlockBase/CallDirectoryHandler.swift | com.spamcall070.CallBlock001 |
| ... | ... | ... | ... |
| CallBlockNNN | Call Directory Extension | CallBlockBase/CallDirectoryHandler.swift | com.spamcall070.CallBlockNNN |

모든 익스텐션 타겟은 동일한 소스 파일 하나를 컴파일한다. 타겟별로 다른 것은 번들 ID뿐이다.

---

## 패턴: 번들 ID 기반 슬라이스 인덱싱

### 개념
1억개 번호를 K개씩 N개 슬라이스로 분할. 각 익스텐션은 런타임에 자기 번들 ID에서 슬라이스 인덱스를 추출하여 담당 구간을 계산한다.

### 번호 매핑
```
전체 범위: 827,000,000,000 ~ 827,099,999,999 (1억개)

CallBlock000: 827,000,000,000 ~ 827,000,000,000 + K - 1
CallBlock001: 827,000,000,000 + K ~ 827,000,000,000 + 2K - 1
CallBlock002: 827,000,000,000 + 2K ~ 827,000,000,000 + 3K - 1
...
CallBlockN-1: 827,000,000,000 + (N-1)×K ~ 827,099,999,999
```

마지막 익스텐션의 끝은 `min(start + K, 827,100,000,000)`으로 범위 초과를 방지한다.

### 슬라이스 인덱스 파싱
```
입력: Bundle.main.bundleIdentifier = "com.spamcall070.CallBlock042"
1. split(separator: ".") → ["com", "spamcall070", "CallBlock042"]
2. .last → "CallBlock042"
3. replacingOccurrences(of: "CallBlock", with: "") → "042"
4. Int64("042") → 42
결과: sliceIndex = 42
```

### 파싱 실패 처리
- `bundleIdentifier`가 nil인 경우 → `cancelRequest(withError:)` 호출
- 접미사가 숫자로 변환 불가한 경우 → `cancelRequest(withError:)` 호출
- sliceIndex가 유효 범위(0..<N)를 벗어난 경우 → `cancelRequest(withError:)` 호출
- 절대 0으로 폴백하지 않음. 잘못된 구간을 등록하는 것보다 명시적 실패가 낫다

### 번호 중복 및 누락 방지 (CRITICAL)

**중복 없음 보장**:
- 각 익스텐션의 구간: `[rangeBase + i×K, rangeBase + (i+1)×K)`
- 구간은 exclusive 범위(`start..<end`)이므로 i번째 끝 = (i+1)번째 시작
- 동일 번호가 두 익스텐션에 등록되는 것은 구조적으로 불가능
- 단, 서로 다른 앱의 익스텐션이 같은 번호를 등록하는 것은 iOS가 허용 (합집합 처리)

**누락 없음 보장**:
- 전체 범위: rangeBase ~ rangeBase + totalNumbers - 1
- 마지막 익스텐션의 end = `min(rangeBase + N×K, rangeBase + totalNumbers)`
- N×K ≥ totalNumbers이면 모든 번호가 커버됨
- N = ceil(totalNumbers / K)로 계산하므로 N×K ≥ totalNumbers 보장

**검증 방법 (빌드 타임)**:
```
assert: N × K ≥ totalNumbers          // 전체 커버리지
assert: rangeBase + totalNumbers ≤ 827_100_000_000  // E.164 범위 내
assert: K > 0                          // 양수
assert: N ≤ 200                        // 실용적 상한 (200개 초과는 UX 파괴)
```

**검증 방법 (런타임)**:
- 각 익스텐션에서 start >= rangeBase + totalNumbers이면 등록할 번호 없음 → completeRequest()로 빈 등록
- 이 경우는 N×K > totalNumbers일 때 마지막 몇 개 익스텐션에서 발생 가능. 에러가 아닌 정상 동작

---

## 컴포넌트 상세

### CallDirectoryHandler (CallBlockBase/CallDirectoryHandler.swift)

CXCallDirectoryProvider를 상속하는 유일한 클래스. 모든 익스텐션 타겟이 공유.

**상수**
| 이름 | 타입 | 값 | 설명 |
|------|------|-----|------|
| `rangeBase` | CXCallDirectoryPhoneNumber (Int64) | 827_000_000_000 | 070-0000-0000의 E.164 |
| `totalNumbers` | CXCallDirectoryPhoneNumber | 100_000_000 | 전체 차단 대상 수 |
| `perExtension` | CXCallDirectoryPhoneNumber | K (테스트 확정) | 익스텐션당 등록 건수 |

**메서드: beginRequest(with:)** — 본 프로젝트(SpamCall070)
```
1. context.delegate = self
2. sliceIndex 파싱 (실패 시 cancelRequest)
3. start = rangeBase + sliceIndex × perExtension
4. end = min(start + perExtension, rangeBase + totalNumbers)
5. start >= end인 경우 → completeRequest() (등록할 번호 없음)
6. for number in start..<end:
     context.addBlockingEntry(withNextSequentialPhoneNumber: number)
7. context.completeRequest()
```

**메서드: beginRequest(with:)** — LimitTest (Phase 0 테스트)
```
1. context.delegate = self
2. sliceIndex 파싱
3. K를 App Group UserDefaults에서 읽기 (앱에서 설정한 값)
4. start/end 계산
5. if sliceIndex == 0:
     // 테스트 번호를 070 범위 앞에 등록 (821065728791 < 827000000000이므로 오름차순 유지)
     context.addBlockingEntry(withNextSequentialPhoneNumber: 821_065_728_791)
6. for number in start..<end:
     context.addBlockingEntry(withNextSequentialPhoneNumber: number)
7. context.completeRequest()
```
- 010-6572-8791(E.164: 821065728791)은 CallBlock000(sliceIndex==0)에서만 등록
- 이 번호에서 테스트 iPhone으로 전화를 걸어 차단 동작을 실제 확인

**메모리 특성**
- 루프 내에서 힙 할당 없음. `number`는 Int64 스택 변수
- `addBlockingEntry`는 시스템 내부로 즉시 전달. 앱 측에 누적되지 않음
- 예상 메모리 피크: 익스텐션 기본 오버헤드 + 수 KB

**스레딩**
- `beginRequest`는 시스템이 호출하며, 호출 스레드에서 동기적으로 실행
- 비동기 처리 불필요. 루프가 완료되면 바로 `completeRequest()`

**에러 핸들링: CXCallDirectoryExtensionContextDelegate**
```swift
func requestFailed(for context: CXCallDirectoryExtensionContext,
                   withError error: Error) {
    // 시스템이 에러를 기록함. 익스텐션 내에서 추가 처리 불가
    // (UI 없음, 네트워크 없음, 파일 쓰기도 제한적)
}
```
익스텐션은 앱과 직접 통신할 수 없다. 에러는 시스템에 의해 앱의 `reloadExtension` completion handler에 전달된다.

---

### ExtensionManager (SpamCall070/ExtensionManager.swift)

N개 익스텐션의 reload와 상태 조회를 관리하는 ObservableObject.

**프로퍼티**
| 이름 | 타입 | 설명 |
|------|------|------|
| `extensionCount` | Int | 전체 익스텐션 수 N (상수) |
| `bundleIDs` | [String] | N개 익스텐션 번들 ID 배열 |
| `statuses` | [String: ExtensionStatus] | 번들 ID → 상태 매핑 |
| `isReloading` | Bool | reload 진행 중 여부 |
| `reloadProgress` | Int | reload 완료된 익스텐션 수 |
| `reloadErrors` | [String: Error] | 실패한 익스텐션의 에러 |

**ExtensionStatus enum**
```
.enabled    — Settings에서 켜짐 + reload 완료
.disabled   — Settings에서 꺼짐
.unknown    — 상태 조회 실패 또는 미확인
```

**메서드: reloadAll()**
```
1. isReloading = true, reloadProgress = 0, reloadErrors 초기화
2. TaskGroup으로 N개 익스텐션 병렬 reload:
   for id in bundleIDs:
     CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: id)
     - 성공: reloadProgress += 1
     - 실패: reloadErrors[id] = error, reloadProgress += 1
3. 전체 완료 후 isReloading = false
4. refreshStatuses() 호출
```

**병렬 reload 전략**
- N개를 동시에 발사하면 시스템 리소스 과부하 가능
- TaskGroup 내에서 동시 실행 수를 제한 (예: 5개씩)
- 실패한 익스텐션은 전체 완료 후 사용자에게 표시, 개별 재시도 가능

**에러 핸들링**
- 개별 익스텐션 reload 실패 시 나머지 계속 진행 (fail-fast 아님)
- 모든 reload 완료 후 실패 목록을 UI에 표시
- "N개 중 M개 실패" 형태로 요약 + 실패 목록 상세

**메서드: refreshStatuses()**
```
for id in bundleIDs:
  CXCallDirectoryManager.sharedInstance
    .getEnabledStatusForExtension(withIdentifier: id) { status, error in
      if let error:
        statuses[id] = .unknown
      else:
        statuses[id] = (status == .enabled) ? .enabled : .disabled
    }
```
- getEnabledStatusForExtension은 비동기 콜백
- 모든 콜백 완료 후 UI 갱신
- 에러 발생 시 .unknown으로 표시 (크래시 방지)

---

### ContentView (SpamCall070/ContentView.swift)

유일한 화면. 표시 요소:

```
┌────────────────────────────────┐
│         070 차단               │
│                                │
│   ■■■■■■■■■■□□  48/50 활성화    │
│                                │
│   ⚠ 모든 070 번호를 차단하려면   │
│     50개 모두 켜야 합니다        │
│                                │
│   [설정 열기]                   │
│   Settings > 전화 >             │
│   Call Blocking & Identification│
│   에서 모든 항목을 켜세요        │
│                                │
│   [Reload]  12/50 완료          │
│                                │
│   ⚠ 2개 실패:                   │
│   CallBlock023 - 시간 초과       │
│   CallBlock041 - 알 수 없는 오류 │
│   [실패 항목 재시도]             │
└────────────────────────────────┘
```

**UI 상태별 표시**

| 상태 | 표시 |
|------|------|
| 전체 비활성화 (최초 설치) | "0 / N 활성화" + Settings 이동 안내 강조 |
| 부분 활성화 | "M / N 활성화" + 경고 메시지 |
| 전체 활성화 + reload 미실행 | "N / N 활성화" + Reload 버튼 활성 |
| reload 진행 중 | ProgressView + "X / N 완료" + 버튼 비활성화 |
| reload 전체 성공 | "차단 활성화됨" |
| reload 부분 실패 | 실패 목록 + 재시도 버튼 |
| reload 전체 실패 | 에러 메시지 + 재시도 버튼 |

**앱 라이프사이클 처리**
- `scenePhase` 변경 감지: `.active`로 전환될 때마다 `refreshStatuses()` 호출
- 사용자가 Settings에서 토글을 변경하고 앱으로 돌아왔을 때 상태 갱신
- reload 중 앱이 백그라운드로 가면: 진행 중인 reload는 시스템이 계속 처리. 포그라운드 복귀 시 완료 여부 확인

---

## 데이터 흐름

### Reload 시퀀스
```
[사용자] Reload 버튼 탭
  → [ContentView] extensionManager.reloadAll()
    → [ExtensionManager] isReloading = true
      → [TaskGroup] 병렬 실행 (동시 5개 제한)
        → [CXCallDirectoryManager] reloadExtension(withIdentifier: "CallBlock000")
          → [iOS] CallBlock000 프로세스 시작
            → [CallDirectoryHandler] beginRequest(with:)
              → sliceIndex 파싱: 0
              → start = 827,000,000,000
              → end = 827,000,000,000 + K
              → for number in start..<end:
                   addBlockingEntry(withNextSequentialPhoneNumber: number)
              → completeRequest()
            → [iOS] 번호를 시스템 DB에 저장
          → [iOS] CallBlock000 프로세스 종료
        → [CXCallDirectoryManager] completion(nil)  // 성공
        → [ExtensionManager] reloadProgress += 1
        
        → [CXCallDirectoryManager] reloadExtension(withIdentifier: "CallBlock001")
          → ... (동일 흐름)
        
        → ... (N개 반복)
      
      → [ExtensionManager] isReloading = false
      → [ExtensionManager] refreshStatuses()
    → [ContentView] UI 갱신
```

### 에러 전파 경로
```
[CallDirectoryHandler] addBlockingEntry 에러 발생
  → context.cancelRequest(withError:) 또는 시스템이 프로세스 종료
    → [CXCallDirectoryManager] completion(error)
      → [ExtensionManager] reloadErrors[bundleID] = error
        → [ContentView] 에러 목록 표시
```

### 상태 조회 시퀀스
```
[사용자] 앱 실행 또는 포그라운드 복귀
  → [ContentView] .onChange(of: scenePhase)
    → [ExtensionManager] refreshStatuses()
      → [CXCallDirectoryManager] getEnabledStatusForExtension() × N
        → 각 콜백에서 statuses[id] 갱신
      → [ContentView] UI 갱신
```

---

## 상태 관리

### 앱 내 상태 (메모리 only, 디스크 저장 없음)
| 상태 | 저장 위치 | 생명주기 |
|------|-----------|----------|
| 익스텐션 활성화 여부 | iOS 시스템 | 앱 삭제 시까지 유지 |
| 차단 번호 목록 | iOS 시스템 DB | reload 시 갱신, 앱 삭제 시 제거 |
| reload 진행 상태 | ExtensionManager @Published | 앱 세션 동안만 유효 |
| 에러 목록 | ExtensionManager @Published | 앱 세션 동안만 유효 |

### 디스크에 저장하지 않는 이유 (본 프로젝트)
- 차단 목록은 고정값 (070 전체 대역). 변하지 않으므로 설정 파일 불필요
- 익스텐션 상태는 시스템 API로 실시간 조회 가능. 캐싱하면 오히려 불일치 위험
- reload 히스토리/에러 로그는 MVP에서 불필요

### LimitTest에서는 App Group 사용
- LimitTest 프로젝트는 Phase 0-A/B 테스트를 위해 K값을 런타임에 조절해야 함
- 앱에서 K값을 설정 → App Group의 UserDefaults에 저장 → 익스텐션이 읽어서 사용
- 본 프로젝트(SpamCall070)에서는 K가 확정된 상수이므로 App Group 불필요

---

## 코드 서명 및 프로비저닝

### 요구사항
- Apple Developer Account (유료, 연 $99)
- App ID 등록: 메인 앱 1개 + 익스텐션 N개 = 총 N+1개
- 각 App ID에 대한 Provisioning Profile
- 익스텐션의 번들 ID는 반드시 메인 앱 번들 ID의 하위여야 함:
  - 메인 앱: `com.spamcall070.app`
  - 익스텐션: `com.spamcall070.app.CallBlock000` (`.app.` 하위)

### Xcode 자동 서명
- Xcode의 "Automatically manage signing" 사용 권장
- N개 타겟 각각에 대해 Team 설정 필요
- xcodegen의 `project.yml`에서 `DEVELOPMENT_TEAM` 설정으로 일괄 적용

### 엣지 케이스
- Apple Developer Portal에서 App ID를 N+1개 수동 등록할 필요 없음 (Xcode 자동 서명이 처리)
- 단, Apple Developer 계정의 App ID 등록 상한은 없음 (확인된 제한 없음)
- 무료 개발자 계정은 익스텐션 타겟 수에 제한이 있을 수 있음 → 유료 계정 필수

---

## 핵심 제약 상세

### 1. E.164 오름차순 등록 (CRITICAL)
- `addBlockingEntry(withNextSequentialPhoneNumber:)`의 "NextSequential"은 이름이 아니라 요구사항
- 이전 호출보다 작거나 같은 번호를 넘기면 → `.entriesOutOfOrder` 에러로 전체 reload 실패
- 우리 구현에서는 `for number in start..<end`의 자연 순서가 오름차순을 보장

### 2. 익스텐션당 등록 한도 — per-extension limit (CRITICAL)
- Apple 공식 문서에 명시된 한도는 없음
- 실측: 200만개에서 실패 확인. 정확한 한도는 100만~200만 사이
- 기존 앱들은 ~100만개/익스텐션으로 운영 (20개 익스텐션 × 100만 = 2000만)
- 기기/iOS 버전에 따라 달라질 수 있음
- Phase 0 Step 2에서 대상 기기에서 이진 탐색으로 확정

### 3. 시스템 전체 한도 — system-wide limit (CRITICAL, 미검증)
- 모든 익스텐션/앱의 차단 번호 합산에 대한 iOS 시스템 수준의 한도
- **검증된 최대 규모: ~2000만개** (기존 앱들의 운영 실적)
- 1억개는 검증된 적 없는 미답의 영역
- per-extension limit과 별개의 제약이며, 우회할 수 없음
- Phase 0 Step 3~6에서 단계적으로 테스트 (2000만 → 4000만 → 6000만 → 8000만 → 1억)
- **이것이 프로젝트 성패를 결정하는 최대 리스크**

### 4. reload 성공 ≠ 차단 동작 (CRITICAL)
- `reloadExtension` completion에서 error == nil은 "익스텐션이 번호를 시스템에 전달했다"는 의미
- 시스템이 전달받은 번호를 실제 차단 인덱스에 반영했는지는 별개
- 시스템 DB 용량 초과, 인덱스 구축 실패 등의 이유로 reload는 성공했으나 차단이 안 될 수 있음
- **모든 테스트의 최종 판정은 실제 070 통화 차단 여부로만 확인**

### 5. 익스텐션 실행 환경 제약
- 메모리 한도: ~120MB (Extension 공통)
- 실행 시간: Apple 미공개. 경험적으로 수십 초~수 분
- 네트워크 접근: 가능하나 사용하지 않음
- 파일 시스템: App Group 컨테이너만 접근 가능 (사용하지 않음)
- UI: 없음

### 6. 시뮬레이터 미지원
- CallKit Call Directory Extension은 시뮬레이터에서 동작하지 않음
- 모든 테스트는 실제 iPhone에서 수행
- Unit Test 가능 범위: sliceIndex 파싱, 범위 계산 로직만

### 7. 시스템 DB 용량 및 수신 전화 매칭
- 1억개 번호 × 8바이트(Int64) = ~800MB (raw data)
- 시스템이 내부적으로 어떻게 저장하는지는 비공개. 인덱스 오버헤드 포함 시 1~2GB 이상 가능
- 기기 저장 공간이 충분해야 함. 저장 공간 부족 시 동작 미보장
- 수신 전화 매칭: 정렬된 데이터의 이진 탐색은 O(log n). 1억개에서 ~27회 비교. 이론적으로는 즉시
- 실제 성능은 디스크 I/O, 메모리 캐시, 시스템 구현에 의존. 2000만에서 1억으로 5배 증가 시 매칭 지연이 체감될 수 있음
- Phase 0에서 단계별로 매칭 성능을 체감 테스트

---

## 1억개 규모에서의 아키텍처 고려사항

### 총 Reload 시간 예측

K=100만, N=100 기준:

| 동시 실행 수 (M) | 배치 수 | 배치당 시간 | 총 시간 (이론) | 총 시간 (시스템 부하 2배 가정) |
|:---:|:---:|:---:|:---:|:---:|
| 1 | 100 | ~30초 | ~50분 | ~100분 |
| 3 | 34 | ~30초 | ~17분 | ~34분 |
| 5 | 20 | ~30초 | ~10분 | ~20분 |
| 10 | 10 | ~30초 | ~5분 | ~10분 |

- 동시 실행 수를 늘리면 빠르지만, 시스템 리소스 경합으로 개별 실패율 증가
- Phase 0에서 최적 M 값을 탐색 (3, 5, 10으로 테스트)
- 최초 설정 시 사용자가 수십 분 대기해야 할 수 있음 → 앱에서 명확히 안내

### 디바이스 저장 공간 영향

| 총 번호 수 | raw data | 추정 시스템 사용량 | 비고 |
|:---:|:---:|:---:|:---:|
| 2,000만 (기존 앱) | 160MB | ~300~500MB | 기존 앱에서 검증된 수준 |
| 5,000만 | 400MB | ~800MB~1.2GB | |
| 1억 | 800MB | ~1.5~3GB | 추정치. Phase 0에서 실측 |

- Phase 0 각 Step에서 Settings > General > iPhone Storage를 기록하여 실제 저장 공간 소모량 추적
- 사용자에게 "이 앱은 약 X GB의 시스템 저장 공간을 사용합니다" 안내 필요

### 앱 바이너리 크기

| 구성 요소 | 크기 |
|:---:|:---:|
| 메인 앱 (SwiftUI) | ~2~5MB |
| 익스텐션 1개 (공유 소스 컴파일) | ~200~500KB |
| N=100 익스텐션 | ~20~50MB |
| **총 예상** | **~25~55MB** |

- App Store 셀룰러 다운로드 제한 (200MB) 이내
- App Thinning으로 아키텍처별 최적화 후 실제 다운로드 크기는 더 작음
