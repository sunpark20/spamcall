#!/bin/bash
# SpamCall070 익스텐션 디렉토리 및 Info.plist 일괄 생성
# Usage: ./generate_extensions.sh [count]
# Default: 58개 (K=1,750,000 기준 1억개 커버)

COUNT=${1:-58}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for i in $(seq 0 $((COUNT - 1))); do
    PADDED=$(printf "%03d" "$i")
    DIR="$SCRIPT_DIR/CallBlock${PADDED}"
    mkdir -p "$DIR"

    cat > "$DIR/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.callkit.call-directory</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).CallDirectoryHandler</string>
    </dict>
</dict>
</plist>
PLIST_EOF
done

echo "Generated $COUNT extension directories: CallBlock000 ~ CallBlock$(printf '%03d' $((COUNT - 1)))"
