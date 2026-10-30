# OpenAI API 接入

## 当前实现

停止录音 → 文件转录 → 可选文本润色 → 使用既有上屏方式输出。语音服务与文本服务独立选择，服务商列表以 OpenAI 为首项；全新安装默认 OpenAI；旧版无语音服务商字段时根据旧设置迁移为豆包，保留原文字服务（旧默认方舟）。已有明确保存的选择继续保留。

语音使用 `/v1/audio/transcriptions`，multipart WAV 上传，默认 `gpt-transcribe`；指定识别语言使用 `languages[]`，自动模式省略。当前只展示已适配的文件转录模型。

识别语言按服务商和模型配置，分别保存选择。豆包保留原火山语言目录及区域代码；OpenAI 的 `gpt-transcribe` 使用独立维护的常用语言提示目录、语言名称及 ISO 代码（例如 `en`、`yue`、`tl`），不显示火山专属地区标签。该目录不是 OpenAI 完整支持语言清单；官方文档未列出完整模型枚举，实际可用性仍待真实 API 验证。未知模型仅提供自动选项且不能发起未适配的识别请求。旧全局语言仅迁移到豆包，切换服务商不覆盖另一方语言选择。

文本使用 `/v1/responses`，默认 `gpt-6.1-terra`，另有 Luna、Sol、Astra 预设和自定义模型 ID。按模型默认推理设置运行，不强制发送可能不兼容的 temperature/thinking/max_tokens。请求设置 `store: false`；仅接受 completed 的文本结果，拒绝截断、拒答和空输出。自定义兼容服务仍使用 Chat Completions，方舟保持原请求格式，文本模型与 OpenAI 使用相同的下拉选择界面：提供现有默认模型 `doubao-seed-2-1-lite-260915`，也可选“其他模型…”填写模型 ID 或推理接入点 ID；模型需在方舟账号内可用。各服务商分别保存模型选择。

OpenAI 语音与文本 API Key 独立保存，分别使用 `openaiSpeech` 和 `openai` 凭据字段，互不回退或覆盖。旧版的 OpenAI Key 仅保留为文本 Key，语音 Key 需单独填写。两者保存在现有版本化 Keychain 凭据项内。模型、服务商选择保存在 UserDefaults。切换服务商不删除原有凭据和模型设置。

润色失败时保留本次识别原文，可使用已有原文操作或重试整理，不要求重新录音。HTTP 错误显示服务商及状态码，不展示响应中的敏感信息。

## 用户验收

1. 在模型配置里选 OpenAI，输入自己的 API Key，分别执行语音和文本测试；确认额度与模型权限正常。
2. 录制中文、英文、中英混说、人名、数字以及长段落，核对原文准确性和上屏延迟。
3. 开启自动整理，切换不同文本模型和整理风格，检查是否改变事实、数字或原意。
4. 试用豆包语音 + OpenAI 文本、OpenAI 语音 + 方舟文本，确认可独立切换。
5. 重启后确认服务商、模型和密钥可恢复；测试无效 Key、不可用模型、网络中断及重试。

以上涉及真实 API 的步骤留给用户填 Key 后进行，本次不调用用户账户。

## 计划中：边说边显示文字（尚未实现）

- 新增实时识别模式，评估 `gpt-live-transcribe` 与 Realtime transcription 接入。
- 录音过程中持续发送音频，在浮条展示临时转录；区分临时结果和最终确认结果。
- 停止录音后等待最终结果，再进行可选润色和一次性上屏，防止重复输入。
- 实现连接取消、断线恢复、音频格式适配、延迟和费用验证。
- 保留现有停止录音后识别模式；实时模型不混入当前文件识别下拉框。

参考：
- https://developers.openai.com/api/docs/guides/transcription
- https://developers.openai.com/api/docs/guides/speech-to-text
- https://developers.openai.com/api/docs/models
