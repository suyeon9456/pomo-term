#!/bin/zsh
# 배포용 빌드: 유니버설 빌드 → Developer ID 서명 → 공증·스테이플 → DMG·zip (dist/)
# 처음 한 번 해야 하는 준비(인증서, 공증 자격 증명)는 docs/RELEASING.md
#
#   ./scripts/release.sh
#   SIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=pomo-notary ./scripts/release.sh
#
# Developer ID 인증서가 없으면 서명·공증 없이 DMG·zip만 만듦 (받는 사람은 처음에 우클릭 → 열기)
set -e
cd "$(dirname "$0")/.."

NAME=Pomo
VERSION=$(cat VERSION)
APP=build/$NAME.app
OUT=dist
PROFILE=${NOTARY_PROFILE:-pomo-notary}
IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ { print $2; exit }')}

# xcrun이 안 되는 Mac(Xcode 첫 실행 설정 전)에서는 Command Line Tools의 도구를 직접 씀
tool() { xcrun --find "$1" 2>/dev/null || echo "/Library/Developer/CommandLineTools/usr/bin/$1"; }
NOTARYTOOL=$(tool notarytool)
STAPLER=$(tool stapler)

notarize() {
  echo "⏳ 공증 중: $1 (보통 몇 분)"
  "$NOTARYTOOL" submit "$1" --keychain-profile "$PROFILE" --wait
}

rm -rf "$OUT"
mkdir -p "$OUT"

./build.sh

if [[ -n $IDENTITY ]]; then
  echo "🔏 서명: $IDENTITY"
  # Hardened Runtime + 타임스탬프 (공증 필수 조건). 샌드박스 밖 앱이라 따로 쓰는 entitlement는 없음
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"

  # 앱을 먼저 공증해서 zip으로 받는 사람도 오프라인에서 바로 열 수 있게 스테이플
  ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
  notarize "$OUT/notarize.zip"
  rm "$OUT/notarize.zip"
  "$STAPLER" staple "$APP"
else
  echo "⚠️  Developer ID 인증서가 없어 서명·공증 없이 만듦 (docs/RELEASING.md 참고)"
fi

# DMG: 앱 + 응용 프로그램 폴더 바로가기 (끌어다 놓아 설치)
STAGE=build/dmg
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/$NAME-$VERSION.dmg"
hdiutil create -volname "$NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [[ -n $IDENTITY ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  notarize "$DMG"
  "$STAPLER" staple "$DMG"
  spctl --assess --type execute --verbose "$APP"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi

ditto -c -k --keepParent "$APP" "$OUT/$NAME-$VERSION.zip"
(cd "$OUT" && shasum -a 256 *.dmg *.zip > SHA256SUMS.txt)

echo "✅ 배포 파일:"
ls -lh "$OUT"
