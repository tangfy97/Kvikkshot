# Releasing Kvikkshot

Kvikkshot ships two ways from the same code: the **Mac App Store** (the `AppStore` build configuration) and a **download from GitHub**, linked from tang-spark.no (the `Release` configuration, signed with Developer ID and notarized). Both run in the App Sandbox with no network entitlement; they differ only in signing and in the Help menu, where the website build links to its download page to check for a new version.

## Every release

1. Bump `MARKETING_VERSION` (and for the App Store, `CURRENT_PROJECT_VERSION`) in `project.yml`, and add the release to `CHANGELOG.md`.
2. Check everything:
   ```bash
   scripts/preflight.sh
   ```
3. App Store: build, then upload.
   ```bash
   scripts/appstore.sh upload
   ```
4. Website: build, sign, notarize and staple, publish the disk image as a GitHub release, then update the pages (see [WEBSITE.md](WEBSITE.md) for the full commands).
   ```bash
   scripts/release.sh
   gh release create v<version> build/release/Kvikkshot-<version>.{dmg,zip} build/release/SHA256SUMS --repo tangfy97/Kvikkshot --title "Kvikkshot <version>" --target main
   scripts/publish-website.sh ~/Documents/tang-spark.no
   ```

## One-time setup

| What | Status |
|---|---|
| Developer ID Application certificate (Feiyang Tang, X933P26489) | In the login keychain |
| Notarization profile `kvikkshot` | In the keychain; `scripts/release.sh` notarized 1.0.0 |
| App Store distribution signing | Cloud-managed by Xcode |
| Bundle ID `com.feiyangtang.Kvikkshot` | Registered |
| App record | Created: Apple ID 6825502761; build 1.0.0 (1) uploaded and attached |

## App Store Connect

| Field | Value |
|---|---|
| Platform | macOS |
| Bundle ID | `com.feiyangtang.Kvikkshot` |
| Apple ID | 6825502761 |
| SKU | `kvikkshot-macos` |
| Primary language | English (U.S.) |
| Primary category | Photo & Video |
| Secondary category | Utilities |
| Price | Free |
| Availability | 174 countries or regions: everywhere except China mainland, which needs an ICP filing number |
| Age rating | 4+ (no objectionable content) |
| App Privacy | Data Not Collected |
| Export compliance | No encryption (`ITSAppUsesNonExemptEncryption` is false) |
| Copyright | 2026 TangSpark |
| Support URL | https://tang-spark.no/kvikkshot-support.html |
| Marketing URL | https://tang-spark.no/kvikkshot.html |
| Privacy Policy URL | https://tang-spark.no/kvikkshot-support.html#privacy |
| Localizations | English (U.S.), English (U.K.), Chinese (Simplified), Chinese (Traditional) |

### Screenshots

2880 × 1800, in [screenshots/](appstore/screenshots): `en` for both English localizations, `zh-Hans` and `zh-Hant`. Upload 1, 2, 3 in order. The footage is drawn by `scripts/sample-video.swift`, so the studio owns it outright. To redo them after a UI change, see [Screenshots](#remaking-the-screenshots).

### English (U.S.)

**Name** (30): Kvikkshot: Video Screenshots

**Subtitle** (30): Video frames & contact sheets

**Promotional text** (170):
Drop in a video and the screenshots are there before you can look away. Pick the best, export them, or turn them into one image to share. Nothing ever leaves your Mac.

**Keywords** (100):
quickshot,quick shot,frame grab,contact sheet,thumbnail,still,capture,storyboard,mp4,mov,extract

**Description**:

Kvikkshot turns a video into screenshots in a blink, and those screenshots into one image you can share.

Drop a video in and the screenshots are there before you can look away: one every few seconds, or a set number spread evenly across the whole video. Fast mode jumps to the nearest keyframes, so even an hour of 4K takes seconds; precise mode lands on the exact frame.

Keep the ones you want, export them as JPG or PNG, or lay them out as a share image with the video's name, length and resolution, and a timestamp on every frame.

SCREENSHOTS
• By interval (every N seconds) or by count (N shots, evenly spaced)
• Fast keyframe mode or frame-exact precise mode
• Full-resolution JPG or PNG, with adjustable JPEG quality
• Click a shot to leave it out; drag any shot straight into another app

MANY VIDEOS
• Drop several videos at once; they are processed one after another
• Export them all in one go, each into its own folder

SHARE IMAGE
• Choose the columns, the width, and a dark or light background
• Timestamps and video details on or off
• Copy, save, share, or drag the image straight into a chat

PRIVATE BY DESIGN
• Everything happens on your Mac. Kvikkshot has no network access at all: no accounts, no analytics, no tracking
• Screenshots wait in a private temporary folder and are deleted when you go back or quit; only what you export or save is kept

Kvikkshot opens anything macOS can play, such as MP4, MOV and M4V. It speaks English, Simplified Chinese and Traditional Chinese, and it is free.

Made by TangSpark, a small software studio in Norway. Kvikk is Norwegian for quick.

**What's New** (1.0.0): First release.

### English (U.K.)

The same as English (U.S.): the copy uses no spellings that differ between US and UK English.

### Chinese (Simplified)

**名称**（30）：Kvikkshot：视频截图与分享图

**副标题**（30）：一眨眼截好视频，一键生成分享图

**推广文本**（170）：
拖入视频，一眨眼截图就好了。挑出想要的，直接导出，或拼成一张分享图。所有处理都在你的 Mac 上完成，什么都不会上传。

**关键词**（100）：
截图,视频截图,抽帧,关键帧,缩略图,分享图,拼图,预览图,mp4,mov,quickshot

**描述**：

Kvikkshot 把视频一眨眼变成截图，再把截图拼成一张可以直接分享的图。

拖入视频，截图马上就好：每隔几秒一张，或者在整段视频里平均取指定数量。快速模式直接取最近的关键帧，一小时的 4K 视频也只要几秒；精确模式则准确到每一帧。

留下想要的，导出成 JPG 或 PNG，或者拼成一张分享图，上面有视频名称、时长和分辨率，每一格都标好时间。

截图
• 按间隔（每隔 N 秒）或按数量（平均取 N 张）
• 快速关键帧模式，或精确到帧的模式
• 原始分辨率的 JPG 或 PNG，JPEG 质量可调
• 点一下就能去掉不要的；截图可以直接拖到其他 app

多个视频
• 一次拖入多个视频，后台依次截图
• 一键全部导出，每个视频各有自己的文件夹

分享图
• 列数、宽度、深色或浅色背景随你选
• 时间戳和视频信息可开可关
• 拷贝、存储、分享，或直接拖进聊天窗口

隐私
• 所有处理都在你的 Mac 上完成。Kvikkshot 完全没有联网权限：没有账号，没有统计，没有追踪
• 截图只放在私有的临时文件夹里，返回首页或退出时就会删除；只有你导出或存储的文件才会保留

Kvikkshot 能打开 macOS 能播放的视频，比如 MP4、MOV、M4V。支持英文、简体中文和繁体中文，完全免费。

由挪威的小型软件工作室 TangSpark 制作。Kvikk 是挪威语里“快”的意思。

**新功能**（1.0.0）：首次发布。

### Chinese (Traditional)

**名稱**（30）：Kvikkshot：影片截圖與分享圖

**副標題**（30）：一眨眼截好影片，一鍵製作分享圖

**宣傳文字**（170）：
拖入影片，一眨眼截圖就好了。挑出想要的，直接匯出，或拼成一張分享圖。所有處理都在你的 Mac 上完成，什麼都不會上傳。

**關鍵字**（100）：
截圖,影片截圖,擷取畫面,關鍵影格,縮圖,分享圖,拼圖,mp4,mov,quickshot

**描述**：

Kvikkshot 把影片一眨眼變成截圖，再把截圖拼成一張可以直接分享的圖。

拖入影片，截圖馬上就好：每隔幾秒一張，或在整段影片中平均擷取指定數量。快速模式直接取最近的關鍵影格，一小時的 4K 影片也只要幾秒；精確模式則準確到每一格。

留下想要的，匯出成 JPG 或 PNG，或者拼成一張分享圖，上面有影片名稱、長度和解析度，每一格都標好時間。

截圖
• 按間隔（每隔 N 秒）或按數量（平均擷取 N 張）
• 快速關鍵影格模式，或精確到每一格的模式
• 原始解析度的 JPG 或 PNG，JPEG 品質可調
• 按一下就能去掉不要的；截圖可以直接拖移到其他 App

多部影片
• 一次拖入多部影片，背景依序截圖
• 一鍵全部匯出，每部影片各有自己的檔案夾

分享圖
• 欄數、寬度、深色或淺色背景隨你選
• 時間標記和影片資訊可開可關
• 拷貝、儲存、分享，或直接拖進聊天視窗

隱私
• 所有處理都在你的 Mac 上完成。Kvikkshot 完全沒有連網權限：沒有帳號，沒有統計，沒有追蹤
• 截圖只放在私有的暫存檔案夾裡，返回首頁或結束時就會刪除；只有你匯出或儲存的檔案才會保留

Kvikkshot 能打開 macOS 能播放的影片，例如 MP4、MOV、M4V。支援英文、簡體中文和繁體中文，完全免費。

由挪威的小型軟體工作室 TangSpark 製作。Kvikk 是挪威語「快」的意思。

**新功能**（1.0.0）：首次發佈。

## Notes for App Review

> Kvikkshot makes screenshots from videos. It needs no account, has no in-app purchases, and has no network access.
>
> To try it: drag any MP4 or MOV file onto the window, or choose File > Add Videos…. Screenshots appear at once. The button on the right of the toolbar changes the interval or count. "Create Share Image" shows the contact sheet. Drop several videos to see the list on the left.
>
> It runs in the App Sandbox with only user-selected read-write access and app-scoped bookmarks. Export asks for a folder with a standard open panel, unless a default export folder has been chosen in Settings; that folder is kept as a security-scoped bookmark. Screenshots are cached in the app's temporary folder and deleted on Back, on quit, and at the next launch.
>
> The Help menu links (website, support, contact) open in the browser.

## Remaking the screenshots

1. Render the sample footage:
   ```bash
   swift scripts/sample-video.swift "Fjord Timelapse.mp4" 90 0 1 7
   swift scripts/sample-video.swift "Aurora Night.mp4" 60 0.8 1 3
   swift scripts/sample-video.swift "Golden Hour.mp4" 45 0.15 0.62 11
   ```
2. For each language, open the app with `--args -AppleLanguages "(en)" -AppleLocale en_US` (or `zh-Hans`/`zh_CN`, `zh-Hant`/`zh_TW`), count mode, 24 shots, and capture the window with `screencapture -o -l <window id>`: Fjord Timelapse alone (1), then all three videos (2), then Fjord Timelapse with Create Share Image open (3).
3. Compose each capture:
   ```bash
   swift scripts/storeshot.swift capture.png docs/appstore/screenshots/en/1.jpg "Headline" "Subline"
   ```
   The headlines are in the screenshots themselves; keep them in step with the listing copy.
