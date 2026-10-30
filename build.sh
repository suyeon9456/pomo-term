#!/bin/zsh
# PomodoroTodo.app 빌드 스크립트 (Xcode 없이 Command Line Tools의 swiftc로 직접 빌드)
set -e
cd "$(dirname "$0")"

# Xcode가 정상이면 xcrun으로 찾고, 안 되면(Xcode 첫 실행 설정 전 등) Command Line Tools로
CLT=/Library/Developer/CommandLineTools
if SWIFTC=$(xcrun --find swiftc 2>/dev/null) && SDK=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null); then
  :
else
  export DEVELOPER_DIR=$CLT
  SWIFTC=$CLT/usr/bin/swiftc
fi
# Command Line Tools에는 컴파일러보다 새 SDK가 함께 깔려 있을 수 있어서(xcrun은 가장 새 SDK를 고름)
# 컴파일러와 짝이 맞는 기본 링크 MacOSX.sdk를 씀
if [[ $SWIFTC == $CLT/* ]]; then
  SDK=$CLT/SDKs/MacOSX.sdk
fi
APP=build/PomodoroTodo.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

"$SWIFTC" -O -swift-version 5 -sdk "$SDK" -target arm64-apple-macos14.0 \
  -parse-as-library Sources/**/*.swift -o "$APP/Contents/MacOS/PomodoroTodo"

if [ -d Resources ]; then cp -R Resources/ "$APP/Contents/Resources/"; fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PomodoroTodo</string>
  <key>CFBundleDisplayName</key><string>뽀모도로 할 일</string>
  <key>CFBundleIdentifier</key><string>com.local.pomodorotodo</string>
  <key>CFBundleExecutable</key><string>PomodoroTodo</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>ATSApplicationFontsPath</key><string>Fonts</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "✅ 빌드 완료: $PWD/$APP"
