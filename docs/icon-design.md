# YouJustSay 图标

1.0.8 使用用户于 2026-10-20 确认的独立高分辨率 Y 形原图：流动的黑／米白线条与青色点缀。

- 亮暗原图分别保存在 `icon-source/high-resolution-draft/VoiceYLight-original.png` 与 `VoiceYDark-original.png`。目录沿用预览时的名称，两张图现已确认。
- 两张均为内置生图工具独立生成的 1254 × 1254 PNG；不使用约 300 像素的方案图裁片，不放大、描摹或重绘。
- `icon-source/selection.json` 记录原始文件、尺寸和 SHA-256；应用的 `VoiceYLight.png` / `VoiceYDark.png` 与网站的 `app-icon.png` / `app-icon-dark.png` 分别与对应原图字节一致。
- 应用按外观使用亮暗图片；白色官网固定使用亮色版，避免跟随系统深色模式切为黑底。
- 图标编译关闭 glass、specular、translucency 与 shadow；应用图层按系统底板宽度缩放至 0.8，保留原图内的留白，避免青色尖端碰到圆角裁切；网页仅作外框圆角适配。

构建时由 actool 编译为 Assets.car 和 AppIcon.icns。此前设计资源仅作历史保留，不参与当前图标编译。

发布前检查编译后的图标边缘、小尺寸效果与安装包资源；仅以用户确认的高分辨率原图为来源。
