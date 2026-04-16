# 아키텍처

## 디렉토리 구조
```
SpamCall070/
├── SpamCall070/                    # 메인 앱 타겟 (SwiftUI Lifecycle)
│   ├── SpamCall070App.swift        # @main SwiftUI 진입점
│   ├── ContentView.swift           # 3단계 설정 UI (유일한 화면)
│   └── ExtensionManager.swift      # 58개 익스텐션 reload/status 관리
├── CallBlockBase/                  # 공유 소스 디렉토리 (빌드 타겟 아님)
│   └── CallDirectoryHandler.swift  # 차단 로직 (모든 익스텐션 타겟의 Compile Sources에 포함)
├── CallBlock000/                   # Extension 타겟 0
│   └── Info.plist
├── CallBlock001/                   # Extension 타겟 1
│   └── Info.plist
├── ...
├── CallBlock057/                   # Extension 타겟 57
│   └── Info.plist
├── LimitTest/                      # Phase 0: 한도 탐색용 별도 프로젝트
│   ├── LimitTestApp/
│   │   ├── LimitTestApp.swift      # @main
│   │   └── ContentView.swift       # K값 설정 + 익스텐션 수 설정 + reload + 상태 표시
│   ├── LimitTestBase/
│   │   └── CallDirectoryHandler.swift  # K값 하드코딩 (1,750,000)
│   ├── LimitTestExt000~057/        # 58개 익스텐션
│   │   └── Info.plist
│   ├── project.yml                 # xcodegen 설정 (58개 익스텐션 포함)
│   └── generate_test_extensions.sh
├── project.yml                     # xcodegen 프로젝트 정의 (메인앱 + 58개 익스텐션)
└── generate_extensions.sh          # 58개 익스텐션 디렉토리/Info.plist 일괄 생성 스크립트
```

### 타겟 구성
| 타겟 | 타입 | 소스 | 번들 ID |
|------|------|------|---------|
| SpamCall070 | iOS Application | SpamCall070/*.swift | com.spamcall070.app |
| CallBlock000 | Call Directory Extension | CallBlockBase/CallDirectoryHandler.swift | com.spamcall070.app.CallBlock000 |
| CallBlock001 | Call Directory Extension | CallBlockBase/CallDirectoryHandler.swift | com.spamcall070.app.CallBlock001 |
| ... | ... | ... | ... |
| CallBlock057 | Call Directory Extension | CallBlockBase/CallDirectoryHandler.swift | com.spamcall070.app.CallBlock057 |

N = 58 (확정). 모든 익스텐션 타겟은 동일한 소스 파일 하나를 컴파일한다. 타겟별로 다른 것은 번들 ID뿐이다.

---

## 패턴: 번들 ID 기반 슬라이스 인덱싱

### 개념
1억개 번호를 K=1,750,000개씩 58개 슬라이스로 분할. 각 익스텐션은 런타임에 자기 번들 ID에서 슬라이스 인덱스를 추출하여 담당 구간을 계산한다.

### 번호 매핑
```
전체 범위: 827,000,000,000 ~ 827,099,999,999 (1억개)

CallBlock000: 827,000,000,000 ~ 827,001,749,999  (175만개)
CallBlock001: 827,001,750,000 ~ 827,003,499,999  (175만개)
CallBlock002: 827,003,500,000 ~ 827,005,249,999  (175만개)
...
CallBlock056: 827,098,000,000 ~ 827,099,749,999  (175만개)
CallBlock057: 827,099,750,000 ~ 827,099,999,999  (25만개, 잔여)
```

58 x 1,750,000 = 101,500,000 >= 100,000,000이므로 전체 커버리지 보장.
마지막 익스텐션의 끝은 `min(start + K, 827,100,000,000)`으로 범위 초과를 방지한다.

### 슬라이스 인덱스 파싱
```
입력: Bundle.main.bundleIdentifier = "com.spamcall070.app.CallBlock042"
1. split(separator: ".") → ["com", "spamcall070", "app", "CallBlock042"]
2. .last → "CallBlock042"
3. replacingOccurrences(of: "CallBlock", with: "") → "042"
4. Int("042") → 42
결과: sliceIndex = 42
```

### 파싱 실패 처리
- `bundleIdentifier`가 nil인 경우 → `cancelRequest(withError:)` 호출
- 접미사가 숫자로 변환 불가한 경우 → `cancelRequest(withError:)` 호출
- 절대 0으로 폴백하지 않음. 잘못된 구간을 등록하는 것보다 명시적 실패가 낫다

### 번호 중복 및 누락 방지 (CRITICAL)

**중복 없음 보장**:
- 각 익스텐션의 구간: `[rangeBase + i*K, rangeBase + (i+1)*K)`
- 구간은 exclusive 범위(`start..<end`)이므로 i번째 끝 = (i+1)번째 시작
- 동일 번호가 두 익스텐션에 등록되는 것은 구조적으로 불가능
- 단, 서로 다른 앱의 익스텐션이 같은 번호를 등록하는 것은 iOS가 허용 (합집합 처리)

**누락 없음 보장**:
- 전체 범위: rangeBase ~ rangeBase + totalNumbers - 1
- 마지막 익스텐션의 end = `min(rangeBase + N*K, rangeBase + totalNumbers)`
- N*K = 58 * 1,750,000 = 101,500,000 >= 100,000,000이므로 모든 번호가 커버됨

**검증 방법 (빌드 타임)**:
```
assert: N * K >= totalNumbers          // 58 * 1,750,000 = 101,500,000 >= 100,000,000
assert: rangeBase + totalNumbers <= 827_100_000_000  // E.164 범위 내
assert: K > 0                          // 양수
assert: N <= 200                       // 실용적 상한 (200개 초과는 UX 파괴)
```

**검증 방법 (런타임)**:
- 각 익스텐션에서 start >= rangeBase + totalNumbers이면 등록할 번호 없음 → completeRequest()로 빈 등록
- 이 경우는 N*K > totalNumbers일 때 마지막 몇 개 익스텐션에서 발생 가능. 에러가 아닌 정상 동작

---

## 컴포넌트 상세

### CallDirectoryHandler (CallBlockBase/CallDirectoryHandler.swift)

CXCallDirectoryProvider를 상속하는 유일한 클래스. 모든 익스텐션 타겟이 공유.

**상수**
| 이름 | 타입 | 값 | 설명 |
|------|------|-----|------|
| `rangeBase` | CXCallDirectoryPhoneNumber (Int64) | 827_000_000_000 | 070-0000-0000의 E.164 |
| `totalNumbers` | CXCallDirectoryPhoneNumber | 100_000_000 | 전체 차단 대상 수 |
| `perExtension` | CXCallDirectoryPhoneNumber | 1_750_000 | 익스텐션당 등록 건수 (확정) |
| `testPhoneNumber` | CXCallDirectoryPhoneNumber | 821_065_728_791 | 010-6572-8791, 차단 테스트용 |

**메서드: beginRequest(with:)**

비증분/증분 분기가 핵심 설계. Settings에서 58개 익스텐션을 켤 때 동시 로딩을 방지한다.

```
1. context.delegate = self
2. sliceIndex 파싱 (실패 시 cancelRequest)
3. if !context.isIncremental:        // 비증분 (Settings 토글 시)
     context.completeRequest()       // 빈 등록으로 즉시 완료 → 동시 로딩 방지
     return
4. // 증분 (앱의 reloadExtension 호출 시) → 슬라이스 등록
5. start = rangeBase + sliceIndex * perExtension
6. end = min(start + perExtension, rangeBase + totalNumbers)
7. start >= end인 경우 → completeRequest() (등록할 번호 없음)
8. if sliceIndex == 0:
     addBlockingEntry(withNextSequentialPhoneNumber: 821_065_728_791)  // 테스트 번호
9. for number in start..<end:
     context.addBlockingEntry(withNextSequentialPhoneNumber: number)
10. context.completeRequest()
```

- 비증분 요청(Settings 토글)은 빈 등록 + `completeRequest()`로 즉시 완료. 58개가 동시에 비증분 로드되어도 각각 즉시 종료하므로 시스템 부하 없음
- 증분 요청(앱의 `reloadExtension` 호출)에서만 실제 번호 등록 수행
- CallBlock000(index==0)에서 테스트 번호(821065728791)를 070 범위 앞에 등록. 821... < 827... 이므로 E.164 오름차순 유지
- 이 번호(010-6572-8791)에서 테스트 iPhone으로 전화를 걸어 차단 동작을 실제 확인

**메모리 특성**
- 루프 내에서 힙 할당 없음. `number`는 Int64 스택 변수
- `addBlockingEntry`는 시스템 내부로 즉시 전달. 앱 측에 누적되지 않음
- 예상 메모리 피크: 익스텐션 기본 오버헤드 + 수 KB

**스레딩**
- `beginRequest`는 시스템이 호출하며, 호출 스레드에서 동기적으로 실행
- 비동기 처리 불필요. 루프가 완료되면 바로 `completeRequest()`

**에러 핸들링: CXCallDirectoryExtensionContextDelegate**
```swift
func requestFailed(for extensionContext: CXCallDirectoryExtensionContext,
                   withError error: any Error) {
    // 시스템이 에러를 기록함. 익스텐션 내에서 추가 처리 불가
    // (UI 없음, 네트워크 없음, 파일 쓰기도 제한적)
}
```
익스텐션은 앱과 직접 통신할 수 없다. 에러는 시스템에 의해 앱의 `reloadExtension` completion handler에 전달된다.

---

### ExtensionManager (SpamCall070/ExtensionManager.swift)

58개 익스텐션의 reload와 상태 조회를 관리하는 `@MainActor` ObservableObject.

**프로퍼티**
| 이름 | 타입 | 설명 |
|------|------|------|
| `extensionCount` | Int (static) | 58 (확정 상수) |
| `maxConcurrent` | Int (static) | 1 (순차 reload 확정) |
| `bundleIDs` | [String] | 58개 번들 ID 배열 (`com.spamcall070.app.CallBlock000`~`057`) |
| `enabledCount` | Int (@Published) | Settings에서 활성화된 익스텐션 수 |
| `statusChecked` | Bool (@Published) | 상태 조회 완료 여부 |
| `isReloading` | Bool (@Published) | reload 진행 중 여부 |
| `reloadProgress` | Int (@Published) | reload 완료된 익스텐션 수 |
| `reloadCurrent` | String (@Published) | 현재 로딩 중인 익스텐션 접미사 (예: "042") |
| `reloadErrors` | [(id: String, code: String, message: String)] (@Published) | 실패한 익스텐션의 에러 목록 |
| `reloadDuration` | TimeInterval (@Published) | reload 소요 시간 |
| `isLoaded` | Bool (@Published) | 로딩 완료 여부 (UserDefaults `reloadCompleted`에 저장) |

**메서드: reloadAll()**
```
1. guard !isReloading (중복 실행 방지)
2. isReloading = true, reloadProgress = 0, reloadErrors 초기화
3. startTime 기록
4. TaskGroup으로 순차 reload (maxConcurrent = 1):
   - pending 큐에서 1개씩 꺼내 reloadExtension 호출
   - 완료 시 running -= 1, reloadProgress += 1
   - 에러 시 describeError()로 한국어 메시지 변환 후 reloadErrors에 추가
   - 다음 1개 시작
5. 전체 완료 후:
   - reloadDuration = 경과 시간
   - isReloading = false
   - 에러 없으면 UserDefaults에 reloadCompleted=true, reloadDuration 저장
   - refreshStatuses() 호출
```

**순차 reload 전략 (maxConcurrent = 1) — 확정**

Phase 0 테스트 결과로 확정된 전략:
- 병렬 5개 → SQLite lock 경합으로 36분 + 3개 실패
- 병렬 2개 → 시간 단축 효과 없음 (16분 32초)
- 순차 1개 → 16분, 0 실패

병렬 실행은 시스템 내부 SQLite DB의 lock 경합으로 인해 오히려 느려지고 실패율이 높아진다.
1개씩 순차 실행이 가장 빠르고 안정적이다.

**에러 핸들링**
- 개별 익스텐션 reload 실패 시 나머지 계속 진행 (fail-fast 아님)
- 모든 reload 완료 후 실패 목록을 UI에 표시

**메서드: reloadFailed()**
```
1. reloadErrors에서 실패한 ID 목록 추출
2. guard !failedIDs.isEmpty, !isReloading
3. isReloading = true, reloadProgress = 0, reloadErrors 초기화
4. 실패 항목만 순차 재시도 (for loop)
5. 완료 후 에러 없으면 UserDefaults에 저장
6. refreshStatuses() 호출
```

**메서드: describeError(_:)**

에러 코드별 한국어 메시지 매핑:

*CallKit 에러 도메인: `com.apple.CallKit.error.calldirectorymanager`*
| 코드 | 이름 | 메시지 |
|------|------|--------|
| 0 | unknown | 알 수 없는 오류. 기기를 재시작해 보세요. |
| 1 | noExtensionFound | 익스텐션을 찾을 수 없음. 앱을 재설치해 주세요. |
| 2 | loadingInterrupted | 로딩 중단됨. 다시 시도해 주세요. |
| 3 | entriesOutOfOrder | 내부 오류 (번호 순서). 개발자에게 문의해 주세요. |
| 4 | duplicateEntries | 내부 오류 (중복). 개발자에게 문의해 주세요. |
| 5 | maximumEntriesExceeded | 등록 한도 초과. 개발자에게 문의해 주세요. |
| 6 | extensionDisabled | 설정에서 꺼져 있습니다. 설정에서 켜주세요. |
| 7 | currentlyLoading | 이미 로딩 중. 잠시 후 다시 시도해 주세요. |
| 8 | unexpectedIncrementalRemoval | 설정에서 OFF→ON 후 다시 시도해 주세요. |

*기타 도메인*: `domain:code` 형태로 표시 (예: SQLite 에러 `com.apple.callkit.database.sqlite:19` = CONSTRAINT)

**메서드: refreshStatuses()**
```
1. statusChecked = false, enabledCount = 0
2. 10개씩 배치로 병렬 조회:
   for batch in stride(from: 0, to: 58, by: 10):
     withTaskGroup:
       getEnabledStatusForExtension() x 10 (병렬)
       status == .enabled이면 count += 1
     enabledCount = count (배치마다 갱신)
3. statusChecked = true
```
- enabledCount만 카운트 (개별 상태 매핑 없음)
- 에러 발생 시 해당 익스텐션은 비활성으로 간주 (false 반환)

**메서드: markAsLoaded()**
- isLoaded = true, UserDefaults에 저장

**메서드: resetState()**
- reloadProgress, reloadErrors, reloadDuration, isLoaded 초기화
- UserDefaults에서 `reloadCompleted`, `reloadDuration` 제거

---

### ContentView (SpamCall070/ContentView.swift)

유일한 화면. 3단계 설정 플로우:

```
┌────────────────────────────────┐
│  Step 1: 설정에서 58개 ON 하기  │
│                                │
│  [전화 차단 및 발신자 확인 열기] │
│  48 / 58개 활성화               │
│                                │
│  설정 > 앱 > 전화 >             │
│  전화 차단 및 발신자 확인        │
│  iOS 26: 목록 가장 아래쪽에 있음 │
│  10개 ON 후 10초 대기 반복       │
│                                │
│  Step 2: 1억건 로딩 시작하기     │
│                                │
│  [로딩 시작하기 (20분 소요)]     │
│  창을 유지해야 합니다            │
│                                │
│  Step 3:                        │
│  070-XXXX-XXXX 1억건 차단됨     │
│  영구 유지됩니다                 │
│  소요 시간: 16분 00초            │
│                                │
│  ─── 초기화 ──────────────────  │
│  [결과 초기화]                   │
│  문제 시: 앱 삭제 → 기기 재시작  │
│  → 앱 재설치                    │
└────────────────────────────────┘
```

**Step 1: 설정에서 58개 ON 하기**
- `enabledCount / 58개 활성화` 표시
- 전체 활성화 시 체크마크 아이콘
- Settings 딥링크 버튼
- 로딩 중에는 "전화 차단 및 발신자 확인 메뉴가 일시적으로 사라집니다" 경고 (주황)
- 미활성 시 안내: "10개 ON 후 10초 대기를 반복"
- `#available(iOS 26, *)`: "iOS 26: 목록 가장 아래쪽에 있습니다" 표시

**Step 2: 1억건 로딩 시작하기**
- 로딩 중: ProgressView + "Block XXX 로딩 중..." + 진행률 바 + "X / 58 완료"
- 실패 시: "N개 실패" + [실패 항목 재시도] 버튼 (빨간색)
- 대기 중: [로딩 시작하기 (20분 소요)] 버튼 (allEnabled && !reloadDone일 때 활성)
- 안내: "창을 유지해야 합니다. 중간에 전화 등으로 끊길 시 다시 눌러주세요."

**Step 3: 완료**
- "070-XXXX-XXXX 1억건이 차단되었습니다." (초록)
- "영구 유지됩니다. 앱을 삭제하지 않는 한 계속 차단됩니다."
- "소요 시간: X분 Y초"

**실패 상세 섹션**
- reloadDuration > 0 && reloadErrors 비어있지 않을 때 표시
- 각 실패 항목: "Block XXX" + 한국어 에러 메시지

**초기화 섹션**
- [결과 초기화] 버튼 (빨간 텍스트)
- "문제가 생기면 앱 삭제 → 기기 재시작 → 앱 재설치 순서로 진행하세요."

**Settings 딥링크 전략**

`openCallBlockingSettings()`에서 URL 후보를 순서대로 시도, 첫 번째 성공하는 URL 사용:
```
1. App-prefs:com.apple.mobilephone&path=CALL_BLOCKING_AND_IDENTIFICATION
2. App-prefs:com.apple.mobilephone
3. prefs:root=Apps&path=com.apple.mobilephone
4. App-prefs:Phone&path=CALL_BLOCKING_AND_IDENTIFICATION
5. App-prefs:Phone
6. prefs:root=Phone
```
iOS 버전마다 지원되는 URL이 다르므로 후보 목록으로 대응한다.

**앱 라이프사이클 처리**
- `onAppear`: `refreshStatuses()` 호출
- `scenePhase` 변경 감지: `.active`로 전환될 때마다 `refreshStatuses()` 호출
- 사용자가 Settings에서 토글을 변경하고 앱으로 돌아왔을 때 상태 갱신

---

## 데이터 흐름

### Reload 시퀀스
```
[사용자] 로딩 시작 버튼 탭
  → [ContentView] extensionManager.reloadAll()
    → [ExtensionManager] isReloading = true
      → [TaskGroup] 순차 실행 (maxConcurrent = 1)
        → [CXCallDirectoryManager] reloadExtension(withIdentifier: "...CallBlock000")
          → [iOS] CallBlock000 프로세스 시작
            → [CallDirectoryHandler] beginRequest(with:)
              → context.isIncremental == true (앱의 reloadExtension 호출이므로)
              → sliceIndex 파싱: 0
              → start = 827,000,000,000
              → end = 827,001,750,000
              → addBlockingEntry(821,065,728,791)  // 테스트 번호
              → for number in start..<end:
                   addBlockingEntry(withNextSequentialPhoneNumber: number)
              → completeRequest()
            → [iOS] 번호를 시스템 DB에 저장
          → [iOS] CallBlock000 프로세스 종료
        → [CXCallDirectoryManager] completion(nil)  // 성공
        → [ExtensionManager] reloadProgress += 1
        
        → [CXCallDirectoryManager] reloadExtension(withIdentifier: "...CallBlock001")
          → ... (동일 흐름, 테스트 번호 없음)
        
        → ... (58개 순차 반복)
      
      → [ExtensionManager] reloadDuration 기록
      → [ExtensionManager] isReloading = false
      → [ExtensionManager] UserDefaults에 reloadCompleted, reloadDuration 저장
      → [ExtensionManager] refreshStatuses()
    → [ContentView] UI 갱신 → Step 3 표시
```

### Settings 토글 시퀀스 (비증분)
```
[사용자] Settings > 전화 차단 및 발신자 확인 > CallBlock000 ON
  → [iOS] CallBlock000 프로세스 시작
    → [CallDirectoryHandler] beginRequest(with:)
      → context.isIncremental == false
      → completeRequest()  // 즉시 완료, 번호 등록 안 함
    → [iOS] CallBlock000 프로세스 종료
```
58개 익스텐션을 한꺼번에 켜도 각각 즉시 완료하므로 시스템 부하 없음.

### 에러 전파 경로
```
[CallDirectoryHandler] addBlockingEntry 에러 발생
  → context.cancelRequest(withError:) 또는 시스템이 프로세스 종료
    → [CXCallDirectoryManager] completion(error)
      → [ExtensionManager] describeError() → 한국어 메시지 변환
        → reloadErrors.append((id, code, message))
          → [ContentView] 실패 목록 표시 + 재시도 버튼
```

### 상태 조회 시퀀스
```
[사용자] 앱 실행 또는 포그라운드 복귀
  → [ContentView] .onAppear 또는 .onChange(of: scenePhase)
    → [ExtensionManager] refreshStatuses()
      → 10개씩 배치로 병렬 조회
        → [CXCallDirectoryManager] getEnabledStatusForExtension() x 10
          → 각 결과에서 .enabled이면 count += 1
        → enabledCount 갱신 (배치마다)
      → statusChecked = true
    → [ContentView] UI 갱신
```

---

## 상태 관리

### 상태 저장 위치
| 상태 | 저장 위치 | 생명주기 |
|------|-----------|----------|
| 익스텐션 활성화 여부 | iOS 시스템 | 앱 삭제 시까지 유지 |
| 차단 번호 목록 | iOS 시스템 DB | reload 시 갱신, 앱 삭제 시 제거 |
| reload 진행 상태 | ExtensionManager @Published | 앱 세션 동안만 유효 |
| 에러 목록 | ExtensionManager @Published | 앱 세션 동안만 유효 |
| 로딩 완료 여부 (isLoaded) | UserDefaults `reloadCompleted` | 앱 삭제 시까지 유지 |
| 로딩 소요 시간 | UserDefaults `reloadDuration` | 앱 삭제 시까지 유지 |

### UserDefaults 사용
- `reloadCompleted` (Bool): reload 성공 시 true. Step 3 완료 표시에 사용
- `reloadDuration` (Double): reload 소요 시간. 앱 재시작 후에도 표시
- `resetState()`로 초기화 가능

### 디스크에 저장하지 않는 항목
- 차단 목록은 고정값 (070 전체 대역). 변하지 않으므로 설정 파일 불필요
- 익스텐션 상태는 시스템 API로 실시간 조회 가능. 캐싱하면 오히려 불일치 위험
- reload 히스토리/에러 로그는 세션 동안만 필요

### LimitTest에서는 App Group 사용
- LimitTest 프로젝트는 Phase 0 테스트를 위해 K값을 런타임에 조절하기 위해 설계되었으나, 최종적으로는 K=1,750,000으로 하드코딩됨
- 본 프로젝트(SpamCall070)에서는 K가 확정된 상수이므로 App Group 불필요

---

## 코드 서명 및 프로비저닝

### 요구사항
- Apple Developer Account (유료, 연 $99)
- App ID 등록: 메인 앱 1개 + 익스텐션 58개 = 총 59개
- 각 App ID에 대한 Provisioning Profile
- 익스텐션의 번들 ID는 반드시 메인 앱 번들 ID의 하위여야 함:
  - 메인 앱: `com.spamcall070.app`
  - 익스텐션: `com.spamcall070.app.CallBlock000` (`.app.` 하위)

### Xcode 자동 서명
- Xcode의 "Automatically manage signing" 사용 권장
- 58개 타겟 각각에 대해 Team 설정 필요
- xcodegen의 `project.yml`에서 `DEVELOPMENT_TEAM` 설정으로 일괄 적용

### 엣지 케이스
- Apple Developer Portal에서 App ID를 59개 수동 등록할 필요 없음 (Xcode 자동 서명이 처리)
- 단, Apple Developer 계정의 App ID 등록 상한은 없음 (확인된 제한 없음)
- 무료 개발자 계정은 익스텐션 타겟 수에 제한이 있을 수 있음 → 유료 계정 필수

---

## 핵심 제약 상세

### 1. E.164 오름차순 등록 (CRITICAL)
- `addBlockingEntry(withNextSequentialPhoneNumber:)`의 "NextSequential"은 이름이 아니라 요구사항
- 이전 호출보다 작거나 같은 번호를 넘기면 → `.entriesOutOfOrder` 에러로 전체 reload 실패
- 우리 구현에서는 `for number in start..<end`의 자연 순서가 오름차순을 보장
- 테스트 번호(821...)는 070 범위(827...) 앞에 등록하므로 오름차순 유지

### 2. 익스텐션당 등록 한도 — per-extension limit (CRITICAL)
- Apple 공식 문서에 명시된 한도는 없음
- **실측: K = 1,750,000 (확정)**
- 200만개에서 실패 확인. 이진 탐색으로 175만이 안정적 상한임을 확정
- 익스텐션당 시간 한도 ~30초, 처리 속도 ~83,000건/초

### 3. 시스템 전체 한도 — system-wide limit (확인됨)
- 모든 익스텐션/앱의 차단 번호 합산에 대한 iOS 시스템 수준의 한도
- **T >= 1억 확인 (Phase 0에서 검증 완료)**
- 58개 익스텐션 x 175만 = 1억 150만개 등록 후 실제 전화 차단 동작 확인됨
- 시스템 전체 한도는 프로젝트 성패를 결정하는 최대 리스크였으나, Phase 0에서 해소됨

### 4. reload 성공 = 차단 동작 (Phase 0에서 확인)
- `reloadExtension` completion에서 error == nil은 "익스텐션이 번호를 시스템에 전달했다"는 의미
- Phase 0에서 1억개 reload 성공 후 실제 070 통화 차단을 확인함
- 010-6572-8791에서 테스트 iPhone으로 전화를 걸어 차단 동작을 검증

### 5. 익스텐션 실행 환경 제약
- 메모리 한도: ~120MB (Extension 공통)
- 실행 시간: Apple 미공개. 실측 ~30초 (175만건 기준)
- 네트워크 접근: 가능하나 사용하지 않음
- 파일 시스템: App Group 컨테이너만 접근 가능 (사용하지 않음)
- UI: 없음

### 6. 시뮬레이터 미지원
- CallKit Call Directory Extension은 시뮬레이터에서 동작하지 않음
- 모든 테스트는 실제 iPhone에서 수행
- Unit Test 가능 범위: sliceIndex 파싱, 범위 계산 로직만

### 7. 시스템 DB 용량 및 수신 전화 매칭
- 1억개 번호 x 8바이트(Int64) = ~800MB (raw data)
- 시스템이 내부적으로 어떻게 저장하는지는 비공개. 인덱스 오버헤드 포함 시 1~2GB 이상 가능
- 기기 저장 공간이 충분해야 함. 저장 공간 부족 시 동작 미보장
- 수신 전화 매칭: 정렬된 데이터의 이진 탐색은 O(log n). 1억개에서 ~27회 비교. 실측에서 체감 지연 없음

### 8. 앱 삭제 후 재부팅 필수
- 앱 삭제 → 재설치 시 기기 재부팅 필수
- 재부팅 안 하면 시스템 DB 정리가 안 되어 등록 실패 가능

---

## 1억개 규모에서의 아키텍처 고려사항

### 총 Reload 시간 (실측)

K=1,750,000, N=58 기준:

| 동시 실행 수 | 소요 시간 | 실패 수 | 비고 |
|:---:|:---:|:---:|:---:|
| 1 (순차) | **~16분 (957초)** | **0** | **채택** |
| 2 | ~16분 32초 | 0 | 시간 단축 효과 없음 |
| 5 | ~36분 | 3 | SQLite lock 경합으로 실패 발생 |

순차 실행이 가장 빠르고 안정적이므로 maxConcurrent = 1로 확정.

### 디바이스 저장 공간 영향

| 총 번호 수 | raw data | 추정 시스템 사용량 | 비고 |
|:---:|:---:|:---:|:---:|
| 2,000만 (기존 앱) | 160MB | ~300~500MB | 기존 앱에서 검증된 수준 |
| 5,000만 | 400MB | ~800MB~1.2GB | |
| 1억 | 800MB | ~1.5~3GB | Phase 0 실측 완료 |

- 사용자에게 "이 앱은 약 X GB의 시스템 저장 공간을 사용합니다" 안내 필요

### 앱 바이너리 크기

| 구성 요소 | 크기 |
|:---:|:---:|
| 메인 앱 (SwiftUI) | ~2~5MB |
| 익스텐션 1개 (공유 소스 컴파일) | ~200~500KB |
| N=58 익스텐션 | ~12~29MB |
| **총 예상** | **~14~34MB** |

- App Store 셀룰러 다운로드 제한 (200MB) 이내
- App Thinning으로 아키텍처별 최적화 후 실제 다운로드 크기는 더 작음
