#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_DISPLAY_NAME="YouTube to Slide"
EXECUTABLE_NAME="YouTubeToSlide"
BUNDLE_ID="com.eidenchoe.youtube-to-slide"
VERSION="2.2.0"
BUILD="11"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

build_app() {
  pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true

  swift build -c release --package-path "$ROOT_DIR"
  BUILD_BINARY="$(swift build -c release --package-path "$ROOT_DIR" --show-bin-path)/$EXECUTABLE_NAME"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$BUILD_BINARY" "$APP_BINARY"
  chmod +x "$APP_BINARY"

  prepare_icon
  write_info_plist
}

prepare_icon() {
  ICON_SOURCE="$ROOT_DIR/icon.icon"
  [[ -e "$ICON_SOURCE" ]] || return 0

  if [[ -d "$ICON_SOURCE" ]]; then
    PACKAGED_ICON="$(find "$ICON_SOURCE/Assets" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.icns' \) | head -n 1 || true)"
    if [[ -z "$PACKAGED_ICON" ]]; then
      echo "warning: icon.icon exists but no supported image was found under icon.icon/Assets" >&2
      return 0
    fi
    ICON_SOURCE="$PACKAGED_ICON"
  fi

  FILE_TYPE="$(/usr/bin/file -b "$ICON_SOURCE" || true)"
  if [[ "$FILE_TYPE" == *"Apple Icon Image"* ]] || [[ "$FILE_TYPE" == *"Mac OS X icon"* ]]; then
    cp "$ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
    return 0
  fi

  if [[ "$FILE_TYPE" == *"PNG image"* ]] || [[ "$FILE_TYPE" == *"JPEG image"* ]]; then
    ICONSET="$DIST_DIR/AppIcon-$$.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"

    /usr/bin/sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
    /usr/bin/sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
    /usr/bin/sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
    /usr/bin/sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
    /usr/bin/sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
    /usr/bin/sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    /usr/bin/sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
    /usr/bin/sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    /usr/bin/sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
    /usr/bin/sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    /usr/bin/iconutil -c icns "$ICONSET" -o "$APP_RESOURCES/AppIcon.icns"
    rm -rf "$ICONSET"
    return 0
  fi

  echo "warning: icon.icon exists but is not an icns/png/jpeg file: $FILE_TYPE" >&2
}

write_info_plist() {
  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    build_app
    open_app
    ;;
  --build-only|build)
    build_app
    ;;
  --debug|debug)
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    build_app
    open_app
    sleep 2
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
