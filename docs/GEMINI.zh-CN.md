# Gemini 接入

设置 → 模型：语音识别、文本整理可分别选择 Google Gemini。两处 API Key 共用钥匙串中的同一条凭据，修改任意一处即同步。可与其他供应方混合使用。

- 录音转文字：gemini-3.5-transcribe，自动识别语言，原文转写。
- 文本整理：默认 gemini-3.5-flash-lite，可选 gemini-4-hydrogen、gemini-4-argon、gemini-4-carbon、gemini-3.8-flash 或自定义模型。
- 只支持录音结束后转文字及文本整理。实时识别不实现，也不在计划中。
- 使用 Interactions API（Api-Revision: 2026-05-20），store=false，内联 WAV；原始录音小于 70 MB。
- 两个模块可分别点击测试。API 权限、计费及真实识别效果需要有效 Gemini API Key 验证。

协议参考：
https://ai.google.dev/gemini-api/docs/transcribe
https://aistudio.google.com/api-reference/interactions-api/create-interaction
https://aistudio.google.com/docs/file-input-methods
