# App Store 출시 리소스

## 폴더 구조
```
appstore/
├── README.md              ← 이 파일 (체크리스트)
├── icon/
│   └── AppIcon_1024x1024.png   ← 앱 아이콘 (1024x1024)
└── screenshots/
    ├── comparison_original.png  ← 비교 도표 원본
    └── comparison_6.7inch.png   ← 비교 도표 (1290x2796, App Store용)
```

## 출시 체크리스트

### App Store Connect 입력 항목
| 항목 | 값 | 상태 |
|------|-----|------|
| 앱 이름 | 070 스팸 전화 차단 | ✅ |
| 부제 | SPAMCALL BLOCK | ✅ |
| 카테고리 | 유틸리티 | ✅ |
| 가격 | 무료 | ✅ |
| 프라이버시 URL | https://homeninja.vercel.app/privacy/spamcall070 | ✅ 배포됨 |
| 프라이버시 라벨 | 데이터 수집 없음 | ✅ |
| 설명 | docs/APPSTORE_META.md 참조 | ✅ |
| 키워드 | docs/APPSTORE_META.md 참조 | ✅ |
| 심사 노트 | docs/APPSTORE_META.md 참조 (영문) | ✅ |
| 연령 등급 | 4+ | ✅ |

### 리소스 업로드
| 항목 | 파일 | 상태 |
|------|------|------|
| 앱 아이콘 | icon/AppIcon_1024x1024.png | ✅ 빌드에 포함됨 |
| 스크린샷 6.7인치 (1) | screenshots/comparison_6.7inch.png | ✅ |
| 스크린샷 6.7인치 (2) | 앱 완료 화면 캡처 필요 | ❌ 로딩 후 캡처 |
| 스크린샷 6.5인치 | 6.7인치와 동일 사용 가능 | — |

### 빌드
| 항목 | 상태 |
|------|------|
| Xcode Archive | ✅ |
| App Store Connect 업로드 | 진행 중 |
| 심사 제출 | ❌ 업로드 완료 후 |

### 스크린샷 추가 필요
앱 완료 화면 (Step 3) 스크린샷이 필요합니다:
1. 앱에서 로딩 완료 (실제 16분 로딩 후)
2. Step 3 "070-XXXX-XXXX 1억건이 차단되었습니다" 화면 캡처
3. `appstore/screenshots/` 에 저장
