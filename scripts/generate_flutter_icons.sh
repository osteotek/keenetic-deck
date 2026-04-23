#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/apps/keenetic_manager_app"
SOURCE_ICON="${ROOT_DIR}/data/icons/hicolor/scalable/apps/ru.toxblh.KeeneticManager.svg"

if [[ ! -f "${SOURCE_ICON}" ]]; then
  echo "Icon source not found: ${SOURCE_ICON}" >&2
  exit 1
fi

if ! command -v qlmanage >/dev/null 2>&1 || ! command -v sips >/dev/null 2>&1; then
  echo "macOS Quick Look tools 'qlmanage' and 'sips' are required." >&2
  exit 1
fi

render_png() {
  local size="$1"
  local output="$2"
  local tmpdir
  local rendered

  tmpdir="$(mktemp -d)"
  mkdir -p "$(dirname "${output}")"
  qlmanage -t -s "${size}" -o "${tmpdir}" "${SOURCE_ICON}" >/dev/null 2>&1
  rendered="${tmpdir}/$(basename "${SOURCE_ICON}").png"

  if [[ ! -f "${rendered}" ]]; then
    echo "Failed to render ${SOURCE_ICON} at ${size}px" >&2
    rm -rf "${tmpdir}"
    exit 1
  fi

  sips -z "${size}" "${size}" "${rendered}" --out "${output}" >/dev/null 2>&1
  rm -rf "${tmpdir}"
}

generate_android_icons() {
  render_png 48  "${APP_DIR}/android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
  render_png 72  "${APP_DIR}/android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
  render_png 96  "${APP_DIR}/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
  render_png 144 "${APP_DIR}/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
  render_png 192 "${APP_DIR}/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
}

generate_ios_icons() {
  render_png 20   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"
  render_png 40   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"
  render_png 60   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"
  render_png 29   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"
  render_png 58   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"
  render_png 87   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"
  render_png 40   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"
  render_png 80   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"
  render_png 120  "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"
  render_png 120  "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"
  render_png 180  "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"
  render_png 76   "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"
  render_png 152  "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"
  render_png 167  "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"
  render_png 1024 "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
}

generate_macos_icons() {
  render_png 16   "${APP_DIR}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png"
  render_png 32   "${APP_DIR}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png"
  render_png 64   "${APP_DIR}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png"
  render_png 128  "${APP_DIR}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png"
  render_png 256  "${APP_DIR}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
  render_png 512  "${APP_DIR}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
  render_png 1024 "${APP_DIR}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
}

generate_android_icons
generate_ios_icons
generate_macos_icons

echo "Generated Flutter launcher icons from source SVG:"
echo "${SOURCE_ICON}"
