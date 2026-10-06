# 你就说官网

原生 HTML / CSS / JavaScript 静态网站，无构建依赖、无第三方字体或统计脚本。

## 本地预览

在仓库根目录运行 `python3 -m http.server 4173`，访问 http://localhost:4173/website/。

## 发布

仓库 Settings → Pages → Build and deployment 选择 **GitHub Actions**。
推送 `website/` 或 `.github/workflows/pages.yml` 的更新到 `main` 后自动发布；也可手动运行工作流。
只上传 `website/`，不会把应用源码、构建产物或本地配置发布到 Pages。

公开地址：https://nufegia.github.io/YouJustSay/

安装包始终链接到 GitHub Releases 的 latest 页面，不需要在网页中维护版本号。
如以后绑定独立域名，请同步更新 `index.html` 中的 canonical、og:url 和 og:image。

## 内容维护

- `index.html`：文案、下载链接、费用和隐私说明。
- `styles.css`：响应式布局和减少动态效果设置。
- `app.js`：输入流程示意、口语整理开关、原生浮条主题切换及截图放大；不录音、不调用 AI 服务、不收集数据。
- `assets/`：现有应用图标的网页尺寸副本，以及从已安装的 1.0.4 正式版重新拍摄、按网页需求裁切的局部截图。

文案保持生活化、自由表达的语气，不使用开会、办公邮件或工作效率类示例，不设置「使用场景」栏目。直接使用应用真实截图，不重新生成产品界面。新拍原图及裁切坐标记录在 `docs/screenshots/website-1.0.4/`。应用控件未重绘，原有截图不再用于官网。

## 原生浮条与说明性可视化

`./script/render_website_bars.sh` 使用 macOS SwiftUI / AppKit 离屏导出 `website/assets/bars/`。
直接编译项目的 `DictationBar.swift`、`FloatingBarSurface.swift`、`AudioWaveform.swift` 和 `Language.swift`；仅为状态和动作注入只读夹具，不复制浮条布局代码，不改动应用，不访问音频、密钥或网络。使用原生 NSHostingView 快照以保留系统进度图标。

录音波形是确定的示例数据，进度图标为静态帧。导出浅色与深色的录音、识别、整理、完成及暂停状态。应用组件改变后重新执行脚本并检查输出。

首屏输入过程和口语整理结果是明确标注的解释性示意，不代表实时识别或模型准确率。动画只在用户点击后播放一次，并尊重减少动态效果设置。输入法关系图和费用构成图用于解释产品优势，不使用虚构价格、性能数据或竞品结论。
