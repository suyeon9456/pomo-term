#!/bin/zsh
# 앱 아이콘(Resources/AppIcon.icns)을 다시 만듦. 아이콘 모양은 Sources/App/AppIconArt.swift
set -e
cd "$(dirname "$0")/.."
ARCHS=arm64 ./build.sh
rm -rf build/AppIcon.iconset
build/Pomo.app/Contents/MacOS/Pomo --icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
echo "✅ 아이콘: $PWD/Resources/AppIcon.icns"
