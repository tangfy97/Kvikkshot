#!/usr/bin/env python3
"""Generates the Kvikkshot pages for tang-spark.no in English, Simplified and Traditional Chinese.

    python3 website/generate.py            # writes website/dist/

scripts/publish-website.sh runs this and copies the result into a tang-spark.no checkout (see
docs/WEBSITE.md). Edit the copy below, not the generated HTML. The version comes from project.yml,
and the download size and checksum from the notarized disk image in build/release. Downloads are
GitHub releases; the site hosts no installers.

The English product page uses the site's Plakat layout (styles.css). The Chinese product pages and the
support pages keep the earlier launch layout, which the site now serves as legacy.css.
"""
import hashlib
import html
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
VERSION = re.search(r'MARKETING_VERSION: "([^"]+)"', (ROOT / "project.yml").read_text()).group(1)
DMG = ROOT / "build" / "release" / f"Kvikkshot-{VERSION}.dmg"
if DMG.exists():
    SHA256 = hashlib.sha256(DMG.read_bytes()).hexdigest()
    DMG_SIZE = f"{DMG.stat().st_size / 1_000_000:.1f} MB"
else:
    SHA256 = None
    DMG_SIZE = "1 MB"
    print(f"warning: {DMG.relative_to(ROOT)} not found; run scripts/release.sh first. The checksum line is left out.")
APP_STORE_URL = ""  # https://apps.apple.com/app/id… once the app is live; the button stays hidden until then
DOWNLOAD_URL = "https://github.com/tangfy97/Kvikkshot/releases/latest"

OUT = pathlib.Path(__file__).parent / "dist"

ICONS = {
    "mac": '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
    "bolt": '<path d="M13 3 5 13h6l-1 8 8-10h-6l1-8Z"/>',
    "stack": '<rect x="4" y="8" width="16" height="12" rx="2"/><path d="M7 5h10M9 2h6"/>',
    "gift": '<rect x="4" y="9" width="16" height="11" rx="1.5"/><path d="M3 9h18M12 9v11M12 9c-2-4-6-4-6-1s6 1 6 1Zm0 0c2-4 6-4 6-1s-6 1-6 1Z"/>',
    "shield": '<path d="M12 3 5 6v5c0 4.5 3 7.8 7 10 4-2.2 7-5.5 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-5"/>',
    "clock": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    "grid": '<rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/><rect x="13" y="13" width="7" height="7" rx="1"/>',
    "globe": '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.6 2.5 14.4 0 17M12 3.5c-2.5 2.6-2.5 14.4 0 17"/>',
    "film": '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M7 5v14M17 5v14M3 9h4M3 15h4M17 9h4M17 15h4"/>',
    "home": '<path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10.5V20h13v-9.5"/><path d="M9.5 20v-6h5v6"/>',
    "help": '<path d="M5 13v-2a7 7 0 0 1 14 0v2"/><path d="M5 13h3v5H6a1 1 0 0 1-1-1v-4ZM19 13h-3v5h2a1 1 0 0 0 1-1v-4Z"/>',
    "download": '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
}


def icon(name):
    return f'<svg viewBox="0 0 24 24" aria-hidden="true">{ICONS[name]}</svg>'


LANGS = {
    "en": dict(
        html_lang="en", body_class="", suffix="", label="EN",
        screenshot="kvikkshot/screenshot-en.jpg",
        title="Kvikkshot | Video screenshots for Mac | TangSpark",
        description="Kvikkshot turns videos into screenshots the moment you drop them in, and those screenshots into one image to share. Free, and entirely on your Mac.",
        nav_home="Home", nav_support="Support", cta="Download",
        h1='Every frame you need, in a <span class="orange">blink</span>.',
        lead="Kvikkshot is a small Mac app that turns videos into screenshots the moment you drop them in, and those screenshots into one image to share. Free, and entirely on your Mac.",
        primary="Download for Mac", secondary="Support &amp; privacy",
        proofs=[("mac", "On your Mac", "No network access at all"),
                ("bolt", "Seconds, not minutes", "Keyframe mode skims even long 4K video"),
                ("stack", "Many videos", "Drop a batch, export a folder each"),
                ("gift", "Free", "No account, no ads, no purchases")],
        screenshot_alt="Kvikkshot with 24 screenshots taken from a fjord timelapse",
        features=[("film", "By interval or by count", "One shot every few seconds, or a set number spread across the whole video. Fast mode jumps to nearby keyframes; precise mode lands on the exact frame."),
                  ("grid", "One image to share", "Lay the shots you keep out on one sheet with the video's details and a timestamp on every frame. Copy it, save it, or drag it straight into a chat."),
                  ("clock", "Leaves nothing behind", "Screenshots wait in a private temporary folder and disappear when you go back or quit. Only what you export or save is kept.")],
        trusts=[("shield", "App Sandbox", "macOS itself keeps Kvikkshot off the internet and out of your files."),
                ("mac", "Native and small", "About 2.5 MB, for Apple silicon and Intel Macs."),
                ("globe", "Four languages", "English, English (UK), Simplified and Traditional Chinese.")],
        dl_title="Download Kvikkshot",
        dl_meta=f"Version {VERSION} · macOS 14 Sonoma or later · Apple silicon and Intel · {DMG_SIZE}",
        dl_note="Signed and notarized by Apple. Open the disk image and drag Kvikkshot to Applications.",
        dl_button="Download from GitHub", store_button="Mac App Store",
        sha_label="SHA-256",
        up_to_date="You have the latest version.",
        update_available="Version {latest} is available. You have {installed}.",
        footer="© 2026 TangSpark. Nordic software, local-first by default.",
        # support page
        s_title="Kvikkshot support and privacy | TangSpark",
        s_description="Help, privacy policy and terms for Kvikkshot, the video screenshot app for Mac.",
        s_h1="Kvikkshot support",
        s_lead="Answers to common questions, the privacy policy and the terms. If something isn't covered here, write to us and we'll reply.",
        s_contact="Email support", s_back="Back to Kvikkshot",
        start_title="Getting started",
        start=["Drop one or more videos onto the window, or choose File › Add Videos.",
               "Choose how many screenshots you want with the button at the right of the toolbar: one every few seconds, or a set number.",
               "Click a screenshot to leave it out, then Export, or Create Share Image to put them on one sheet."],
        faq_title="Questions",
        faq=[("Which videos can Kvikkshot open?", "Anything macOS can play: MP4, MOV, M4V and the H.264, HEVC and ProRes inside them. MKV, AVI and WebM files need converting first, for example with HandBrake."),
             ("What is the difference between fast and precise?", "Fast mode takes the nearest keyframe to each point, which is why even long 4K videos take seconds. Turn on Precise Frames when you need the exact moment; it decodes more and is slower."),
             ("Some screenshots say they couldn't be read.", "The video is damaged at those points, or it is still being copied or downloaded. Kvikkshot retries every missing frame with a fresh decoder before it gives up, and tells you how many are missing instead of stopping."),
             ("Where do exported screenshots go?", "Export asks for a folder and creates a “… Screenshots” folder inside it for each video. To skip the question, choose a default folder in Settings."),
             ("Are my screenshots stored anywhere?", "Only in Kvikkshot's private temporary folder while you work. It is emptied when you go back to the start screen, when you quit, and at the next launch if Kvikkshot was quit unexpectedly."),
             ("How do I update?", "The Mac App Store version updates through the App Store. In the downloaded version, choose Help › Check for a New Version; it opens this website in your browser, because Kvikkshot itself never goes online."),
             ("How do I uninstall it?", "Drag Kvikkshot from Applications to the Bin. Its settings are in ~/Library/Containers/com.feiyangtang.Kvikkshot, which you can delete too.")],
        privacy_title="Privacy policy",
        privacy_updated="Last updated 21 October 2026. This policy covers the Mac App Store version and the version downloaded from GitHub.",
        privacy=["<strong>Kvikkshot collects no data.</strong> It has no network access: the App Sandbox does not let it connect to the internet. There are no accounts, analytics, telemetry, crash reporting, advertising or update checks, and no third-party code.",
                 "It reads the videos you open, keeps the screenshots it makes in its own temporary folder while you work, and writes files only where you export or save them. It remembers your settings, the last folder you exported to and, if you choose one, your default export folder. All of this stays on your Mac.",
                 "Links in the Help menu open in your browser, outside Kvikkshot. “Check for a New Version” tells this page which version you have, so it can say whether a newer one exists.",
                 "Kvikkshot is suitable for all ages and collects nothing from anyone, including children. Questions about privacy: support@tang-spark.no."],
        terms_title="Terms",
        terms=["Kvikkshot is free. You may use it for personal and commercial work, and the screenshots and share images you make are yours.",
               "It is provided as is, without warranty. TangSpark is not liable for loss of data or other damages from using it, as far as the law allows. Only process videos you have the right to use.",
               "Mac App Store downloads are also covered by Apple's standard licence agreement."],
        notes_title="Release notes",
        notes=[(f"Version {VERSION}", "21 October 2026", "First release: screenshots by interval or count, fast and precise modes, several videos at once, share images, four languages.")],
        contact_title="Contact",
        contact="Write to support@tang-spark.no. It helps to include your macOS version, the Kvikkshot version (Kvikkshot › About Kvikkshot) and, for a video that won't open, its format and where it is stored.",
    ),
    "zh-cn": dict(
        html_lang="zh-Hans", body_class="zh", suffix="-zh-cn", label="简体",
        screenshot="kvikkshot/screenshot-zh-hans.jpg",
        title="Kvikkshot | Mac 视频截图 | TangSpark",
        description="Kvikkshot 把视频一拖进来就变成截图，再把截图拼成一张可以分享的图。免费，全部在你的 Mac 上完成。",
        nav_home="首页", nav_support="支持", cta="下载",
        h1='想要的每一帧，<span class="orange">一眨眼</span>就好。',
        lead="Kvikkshot 是一个小巧的 Mac app：视频一拖进来就变成截图，再把截图拼成一张可以分享的图。免费，所有处理都在你的 Mac 上完成。",
        primary="下载 Mac 版", secondary="支持与隐私",
        proofs=[("mac", "只在你的 Mac 上", "完全没有联网权限"),
                ("bolt", "几秒钟，不是几分钟", "关键帧模式，4K 长视频也很快"),
                ("stack", "一次多个视频", "批量拖入，每个视频各自导出"),
                ("gift", "免费", "不用账号，没有广告，没有内购")],
        screenshot_alt="Kvikkshot 从一段峡湾延时视频里截出 24 张图",
        features=[("film", "按间隔或按数量", "每隔几秒一张，或在整段视频里平均取指定数量。快速模式取最近的关键帧，精确模式准确到每一帧。"),
                  ("grid", "一张图，全部分享", "把留下的截图拼成一张图，带视频信息，每一格都标好时间。可以拷贝、存储，或直接拖进聊天窗口。"),
                  ("clock", "用完不留痕迹", "截图只放在私有的临时文件夹里，返回首页或退出时就会删除。只有你导出或存储的文件才会保留。")],
        trusts=[("shield", "App 沙盒", "由 macOS 本身保证 Kvikkshot 不联网，也碰不到你没选的文件。"),
                ("mac", "原生、小巧", "约 2.5 MB，支持 Apple 芯片和 Intel 芯片的 Mac。"),
                ("globe", "四种语言", "英文、英式英文、简体中文和繁体中文。")],
        dl_title="下载 Kvikkshot",
        dl_meta=f"版本 {VERSION} · macOS 14 Sonoma 或更新 · Apple 芯片和 Intel · {DMG_SIZE}",
        dl_note="已由 Apple 签名并公证。打开磁盘映像，把 Kvikkshot 拖到“应用程序”文件夹即可。",
        dl_button="从 GitHub 下载", store_button="Mac App Store",
        sha_label="SHA-256",
        up_to_date="你用的已经是最新版本。",
        update_available="新版本 {latest} 已发布，你现在用的是 {installed}。",
        footer="© 2026 TangSpark。来自北欧的软件，默认本地优先。",
        s_title="Kvikkshot 支持与隐私 | TangSpark",
        s_description="Kvikkshot（Mac 视频截图 app）的使用帮助、隐私政策和条款。",
        s_h1="Kvikkshot 支持",
        s_lead="常见问题、隐私政策和使用条款。这里没有提到的问题，欢迎来信，我们会回复。",
        s_contact="发邮件给我们", s_back="返回 Kvikkshot",
        start_title="快速上手",
        start=["把一个或多个视频拖到窗口里，或者选择“文件 › 添加视频”。",
               "用工具栏右边的按钮设置截多少张：每隔几秒一张，或者总共几张。",
               "点一下截图可以去掉不要的，然后导出，或者点“生成分享图”拼成一张。"],
        faq_title="常见问题",
        faq=[("Kvikkshot 能打开哪些视频？", "macOS 能播放的都可以：MP4、MOV、M4V，以及里面的 H.264、HEVC、ProRes 编码。MKV、AVI、WebM 需要先转换，比如用 HandBrake。"),
             ("快速和精确有什么区别？", "快速模式取每个时间点附近的关键帧，所以 4K 长视频也只要几秒。需要准确时刻时打开“精确帧”，解码更多，会慢一些。"),
             ("有些截图显示无法读取。", "视频在那些位置有损坏，或者文件还在复制或下载中。Kvikkshot 会用新的解码器把每一张缺失的截图重试一遍，实在读不出来才会告诉你缺了几张，而不会卡住。"),
             ("导出的截图放在哪里？", "导出时会让你选一个文件夹，然后在里面为每个视频新建一个“… 截图”文件夹。如果不想每次都选，可以在“设置”里设一个默认文件夹。"),
             ("我的截图会被保存在什么地方吗？", "只在你使用时放在 Kvikkshot 私有的临时文件夹里。返回首页、退出时都会清空；如果 Kvikkshot 意外退出，下次启动时也会先清空。"),
             ("怎么更新？", "App Store 版通过 App Store 更新。从 GitHub 下载的版本，选择“帮助 › 检查新版本”，会用浏览器打开本网站；Kvikkshot 本身从不联网。"),
             ("怎么卸载？", "把 Kvikkshot 从“应用程序”拖到废纸篓即可。设置保存在 ~/Library/Containers/com.feiyangtang.Kvikkshot，也可以一并删除。")],
        privacy_title="隐私政策",
        privacy_updated="最后更新：2026 年 10 月 21 日。本政策适用于 Mac App Store 版和从 GitHub 下载的版本。",
        privacy=["<strong>Kvikkshot 不收集任何数据。</strong>它没有联网权限：App 沙盒不允许它连接互联网。没有账号、统计、遥测、崩溃报告、广告或更新检查，也没有任何第三方代码。",
                 "它读取你打开的视频，工作时把截图放在自己的临时文件夹里，只在你导出或存储的位置写入文件。它会记住你的设置、上次导出的文件夹，以及你选择的默认导出文件夹（如果有）。这些都只保存在你的 Mac 上。",
                 "“帮助”菜单里的链接会在浏览器中打开，不经过 Kvikkshot。“检查新版本”会把你正在使用的版本号告诉本页面，以便判断有没有新版本。",
                 "Kvikkshot 适合所有年龄，不向任何人（包括儿童）收集任何信息。隐私相关问题请联系 support@tang-spark.no。"],
        terms_title="使用条款",
        terms=["Kvikkshot 免费。个人和商业用途均可使用，你制作的截图和分享图归你所有。",
               "本软件按“现状”提供，不附带任何保证。在法律允许的范围内，TangSpark 不对使用本软件造成的数据丢失或其他损失负责。请只处理你有权使用的视频。",
               "从 Mac App Store 下载的版本同时适用 Apple 的标准许可协议。"],
        notes_title="更新记录",
        notes=[(f"版本 {VERSION}", "2026 年 10 月 21 日", "首次发布：按间隔或按数量截图，快速与精确两种模式，一次处理多个视频，分享图，四种语言。")],
        contact_title="联系我们",
        contact="发邮件到 support@tang-spark.no。请尽量附上你的 macOS 版本、Kvikkshot 版本（Kvikkshot › 关于 Kvikkshot），如果是打不开的视频，再附上它的格式和存放位置。",
    ),
    "zh-tw": dict(
        html_lang="zh-Hant", body_class="zh", suffix="-zh-tw", label="繁體",
        screenshot="kvikkshot/screenshot-zh-hant.jpg",
        title="Kvikkshot | Mac 影片截圖 | TangSpark",
        description="Kvikkshot 把影片一拖進來就變成截圖，再把截圖拼成一張可以分享的圖。免費，全部在你的 Mac 上完成。",
        nav_home="首頁", nav_support="支援", cta="下載",
        h1='想要的每一格，<span class="orange">一眨眼</span>就好。',
        lead="Kvikkshot 是一個小巧的 Mac App：影片一拖進來就變成截圖，再把截圖拼成一張可以分享的圖。免費，所有處理都在你的 Mac 上完成。",
        primary="下載 Mac 版", secondary="支援與隱私權",
        proofs=[("mac", "只在你的 Mac 上", "完全沒有連網權限"),
                ("bolt", "幾秒鐘，不是幾分鐘", "關鍵影格模式，4K 長影片也很快"),
                ("stack", "一次多部影片", "批次拖入，每部影片各自匯出"),
                ("gift", "免費", "不用帳號，沒有廣告，沒有內購")],
        screenshot_alt="Kvikkshot 從一段峽灣縮時影片中擷取 24 張截圖",
        features=[("film", "按間隔或按數量", "每隔幾秒一張，或在整段影片中平均擷取指定數量。快速模式取最近的關鍵影格，精確模式準確到每一格。"),
                  ("grid", "一張圖，全部分享", "把留下的截圖拼成一張圖，附上影片資訊，每一格都標好時間。可以拷貝、儲存，或直接拖進聊天視窗。"),
                  ("clock", "用完不留痕跡", "截圖只放在私有的暫存檔案夾裡，返回首頁或結束時就會刪除。只有你匯出或儲存的檔案才會保留。")],
        trusts=[("shield", "App 沙盒", "由 macOS 本身確保 Kvikkshot 不連網，也碰不到你沒選的檔案。"),
                ("mac", "原生、小巧", "約 2.5 MB，支援 Apple 晶片和 Intel 處理器的 Mac。"),
                ("globe", "四種語言", "英文、英式英文、簡體中文和繁體中文。")],
        dl_title="下載 Kvikkshot",
        dl_meta=f"版本 {VERSION} · macOS 14 Sonoma 或以上 · Apple 晶片和 Intel · {DMG_SIZE}",
        dl_note="已由 Apple 簽署並完成公證。打開磁碟映像檔，把 Kvikkshot 拖到「應用程式」檔案夾即可。",
        dl_button="從 GitHub 下載", store_button="Mac App Store",
        sha_label="SHA-256",
        up_to_date="你使用的已經是最新版本。",
        update_available="新版本 {latest} 已推出，你目前使用的是 {installed}。",
        footer="© 2026 TangSpark。來自北歐的軟體，預設本機優先。",
        s_title="Kvikkshot 支援與隱私權 | TangSpark",
        s_description="Kvikkshot（Mac 影片截圖 App）的使用說明、隱私權政策和條款。",
        s_h1="Kvikkshot 支援",
        s_lead="常見問題、隱私權政策和使用條款。這裡沒有提到的問題，歡迎來信，我們會回覆。",
        s_contact="寄信給我們", s_back="返回 Kvikkshot",
        start_title="快速上手",
        start=["把一部或多部影片拖到視窗裡，或選擇「檔案 › 加入影片」。",
               "用工具列右邊的按鈕設定要截幾張：每隔幾秒一張，或總共幾張。",
               "按一下截圖可以去掉不要的，然後匯出，或按「製作分享圖」拼成一張。"],
        faq_title="常見問題",
        faq=[("Kvikkshot 能打開哪些影片？", "macOS 能播放的都可以：MP4、MOV、M4V，以及其中的 H.264、HEVC、ProRes 編碼。MKV、AVI、WebM 需要先轉檔，例如用 HandBrake。"),
             ("快速和精確有什麼不同？", "快速模式取每個時間點附近的關鍵影格，所以 4K 長影片也只要幾秒。需要準確時刻時開啟「精確影格」，解碼較多，會慢一些。"),
             ("有些截圖顯示無法讀取。", "影片在那些位置有損壞，或檔案仍在拷貝或下載中。Kvikkshot 會用新的解碼器把每一張缺少的截圖重試一遍，真的讀不出來才會告訴你缺了幾張，而不會卡住。"),
             ("匯出的截圖放在哪裡？", "匯出時會請你選一個檔案夾，然後在其中為每部影片新增一個「… 截圖」檔案夾。如果不想每次都選，可以在「設定」中設定預設檔案夾。"),
             ("我的截圖會被儲存在什麼地方嗎？", "只在你使用時放在 Kvikkshot 私有的暫存檔案夾裡。返回首頁、結束時都會清空；如果 Kvikkshot 意外結束，下次啟動時也會先清空。"),
             ("怎麼更新？", "App Store 版透過 App Store 更新。從 GitHub 下載的版本，選擇「輔助說明 › 檢查新版本」，會用瀏覽器打開本網站；Kvikkshot 本身從不連網。"),
             ("怎麼解除安裝？", "把 Kvikkshot 從「應用程式」拖到垃圾桶即可。設定儲存在 ~/Library/Containers/com.feiyangtang.Kvikkshot，也可以一併刪除。")],
        privacy_title="隱私權政策",
        privacy_updated="最後更新：2026 年 10 月 21 日。本政策適用於 Mac App Store 版和從 GitHub 下載的版本。",
        privacy=["<strong>Kvikkshot 不蒐集任何資料。</strong>它沒有連網權限：App 沙盒不允許它連上網際網路。沒有帳號、統計、遙測、當機報告、廣告或更新檢查，也沒有任何第三方程式碼。",
                 "它讀取你打開的影片，使用時把截圖放在自己的暫存檔案夾裡，只在你匯出或儲存的位置寫入檔案。它會記住你的設定、上次匯出的檔案夾，以及你選擇的預設匯出檔案夾（如果有）。這些都只儲存在你的 Mac 上。",
                 "「輔助說明」選單中的連結會在瀏覽器中打開，不經過 Kvikkshot。「檢查新版本」會把你正在使用的版本號告訴本頁面，以便判斷是否有新版本。",
                 "Kvikkshot 適合所有年齡，不向任何人（包括兒童）蒐集任何資訊。隱私權相關問題請聯絡 support@tang-spark.no。"],
        terms_title="使用條款",
        terms=["Kvikkshot 免費。個人和商業用途皆可使用，你製作的截圖和分享圖歸你所有。",
               "本軟體依「現狀」提供，不附帶任何保證。在法律允許的範圍內，TangSpark 不對使用本軟體造成的資料遺失或其他損失負責。請只處理你有權使用的影片。",
               "從 Mac App Store 下載的版本同時適用 Apple 的標準授權合約。"],
        notes_title="更新紀錄",
        notes=[(f"版本 {VERSION}", "2026 年 10 月 21 日", "首次發佈：按間隔或按數量截圖，快速與精確兩種模式，一次處理多部影片，分享圖，四種語言。")],
        contact_title="聯絡我們",
        contact="寄信到 support@tang-spark.no。請盡量附上你的 macOS 版本、Kvikkshot 版本（Kvikkshot › 關於 Kvikkshot），如果是打不開的影片，再附上它的格式和存放位置。",
    ),
}


def head(t, title, description, page):
    alternates = "\n".join(
        f'    <link rel="alternate" hreflang="{o["html_lang"]}" href="https://tang-spark.no/{page}{o["suffix"]}.html" />'
        for o in LANGS.values())
    return f"""<!doctype html>
<html lang="{t['html_lang']}">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content="{html.escape(description)}" />
    <meta property="og:title" content="{title}" />
    <meta property="og:description" content="{html.escape(description)}" />
    <meta property="og:image" content="https://tang-spark.no/kvikkshot/og-image.jpg" />
{alternates}
    <link rel="icon" type="image/svg+xml" href="./favicon.svg" />
    <link rel="apple-touch-icon" href="./kvikkshot/icon-256.png" />
    <link rel="stylesheet" href="./legacy.css" />
    <link rel="stylesheet" href="./kvikkshot.css" />
  </head>"""


def header(t, page, active):
    def link(o):
        current = 'class="active" aria-current="true" ' if o is t else ""
        return f'<a {current}href="./{page}{o["suffix"]}.html" hreflang="{o["html_lang"]}">{o["label"]}</a>'

    def nav(name, href, symbol, label):
        current = 'class="active" aria-current="page" ' if active == name else ""
        return f'<a {current}href="{href}">{icon(symbol)}{label}</a>'

    langs = " ".join(link(o) for o in LANGS.values())
    s = t["suffix"]
    return f"""
    <div class="launch-shell">
      <header class="launch-header">
        <a class="launch-brand" href="./index.html" aria-label="TangSpark home"><span class="launch-mark" aria-hidden="true"></span><span>TangSpark</span></a>
        <nav class="launch-nav" aria-label="Primary">
          {nav("home", "./index.html", "home", t["nav_home"])}
          {nav("product", f"./kvikkshot{s}.html", "film", "Kvikkshot")}
          {nav("support", f"./kvikkshot-support{s}.html", "help", t["nav_support"])}
        </nav>
        <div class="launch-header-action">
          <nav class="kvikk-lang" aria-label="Language">{langs}</nav>
          <a class="launch-cta" href="./kvikkshot{s}.html#download">{icon("download")}{t["cta"]}</a>
        </div>
      </header>"""


def footer(t):
    return f"""
    <footer class="launch-footer"><p>{t["footer"]}</p><a href="mailto:support@tang-spark.no">support@tang-spark.no</a></footer>"""


def product(t):
    s = t["suffix"]
    proofs = "\n".join(
        f'              <div class="launch-proof"><span class="launch-proof-icon">{icon(i)}</span><span><strong>{a}</strong><span>{b}</span></span></div>'
        for i, a, b in t["proofs"])
    features = "\n".join(
        f'            <article class="launch-feature"><div class="launch-feature-icon">{icon(i)}</div><div><h2>{a}</h2><p>{b}</p></div></article>'
        for i, a, b in t["features"])
    trusts = "\n".join(
        f'            <article class="launch-trust"><div class="launch-trust-icon">{icon(i)}</div><div><strong>{a}</strong><span>{b}</span></div></article>'
        for i, a, b in t["trusts"])
    store_href = APP_STORE_URL or "#"
    store_hidden = "" if APP_STORE_URL else " hidden"
    store = f'<a class="launch-button secondary" href="{store_href}"{store_hidden}>{t["store_button"]}</a>'
    return f"""{head(t, t["title"], t["description"], "kvikkshot")}
  <body class="echoknot-launch kvikkshot {t["body_class"]}">{header(t, "kvikkshot", "product")}

      <main>
        <section class="launch-hero">
          <div class="launch-copy">
            <img class="kvikk-icon" src="./kvikkshot/icon-256.png" width="88" height="88" alt="" />
            <h1>{t["h1"]}</h1>
            <p class="launch-lead">{t["lead"]}</p>
            <div class="launch-actions">
              <a class="launch-button primary" href="#download">{t["primary"]} <span aria-hidden="true">→</span></a>
              <a class="launch-button secondary" href="./kvikkshot-support{s}.html">{t["secondary"]}</a>
            </div>
            <div class="launch-proof-row">
{proofs}
            </div>
          </div>
          <div class="launch-device-wrap">
            <img class="kvikk-shot" src="./{t["screenshot"]}" width="1240" height="820" alt="{t["screenshot_alt"]}" />
          </div>
        </section>

        <section id="features" class="launch-feature-panel">
          <div class="launch-feature-grid">
{features}
          </div>
          <div class="launch-trust-strip kvikk-trust">
{trusts}
          </div>
        </section>

        <section id="download" class="kvikk-download">
          <div>
            <h2>{t["dl_title"]}</h2>
            <p class="kvikk-meta">{t["dl_meta"]}</p>
            <p>{t["dl_note"]}</p>
            {f'<p class="kvikk-sha">{t["sha_label"]} <code>{SHA256}</code></p>' if SHA256 else ""}
            <p class="kvikk-update" id="update-status" hidden></p>
          </div>
          <div class="kvikk-download-actions">
            <a class="launch-button primary" href="{DOWNLOAD_URL}">{icon("download")}{t["dl_button"]}</a>
            {store}
          </div>
        </section>
      </main>
    </div>{footer(t)}
    <script>
      // Help › Check for a New Version opens this page with ?installed=<version>.
      (() => {{
        const latest = "{VERSION}";
        const installed = new URLSearchParams(location.search).get("installed");
        if (!installed) return;
        const newer = (a, b) => {{
          const x = a.split(".").map(Number), y = b.split(".").map(Number);
          for (let i = 0; i < 3; i++) if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
          return false;
        }};
        const status = document.getElementById("update-status");
        status.textContent = newer(latest, installed)
          ? {repr(t["update_available"])}.replace("{{latest}}", latest).replace("{{installed}}", installed)
          : {repr(t["up_to_date"])};
        status.hidden = false;
      }})();
    </script>
  </body>
</html>
"""


def support(t):
    s = t["suffix"]
    start = "\n".join(f"              <li>{x}</li>" for x in t["start"])
    faq = "\n".join(f"            <details><summary>{q}</summary><p>{a}</p></details>" for q, a in t["faq"])
    privacy = "\n".join(f"            <p>{p}</p>" for p in t["privacy"])
    terms = "\n".join(f"            <p>{p}</p>" for p in t["terms"])
    notes = "\n".join(f'            <h3>{v} <span class="kvikk-meta">{d}</span></h3>\n            <p>{n}</p>' for v, d, n in t["notes"])
    return f"""{head(t, t["s_title"], t["s_description"], "kvikkshot-support")}
  <body class="echoknot-launch kvikkshot {t["body_class"]}">{header(t, "kvikkshot-support", "support")}

      <main class="kvikk-doc">
        <section class="kvikk-doc-hero">
          <img class="kvikk-icon" src="./kvikkshot/icon-256.png" width="72" height="72" alt="" />
          <h1>{t["s_h1"]}</h1>
          <p class="launch-lead">{t["s_lead"]}</p>
          <div class="launch-actions">
            <a class="launch-button primary" href="mailto:support@tang-spark.no?subject=Kvikkshot">{t["s_contact"]}</a>
            <a class="launch-button secondary" href="./kvikkshot{s}.html">{t["s_back"]}</a>
          </div>
        </section>

        <section id="start">
          <h2>{t["start_title"]}</h2>
          <ol>
{start}
          </ol>
        </section>

        <section id="faq">
          <h2>{t["faq_title"]}</h2>
          <div class="kvikk-faq">
{faq}
          </div>
        </section>

        <section id="privacy">
          <h2>{t["privacy_title"]}</h2>
          <p class="kvikk-meta">{t["privacy_updated"]}</p>
{privacy}
        </section>

        <section id="terms">
          <h2>{t["terms_title"]}</h2>
{terms}
        </section>

        <section id="release-notes">
          <h2>{t["notes_title"]}</h2>
{notes}
        </section>

        <section id="contact">
          <h2>{t["contact_title"]}</h2>
          <p>{t["contact"]}</p>
        </section>
      </main>
    </div>{footer(t)}
  </body>
</html>
"""


def poster_product():
    """The English product page, in the site's Plakat layout (styles.css), matching Spolo and Rydd."""
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kvikkshot — Screenshots from video, in a blink. | TangSpark</title><meta name="description" content="Drop in a video and the screenshots are there before you can look away. Keep the ones you want, export them, or turn them into one image to share. Kvikk is Norwegian for quick.">
<link rel="icon" type="image/svg+xml" href="./favicon.svg"><link rel="stylesheet" href="./styles.css"></head>
<body><div class="wrap">
<header><a class="mark" href="./index.html">TangSpark</a><nav><a href="./index.html#apps">Apps</a><a href="./kvikkshot-support.html">Support</a><a href="./kvikkshot-zh-cn.html">中文</a></nav></header>
<div class="title"><img src="img/kvikkshot-icon.png" alt=""><span class="label">macOS 14+ · Free</span></div>
<div class="hero-name">Kvikkshot</div>
<section class="grid poster"><div class="block"><h1 class="cond">Screenshots from video, in a blink.</h1><p>Drop in a video and the screenshots are there before you can look away. Keep the ones you want, export them, or turn them into one image to share. Kvikk is Norwegian for quick.</p></div>
<div class="facts"><div><span>Platform</span><span>macOS 14, Apple silicon &amp; Intel</span></div><div><span>Price</span><span>Free</span></div><div><span>Network</span><span>None at all</span></div><div><span>Languages</span><span>EN, 简体, 繁體</span></div></div></section>
<section class="grid"><div class="big"><img src="img/kvikkshot-shot.jpg" alt="Kvikkshot with 24 frames from a fjord timelapse"></div></section>
<section class="part rule grid cols"><h2 class="cond">What it does</h2><ul class="list"><li><b>By interval or count</b><span>One shot every few seconds, or N shots spread across the video.</span></li><li><b>Fast or precise</b><span>Keyframe mode skims an hour of 4K in seconds; precise mode is exact to the frame.</span></li><li><b>Many videos</b><span>Drop a batch; each gets its own folder on export.</span></li><li><b>Share image</b><span>One sheet with columns, light or dark, timestamps and video details.</span></li><li><b>Leaves nothing behind</b><span>Cached frames are deleted on Back, on quit and at next launch.</span></li></ul></section>
<section id="download" class="part rule grid cols"><h2 class="cond">Get Kvikkshot</h2><div style="grid-column: 5 / span 8"><p>Signed and notarized by Apple. Open the disk image and drag Kvikkshot to Applications. Also coming to the Mac App Store.</p><div class="cta"><a class="btn red" href="{DOWNLOAD_URL}">Download from GitHub</a><a class="btn" href="./kvikkshot-support.html">Support &amp; privacy</a></div></div></section>
<footer><span>© 2026 TangSpark</span><a href="./kvikkshot-support.html">Support &amp; privacy</a></footer>
</div></body></html>
"""


OUT.mkdir(exist_ok=True)
for t in LANGS.values():
    (OUT / f"kvikkshot{t['suffix']}.html").write_text(poster_product() if t is LANGS["en"] else product(t))
    (OUT / f"kvikkshot-support{t['suffix']}.html").write_text(support(t))
print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*.html"))))
