# QuickShots

A fast, fully local macOS app for grabbing screenshots from videos and turning them into a share image (contact sheet).

- Drop a video in and screenshots start immediately — by interval (every N seconds) or by count (N evenly spaced shots)
- Fast mode snaps to nearby keyframes; precise mode is exact to the frame
- Export as JPG or PNG, or build a share image with adjustable columns, width, theme, timestamps and video info
- English, English (UK), Simplified Chinese and Traditional Chinese, following the system language
- Sandboxed with no network access; cached screenshots are deleted on Back, on quit, and on the next launch after a crash

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh          # regenerates QuickShots.xcodeproj and builds build/QuickShots.app (signed to run locally)
```

`project.yml` is the source of truth for the Xcode project — edit it rather than the `.xcodeproj`, then run `xcodegen generate`.

For App Store release steps see [APP_STORE.md](APP_STORE.md).
