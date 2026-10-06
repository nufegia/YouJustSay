# YouJustSay · 你就说

**极简 macOS 语音输入工具：按 Fn，说话，变成文字。** 支持 macOS 14 及以上；当前安装包适用于 Apple 芯片。

专注语音输入，按需整理文字。自带 API 密钥，无需注册账号。

## 为什么选择你就说

**功能极简，按量付费，保留你习惯的输入法。**

| 产品 | 为什么你该用你就说 |
| --- | --- |
| [闪电说](https://shandianshuo.cn/docs) | 只想说句话，用不着请个智能体。 |
| [Typeless](https://www.typeless.com/pricing) | 语音输入，何必交月租？API 用多少，付多少。 |
| [OpenTypeless](https://github.com/tover0314-w/opentypeless) | 功能做减法，审美不打折；专注 macOS，把口述输入做好。 |
| [豆包输入法](https://ime.doubao.com/pc) | 五笔、RIME 照用；先开口，再选框，输入工具别改我的习惯。 |

## 界面预览

### 浮条状态

录音、识别、整理、恢复、完成、上屏失败与识别重试，浅色和深色一览。

<img src="docs/screenshots/floating-bars.png" alt="浮条浅色与深色预览：录音、识别、整理、取消后恢复、完成、上屏失败及识别重试" width="840" />

### 快捷键与上屏

按 Fn 开始／结束，或按住说话。支持自动粘贴、直接键入、仅复制。

<img src="docs/screenshots/interaction.png" alt="录音交互：Fn 快捷键与上屏方式" width="816" />

### 自带模型密钥

豆包识别语音，方舟整理文字，也支持自定义 OpenAI 兼容整理接口。

<img src="docs/screenshots/models.png" alt="模型配置：语音识别、语言与密钥测试" width="816" />

### 三种整理风格

基础整理保留原话，轻度润色修正语病，高度结构化分段归类。也可关闭整理。

<img src="docs/screenshots/text-cleanup.png" alt="文本整理：模型与整理风格" width="816" />

## 下载与安装

[下载最新正式版](https://github.com/nufegia/YouJustSay/releases/latest) · [完整安装说明](docs/INSTALL.zh-CN.md)

下载 DMG 后，将应用拖入「应用程序」。本版未使用 Developer ID 签名与苹果公证；首次打开如被拦截，请前往「系统设置 → 隐私与安全性 → 仍要打开」确认。随后授权麦克风和辅助功能。

## 支持的服务商

| 用途 | 服务商 | 配置 |
| --- | --- | --- |
| 语音识别 | 火山·豆包语音 | 录音文件极速版；API 密钥或 App ID + Access Token。 |
| 文字整理 | 火山·方舟 | 方舟 API 密钥，内置豆包模型。 |
| 文字整理 | [OpenAI](https://platform.openai.com/docs/api-reference/chat)、[深度求索（DeepSeek）](https://api-docs.deepseek.com/)等 OpenAI 兼容服务 | 选择「自定义」，填写 HTTPS 接口地址、模型和密钥，使用兼容的 Chat Completions 模型。 |

## 开始使用

1. 打开 `YouJustSay.app`，授权麦克风和辅助功能。
2. 填写豆包语音密钥；启用整理时配置方舟或自定义服务。点击「测试」验证。
3. 按 Fn 说话，再按 Fn 结束，文字输入到所选位置。

按 Esc 取消；识别或整理取消后，5 秒内可恢复。按 `⌃⌥⌘S` 打开设置。

## 数据与隐私

密钥存于本机钥匙串。音频和文字由所选服务处理，不保存文字历史，临时录音正常结束后删除。

## 从源码构建

需要 macOS 14 或更新版本，以及支持 Swift 6 和 `.icon` 图标编译的 Xcode 工具链（当前发行包使用 Xcode 27 构建）。

```sh
swift test
./script/build_and_run.sh --release
./script/package_release.sh
```

## 许可证

采用 [MIT 许可证](LICENSE)。
