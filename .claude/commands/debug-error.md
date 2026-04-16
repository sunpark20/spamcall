사용자가 에러 리포트를 제공했다. 아래 워크플로우에 따라 분석하고 수정하라.

## 입력

사용자가 붙여넣은 에러 리포트 텍스트 (`docs/ERROR_REPORT.md` 형식).
리포트가 없으면 사용자에게 앱 내 "에러 리포트 복사" 버튼 사용을 안내하라.

$ARGUMENTS

---

## 사전 읽기

반드시 아래 파일들을 먼저 읽어라:
- `docs/KNOWN_ERRORS.md` — 알려진 에러 패턴 DB
- `docs/DEBUG_LOOP.md` — 디버깅 워크플로우 상세 (파싱 규칙, GoNoGo 기준)
- `CLAUDE.md` — CRITICAL 규칙

---

## 워크플로우

### 1. 리포트 파싱

위 텍스트에서 다음 정보를 추출하라:
- `[기기]`: 모델, iOS 버전, 저장공간
- `[익스텐션]`: 활성화 수, 미활성 목록
- `[Reload 결과]`: 성공/실패 수, 실패 상세 (Block 번호, 에러 코드, 메시지), 소요 시간
- `[앱 상태]`: 로딩 완료 여부, 버전

실패 라인 파싱 정규식: `^\s+Block\s+(\d{3})\s+—\s+(.+?):\s+(.+)$`

추출 실패 시 사용자에게 누락된 정보를 직접 요청하라.

### 2. KNOWN_ERRORS.md 매칭

`docs/KNOWN_ERRORS.md`를 읽고 각 에러를 매칭하라:

```
각 실패 항목에 대해:
1. 에러 코드 → KNOWN_ERRORS.md 테이블 조회
2. 매칭 + "코드 수정: 불필요" → 사용자 조치 안내만 (Level 확인)
3. 매칭 + "코드 수정: 필요" → Step 3으로
4. 매칭 실패 → 미지 에러, Step 3으로
```

추가 교차 확인:
- iOS 버전별 에러 시나리오 테이블 확인 (리포트의 iOS 버전 기준)
- 기기별 에러 시나리오 테이블 확인 (저장공간 부족, 구형 기기)
- 복합 에러 시나리오 테이블 확인 (로딩 중 전화, 백그라운드 등)

### 3. 코드 수정 (필요 시)

1. 관련 소스 파일 읽기:
   - `CallBlockBase/CallDirectoryHandler.swift`
   - `SpamCall070/ExtensionManager.swift`
   - `SpamCall070/ContentView.swift`

2. 에러 원인 분석 — 미지 에러는 `docs/DEBUG_LOOP.md`의 "미지 에러 조사 프로토콜" 6단계를 따르라

3. 수정 시 CRITICAL 규칙 반드시 준수:
   - 모든 익스텐션은 `CallBlockBase/CallDirectoryHandler.swift` 하나를 공유
   - 차단 번호는 E.164 Int64 오름차순
   - addBlockingEntry 루프에서 힙 할당 금지 (Int64 값 타입만)
   - 순차 reload (maxConcurrent=1)

4. 빌드 검증:
   ```bash
   xcodegen generate && xcodebuild build -project SpamCall070.xcodeproj -scheme SpamCall070 -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
   ```

5. 미지 에러 해결 시 `docs/KNOWN_ERRORS.md`에 새 패턴 추가:
   - 필수 필드: 에러 코드, 원인, 사용자 조치, 코드 수정, Level, 발견 일자, 발견 기기/iOS
   - `ExtensionManager.describeError()`에 한국어 메시지도 동시 업데이트

### 4. 결과 보고

아래 형식으로 출력하라:

```
## 에러 분석 결과

### 알려진 에러
| 익스텐션 | 에러 | Level | 조치 |
|----------|------|-------|------|

### 코드 수정 내용 (있는 경우)
| 파일 | 변경 | 이유 |
|------|------|------|

### 미지 에러 (있는 경우)
| 익스텐션 | 에러 | 분석 결과 |
|----------|------|-----------|

### 권장 조치
1. (번호순, 구체적 단계로 작성)
```

### 5. 사용자 확인 대기

수정한 코드가 있으면 커밋하지 말고, 사용자에게 실기기 테스트를 요청하라.
- Xcode Run (Cmd+R) → 010-6572-8791로 전화 걸어 차단 확인
- 테스트 통과 확인 후 커밋을 진행한다.

### 6. 루프

사용자가 "여전히 실패"라고 답변하면 Step 3으로 돌아간다.
최대 3회 반복 후에도 실패 시: 앱 삭제 → 기기 재시작 → 앱 재설치를 권장한다.
