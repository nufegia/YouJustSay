# GitHub 应用更新

应用使用 Sparkle 2，通过 GitHub Releases 的 `appcast.xml` 检查更新、验证安装包并安装新版。
「关于」页和应用菜单均有「检查更新」；自动检查默认开启，自动安装默认关闭。
更新前仍需用户确认。旧的 1.0.2 没有更新组件，需要手动安装 1.0.3 一次。

## 签名

更新使用 Ed25519 签名。公钥位于 `Resources/Info.plist` 的 `SUPublicEDKey`。
私钥保存在发布者的 macOS 登录钥匙串中，Sparkle account 为 `app.youjustsay.native`。
不要提交、上传或打印私钥；更换发布电脑前，使用 Sparkle `generate_keys` 的导出／导入功能安全备份和迁移。
不要重新生成公钥替换现有公钥，否则已安装版本将无法验证后续更新。

更新签名与 Apple Developer ID 签名是两种不同签名；目前仍未使用 Apple Developer ID 或公证。
初次手动安装的系统授权方式见安装说明。

## 发布

1. 修改 `Resources/Info.plist`：提升版本号和构建号。构建号必须单调递增。
2. 在 Apple 芯片 Mac 上构建并测试，提交并推送源码。
3. 准备发布说明，运行 `./script/publish_release.sh /path/to/release-notes.md`。
4. 检查 GitHub 草稿的 DMG、`appcast.xml` 和 `SHA256SUMS.txt`，确认后发布为最新正式版。

`package_release.sh` 自动嵌入并签署 Sparkle 框架及辅助程序，生成 DMG 和经过签名验证的更新清单。
更新清单中的下载地址指向具体版本；应用检查地址为：
`https://github.com/nufegia/YouJustSay/releases/latest/download/appcast.xml`。
每次正式发布必须同时上传这三个文件，不能单独发布没有 `appcast.xml` 的最新版本。
预发布版本不会替换正式更新源。当前源只分发 arm64 安装包。

## 验证

运行 `swift test`、`./script/package_release.sh`，并检查应用签名与动态框架加载。
首次上线后，在 1.0.3 的「关于」页检查更新，应显示当前已是最新版本。
发布下一版时，用已安装的 1.0.3 检查、下载、确认安装、重启，验证完整更新过程。
