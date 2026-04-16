#!/usr/bin/env bash
# 서킷 브레이커: 동일 Bash 명령이 5회 연속 실행되면 차단
LOCKDIR="/tmp/spamcall070-circuit"
mkdir -p "$LOCKDIR"

INPUT_HASH=$(echo "$CLAUDE_TOOL_INPUT" | shasum -a 256 | cut -d' ' -f1)
COUNTER_FILE="$LOCKDIR/$INPUT_HASH"

if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
else
  COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# 5분 이상 된 카운터 파일 정리
find "$LOCKDIR" -type f -mmin +5 -delete 2>/dev/null

if [ "$COUNT" -ge 5 ]; then
  rm -f "$COUNTER_FILE"
  echo "BLOCKED: 동일 명령이 5회 반복 감지됨. 접근 방식을 바꿔보세요." >&2
  exit 1
fi
