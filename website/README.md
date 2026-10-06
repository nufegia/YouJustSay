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
- `app.js`：真实截图切换与放大查看，不录音、不调用 AI 服务、不收集数据。
- `assets/`：现有应用图标的网页尺寸副本，以及从 `docs/screenshots/` 原样复制的真实截图。

文案保持生活化、自由表达的语气，不使用开会、办公邮件或工作效率类示例，不设置「使用场景」栏目。直接使用应用真实截图，不重新生成产品界面。更新截图时同步 `docs/screenshots/` 和 `website/assets/`。
