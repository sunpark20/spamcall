# App Store 메타데이터

## 기본 정보
- **앱 이름**: 070 스팸 전화 차단
- **부제**: 최초 1회 설정 · 벨소리도 안울리는
- **카테고리**: 유틸리티
- **가격**: 무료
- **연령 등급**: 4+
- **프라이버시 정책 URL**: https://homeninja.vercel.app/privacy/spamcall070

## App Store 설명

```
070 번호 1억 개를 iOS 시스템 레벨에서 차단합니다.
벨이 울리기 전에 막으므로, 전화 벨소리가 울리지 않습니다.

[설정 안내 — 최초 1회, 약 20분]
이 앱은 1억 개 번호를 58개 구역으로 나누어 등록합니다.
설정 > 전화 > 차단 및 발신자 확인에서 58개 항목을 켜고,
앱에서 로딩을 시작하면 약 20분 후 완료됩니다.
이후에는 별도 조작 없이 영구 동작합니다.

[주의사항]
• 받고 싶은 070 번호는 연락처에 등록하면 정상 수신됩니다
• 설정 중 앱을 열어둔 상태로 유지해 주세요
• 카카오톡, FaceTime 등 인터넷 전화에는 영향 없습니다
```

## 키워드
070, 스팸차단, 보이스피싱, 전화차단, 스팸전화, 스팸, 차단, VoIP, 인터넷전화, 스팸필터

## 심사 노트 (App Review Notes)

```
This app divides the entire 070 (VoIP) number range (100 million numbers) into 58 zones of approximately 1.75 million numbers each. Users can individually toggle each zone on or off based on their own spam call patterns. Numbers saved in the user's contacts are automatically whitelisted regardless of zone settings. The app does not block any numbers by default — all blocking is based on user selection.

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
- Users can selectively block only the zones where they receive spam, while keeping other zones open for legitimate calls

Default behavior:
- On first install, all 58 zones are OFF (no numbers blocked)
- Users must explicitly enable each zone they want to block
- This ensures all blocking is user-initiated and user-controlled

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
- 캡처 순서:

### 1장: 텍스트 설명 카드 (앱 화면 아님)
```
070 스팸 전화,
벨이 울리기 전에 차단합니다.

iOS 시스템 레벨 차단
전화가 아예 도달하지 않습니다

✓ 최초 1회 설정 (약 20분)
✓ 이후 영구 동작, 추가 조작 없음
✓ 배터리 소모 없음
✓ 개인정보 수집 없음
```
배경: 앱 테마 색상, 큰 타이틀 + 체크리스트 형태

### 2장: 앱 메인 화면
- Step 1 완료 + Step 2 활성 상태 (58/58 + 로딩 버튼)

### 3장: 완료 화면
- Step 3 완료 상태 (070-XXXX-XXXX 1억건 차단됨)

### 4장: 비교 이미지 (선택)
- 벨 울리는 타 앱 vs 벨 안 울리는 우리 앱
