#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# project.yml이 없으면 xcodegen 프로젝트가 아님 — 스킵
if [ ! -f project.yml ]; then
  echo "SKIP: project.yml 없음 — 빌드 검증 생략"
  exit 0
fi

echo "=== xcodegen generate ==="
xcodegen generate 2>&1

echo "=== xcodebuild: 프로젝트 정합성 확인 ==="
# full build 대신 -showBuildSettings로 xcodeproj 파싱만 검증 (수 초)
xcodebuild -project SpamCall070.xcodeproj \
  -scheme SpamCall070 \
  -destination 'generic/platform=iOS' \
  -showBuildSettings \
  CODE_SIGNING_ALLOWED=NO > /dev/null 2>&1

echo "OK: project.yml → xcodeproj 정합성 확인 완료"
