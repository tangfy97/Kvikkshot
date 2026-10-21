#!/bin/zsh
# Development build: regenerates the Xcode project from project.yml and builds a locally signed
# (sandboxed) copy into build/Kvikkshot.app. For releases see scripts/release.sh (website) and
# scripts/appstore.sh (Mac App Store).
set -e
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project Kvikkshot.xcodeproj -scheme Kvikkshot -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    -quiet build

rm -rf build/Kvikkshot.app
cp -R build/DerivedData/Build/Products/Release/Kvikkshot.app build/
echo "Built build/Kvikkshot.app"
