이 프로젝트의 변경 사항을 리뷰하라.

먼저 다음 문서들을 읽어라:
- `CLAUDE.md`
- `docs/ARCHITECTURE.md`
- `docs/ADR.md`

그런 다음 변경된 파일들을 확인하고, 아래 체크리스트로 검증하라:

## 체크리스트

1. **아키텍처 준수**: ARCHITECTURE.md에 정의된 디렉토리 구조를 따르고 있는가?
2. **기술 스택 준수**: ADR에 정의된 기술 선택을 벗어나지 않았는가?
3. **테스트 가능 범위**: CallKit은 시뮬레이터 미지원이므로, 순수 로직(번호 범위 계산, sliceIndex 파싱 등)의 테스트만 가능하다. 해당 범위의 테스트가 존재하는가? 존재하지 않아도 Fail이 아닌 N/A로 판정하되, 추가 가능성을 비고에 기록하라.
4. **CRITICAL 규칙**: CLAUDE.md의 CRITICAL 규칙을 위반하지 않았는가?
   - 모든 익스텐션이 CallBlockBase 하나를 공유하는가?
   - 차단 번호가 E.164 Int64 오름차순인가?
   - addBlockingEntry 루프에서 힙 할당이 없는가?
5. **빌드 가능**: 아래 명령어가 에러 없이 통과하는가?
   ```bash
   xcodegen generate && xcodebuild build -project SpamCall070.xcodeproj -scheme SpamCall070 -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
   ```

## 출력 형식

| 항목 | 결과 | 비고 |
|------|------|------|
| 아키텍처 준수 | Pass/Fail | {상세} |
| 기술 스택 준수 | Pass/Fail | {상세} |
| 테스트 존재 | Pass/Fail | {상세} |
| CRITICAL 규칙 | Pass/Fail | {상세} |
| 빌드 가능 | Pass/Fail | {상세} |

위반 사항이 있으면 수정 방안을 구체적으로 제시하라.
