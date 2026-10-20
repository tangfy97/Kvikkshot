#!/bin/zsh
# Local build: regenerates the Xcode project from project.yml and builds a locally signed
# (sandboxed) copy into build/QuickShots.app. App Store builds go through Xcode → Product → Archive.
set -e
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project QuickShots.xcodeproj -scheme QuickShots -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    -quiet build

rm -rf build/QuickShots.app
cp -R build/DerivedData/Build/Products/Release/QuickShots.app build/
echo "Built build/QuickShots.app"
