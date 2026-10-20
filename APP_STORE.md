# QuickShots 上架清单

## 已经在项目里做好的
- App Sandbox（只申请了「用户选择的文件 读写」一项权限）
- 隐私清单 `PrivacyInfo.xcprivacy`：不追踪、不收集数据；声明了 UserDefaults（CA92.1）
- 出口合规：`ITSAppUsesNonExemptEncryption = NO`，上传后不用再回答加密问题
- 图标：asset catalog，16–1024 全尺寸
- 本地化：English（基准）、English (UK)、简体中文、繁體中文，跟随系统语言
- 最低系统：macOS 14

## 隐私（可以直接写进 App 描述）
- 完全本地处理：沙盒里没有申请网络权限，系统层面就不允许联网
- 截图缓存只放在 app 自己的沙盒临时文件夹里；点「返回」、换视频、退出时都会删除。如果上次是崩溃或强制退出，下次启动会先清掉残留
- 只有用户主动导出或保存的文件才会留下来

## 需要你自己做的
1. 加入 Apple Developer Program（每年 99 美元），在 Xcode → Settings → Accounts 登录
2. 改 `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`（如果要换）和 `DEVELOPMENT_TEAM`（你的 Team ID），然后运行 `xcodegen generate`
3. 在 App Store Connect 新建 App，确认名字「QuickShots」没有被占用；被占用的话就改 `INFOPLIST_KEY_CFBundleDisplayName`
4. 准备：隐私政策网址（必填，写「不收集任何数据」即可）、支持网址、截图（推荐 2880×1800）、各语言的描述和关键词
5. 隐私标签（App Privacy）选「不收集数据」
6. Xcode 打开 `QuickShots.xcodeproj` → Product → Archive → Distribute App → App Store Connect

## 本地测试构建
```
scripts/build.sh
```
构建结果在 `build/QuickShots.app`（本地签名，已开启沙盒）。
