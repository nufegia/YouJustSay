<p align="center">
  <img src="Resources/AppIcon.icon/Assets/VoiceLight.png" alt="你就说应用图标" width="96" height="96" />
</p>

<h1 align="center">你就说 · YouJustSay</h1>

<p align="center"><strong>想说的，直接变成写好的。</strong></p>

<p align="center">
  按一下 Fn，开口说话，再按一下，文字就到输入框。<br />
  选中文字，按 Fn + 空格，也能直接整理已有表达。
</p>

<p align="center"><strong>免费开源 · 无应用订阅 · 保留你习惯的输入法</strong></p>

<p align="center">
  <a href="https://github.com/nufegia/YouJustSay/releases/latest"><strong>下载 Mac 版 →</strong></a>
  &nbsp; · &nbsp;
  <a href="https://nufegia.github.io/YouJustSay/">产品官网</a>
  &nbsp; · &nbsp;
  <a href="docs/INSTALL.zh-CN.md">安装指南</a>
  &nbsp; · &nbsp;
  <a href="#界面预览">看看界面</a>
</p>

<p align="center"><sub>macOS 14+ · 当前安装包适用于 Apple 芯片 · 自备 API 密钥</sub></p>

| 不多交一份月租 | 不改变输入习惯 | 把口述输入做好 |
| :---: | :---: | :---: |
| 应用免费，自备密钥，API 按量付费 | 五笔、RIME 照用，Fn 随时唤起语音输入 | 原生 macOS 浮条，识别后按需整理文字 |

**随口说出的念头，也能好好留下来。**

> **你说：**“嗯，突然想去海边，什么也不安排，就走走。”<br />
> **整理后：**“突然想去海边。什么也不安排，就走走。”

<sub>以上为文字整理示例，实际结果随模型与整理风格而异；也可关闭整理，直接使用识别结果。</sub>

应用免费开源，无需注册应用账号；语音识别与文字整理使用你自己的 API 密钥，费用由服务商按使用量收取。

## 为什么选择你就说

**如果你已经有顺手的输入法，只想给 Mac 加上语音输入，它就是为这种需求做的。**

| 你在意的事 | 你就说的选择 |
| --- | --- |
| **偶尔用，也不想每月付订阅费** | 应用免费开源，不收订阅费；识别和整理使用自己的 API 密钥，服务费用按量计算。 |
| **输入法已经用顺手了** | 保留五笔、RIME 等现有输入法，需要时按 Fn 说话；支持自动粘贴、直接键入或仅复制。 |
| **想让口语变清楚，又想保留自己的表达** | 基础整理、轻度润色、高度结构化三种风格可选，也能关闭整理，直接使用识别结果。 |
| **想自己选择文字整理模型** | 内置方舟，也支持自定义 OpenAI 兼容整理接口；服务地址、模型和密钥由你配置。 |
| **喜欢 Mac 上简单、顺手的工具** | 原生 macOS 界面，浅色／深色浮条；Fn 开始或结束、按住说话、Esc 取消，专注口述输入。 |

首次使用需要配置豆包语音密钥；启用文字整理时，再配置整理服务。适合愿意花几分钟配置、希望自己掌握服务选择和用量的人。

## 界面预览

### 浮条状态

录音、识别、整理、取消后恢复与完成，浅色和深色一览。浮条由当前原生组件渲染，波形为示例。

<img src="docs/screenshots/floating-bars.png" alt="浮条浅色与深色预览：录音、识别、整理、取消后恢复与完成" width="840" />

### 按键交互与选中文字整理

按 Fn 开始／结束，或按住说话；选中文字后按 Fn + 空格进行整理。两组快捷键均可自定义，共用自动粘贴、模拟键入、仅复制三种上屏方式。

<img src="docs/screenshots/interaction.png" alt="按键交互：Fn 语音输入、Fn + 空格整理选中文字与统一上屏方式" width="816" />

### 自带模型密钥

豆包识别语音，方舟整理文字，也支持自定义 OpenAI 兼容整理接口。

<img src="docs/screenshots/models.png" alt="模型配置：语音识别、语言与密钥测试" width="816" />

### 三种整理风格

基础整理保留原话，轻度润色修正语病，高度结构化去除口水词和冗余表达、优化书面语，并按需分段归类和列点。也可关闭整理。

<img src="docs/screenshots/text-cleanup.png" alt="文本整理：模型与整理风格" width="816" />

## 下载与安装

[下载最新正式版](https://github.com/nufegia/YouJustSay/releases/latest) · [完整安装说明](docs/INSTALL.zh-CN.md)

下载 DMG 后，将应用拖入「应用程序」。本版未使用 Developer ID 签名与苹果公证；首次打开如被拦截，请前往「系统设置 → 隐私与安全性 → 仍要打开」确认。随后授权麦克风和辅助功能。

从 1.0.3 开始，可在「关于」页或应用菜单中检查更新。更新通过 GitHub Releases 分发，安装前验证更新签名并请求确认；也可关闭自动检查。1.0.2 用户需先手动安装新版本一次。[更新与发布说明](docs/UPDATES.zh-CN.md)

## 支持的服务商

| 用途 | 服务商 | 配置 |
| --- | --- | --- |
| 语音识别 | [火山·豆包语音](https://www.volcengine.com/docs/6561/1631584?lang=zh) | 录音文件极速版；API 密钥或 App ID + Access Token。 |
| 文字整理 | [火山·方舟](https://docs.volcengine.com/docs/ark?lang=zh) | 方舟 API 密钥，内置豆包模型。 |
| 文字整理 | [OpenAI](https://platform.openai.com/docs/api-reference/chat)、[深度求索（DeepSeek）](https://api-docs.deepseek.com/)等 OpenAI 兼容服务 | 选择「自定义」，填写 HTTPS 接口地址、模型和密钥，使用兼容的 Chat Completions 模型。 |

## 开始使用

1. 打开 `YouJustSay.app`，授权麦克风和辅助功能。
2. 填写豆包语音密钥；启用整理时配置方舟或自定义服务。点击「测试」验证。
3. 按 Fn 说话，再按 Fn 结束，文字输入到所选位置。
4. 在可编辑文本框中选中文字，按 `Fn + 空格` 使用「整理选中文本」，整理结果遵循「按键交互」中的上屏方式：自动粘贴或模拟键入会覆盖原选区，仅复制则保留原文并将结果复制到剪贴板。此功能使用模型配置中的整理服务和风格，即使关闭录音自动整理也能使用。

在「按键交互」中可分别自定义语音输入和整理选中文本的快捷键，不能设为相同组合。整理完成前请保持原输入框和选区；如果发生变化，应用会保留当前文字，并提供复制结果。目标应用需要支持辅助功能读取文本选区。

按 Esc 取消；识别或整理取消后，5 秒内可恢复。按 `⌃⌥⌘S` 打开设置。

## 数据与隐私

密钥存于本机钥匙串。音频、识别文字及主动选择整理的文本由所选服务处理，不保存文字历史，临时录音正常结束后删除。

## 从源码构建

需要 macOS 14 或更新版本，以及支持 Swift 6 和 `.icon` 图标编译的 Xcode 工具链（当前发行包使用 Xcode 27 构建）。

```sh
swift test
./script/build_and_run.sh --release
./script/package_release.sh
```

## 许可证

采用 [MIT 许可证](LICENSE)。
