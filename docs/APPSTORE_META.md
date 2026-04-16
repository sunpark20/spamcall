# App Store 메타데이터

## 기본 정보
- **앱 이름**: 070 스팸 전화 차단
- **부제**: SPAMCALL BLOCK
- **카테고리**: 유틸리티
- **가격**: 무료
- **연령 등급**: 4+
- **프라이버시 정책 URL**: https://homeninja.vercel.app/privacy/spamcall070

## App Store 설명

```
교대 근무라 낮에 자는데, 벨소리는 꺼둘 수 없습니다.
급한 업무 전화가 올 수 있으니까요.

그런데 스팸 전화가 울립니다.
하나 차단하면 번호를 바꿔서 또 옵니다.
다른 앱을 써도 "스팸 의심" 팝업만 뜰 뿐, 벨은 이미 울린 뒤입니다.
결국 잠에서 깹니다.

그래서 직접 만들었습니다.
iOS 시스템 레벨에서 070 번호 1억개를 통째로 차단합니다.
전화가 아예 도달하지 않습니다. 벨 소리도, 팝업도 없습니다.
직접 쓰니 너무 좋아서, 공유합니다.

[다른 앱과의 차이]
- 차단 방식: 벨이 울린 후 팝업 알림 (타 앱) vs 벨 울리기 전 원천 차단 (이 앱)
- 차단 범위: 신고된 번호 수만개 (타 앱) vs 070 전체 1억개 (이 앱)
- 동작 위치: 앱/서버, 백그라운드 필요 (타 앱) vs iOS 시스템, 배터리 소모 없음 (이 앱)
- 개인정보: 번호 수집 필요 (타 앱) vs 수집 없음 (이 앱)

한 번 설정하면 끝. 앱을 삭제하지 않는 한 영구 유지됩니다.

[사용 방법]
1. 설정 > 앱 > 전화 > 전화 차단 및 발신자 확인에서 58개 항목 모두 켜기
2. 앱에서 '로딩 시작하기' 탭 (약 20분 소요)
3. 완료 — 모든 070 번호가 차단됩니다

[주의사항]
• 모든 070 번호가 차단됩니다. 받고 싶은 070 번호는 연락처에 등록하면 정상 수신됩니다.
• 최초 설정 시 약 20분 소요됩니다. 설정 중 앱을 열어둔 상태로 유지해 주세요.
• 카카오톡, FaceTime 등 인터넷 전화에는 영향 없습니다.
```

## 키워드
070, 스팸차단, 보이스피싱, 전화차단, 스팸전화, 스팸, 차단, VoIP, 인터넷전화, 스팸필터

## 심사 노트 (App Review Notes)

```
This app blocks all 100 million phone numbers in Korea's 070 (VoIP) range using Apple's CallKit Call Directory Extension API.

Technical explanation for 58 extensions:
- iOS CallKit Call Directory Extension has a per-extension limit of approximately 1.75 million entries
- To register 100 million numbers (070-0000-0000 to 070-9999-9999), we need ceil(100M / 1.75M) = 58 extensions
- All 58 extensions share a single source file (CallBlockBase/CallDirectoryHandler.swift). Each extension determines its assigned number range at runtime based on its bundle ID suffix
- This is the same architectural pattern used by "WideProtect", an existing App Store app that uses ~80 extensions to block over 100 million numbers

Why this app is needed:
- Korea's 070 number range is heavily abused for spam calls and voice phishing (vishing)
- Existing solutions (carrier services, other apps) only show a "suspected spam" popup AFTER the phone rings — they cannot prevent the call from reaching the device
- iOS CallKit Call Directory Extension blocks calls at the system level BEFORE they ring, providing true call blocking
- There is no way to block an entire number range on iOS — each number must be registered individually
- This app provides complete coverage of the 070 range, protecting users from all 070-originated spam calls, especially those that disturb sleep

Future plans:
- Custom number range blocking (user-defined patterns)
- Expansion to other commonly spoofed number ranges

Privacy:
- No network communication except optional user-initiated error reports
- No personal data collection
- No access to call content or contacts
- App Store privacy label: "Data Not Collected"
```

## App Store 프라이버시 라벨
- **데이터 수집**: 수집하지 않음
- 단, "에러 신고하기" 버튼 사용 시 기기 모델/iOS 버전/에러 코드만 전송 (사용자 동의 하에)
- 이 경우 "진단" 카테고리에서 "기기 ID", "성능 데이터"를 "앱 기능" 목적으로 선택

## 스크린샷 가이드
- 6.7인치 (iPhone 15 Pro Max 또는 동등) 필수, 최소 1장
- 캡처할 상태:
  1. Step 1 완료 + Step 2 활성 상태 (58/58 ✅ + 로딩 버튼)
  2. Step 3 완료 상태 (070-XXXX-XXXX 1억건 차단됨)
  3. 비교 이미지 (선택): 벨 울리는 타 앱 vs 벨 안 울리는 우리 앱
