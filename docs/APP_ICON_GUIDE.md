# App Icon 제작 가이드

## iOS 앱 아이콘 필수 규격
- **크기**: 1024x1024px (정사각형)
- **모서리**: 둥근 모서리 넣지 말 것 — iOS가 자동으로 superellipse 마스크 적용
- **그림자/외곽선**: 아이콘 자체에 넣지 말 것 — 홈 화면에서 이중 그림자가 됨
- **투명 배경**: 불가 — 반드시 불투명 배경 사용

## 이 프로젝트에서 얻은 교훈

### 실패 사례: 3D 버튼 스타일 아이콘
- 원본 이미지에 둥근 테두리 + 그림자 + 3D chrome이 포함되어 있었음
- iOS superellipse 마스크와 겹쳐서 아이콘이 작아 보이고 어색했음
- crop/resize로는 해결 불가 — 원본 자체가 문제

### 성공 사례: 플랫 디자인 아이콘
- Gemini로 재생성: 유리 구슬 안에 전화기 + 방패 (플랫 스타일)
- 콘텐츠가 캔버스의 ~85%를 채우도록 스케일링
- 흰색 배경 사용
- 둥근 테두리/그림자/3D 효과 없음

## AI 이미지 생성 프롬프트 팁 (Gemini)
- "flat design, no rounded corners, no shadow, no border" 명시
- "square 1024x1024 canvas, content fills 85% of the area" 지정
- "solid white background" 또는 원하는 배경색 지정
- 3D chrome, glossy button, drop shadow 등 명시적으로 제외

## 파일 위치
- App Store 제출용 원본: `appstore/icon/AppIcon_1024x1024.png`
- Xcode 에셋: `SpamCall070/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- 두 파일을 항상 동기화할 것

## 현재 아이콘 디자인
- 유리 구슬(glass sphere) 안에 녹색 전화기 + 파란 방패
- 방패가 "SPAM" 빨간 글자를 튕겨내는 형태
- 흰색 배경
