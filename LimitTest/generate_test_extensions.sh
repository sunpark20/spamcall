#!/bin/bash
# LimitTest 익스텐션 디렉토리 및 Info.plist 일괄 생성
# Usage: ./generate_test_extensions.sh [count]
# Default: 100개

COUNT=${1:-100}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for i in $(seq 0 $((COUNT - 1))); do
    PADDED=$(printf "%03d" "$i")
    DIR="$SCRIPT_DIR/LimitTestExt${PADDED}"
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

echo "Generated $COUNT extension directories: LimitTestExt000 ~ LimitTestExt$(printf '%03d' $((COUNT - 1)))"
