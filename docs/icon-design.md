# YouJustSay 图标

1.0.7 使用用户确认的扁平对话框与三段声波方案，不使用浮雕、材质纹理、镜面高光或图层投影。

- `Resources/AppIcon.icon/Assets/VoiceFlatLight.svg`：暖白底上的深青绿对话轮廓与声波。
- `Resources/AppIcon.icon/Assets/VoiceFlatDark.svg`：炭灰底上的米白对话轮廓与薄荷绿声波。
- 两种外观共享相同的矢量路径、位置和大小。`icon.json` 按外观选择对应图层，关闭 glass、specular、translucency 与 shadow。
- `website/assets/app-icon.png` 与 `app-icon-dark.png` 是同一矢量方案的网页副本。网站导航、网页标签页及 README 支持亮暗外观。

构建脚本通过 actool 将图标编译为 Assets.car 与兼容图标 AppIcon.icns。旧版 PNG 仅作为历史设计资源保留，不参与当前图标编译。
