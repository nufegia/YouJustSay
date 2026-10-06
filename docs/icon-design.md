# YouJustSay 图标

当前前景资源为 `Resources/AppIcon.icon/Assets/VoiceSoft.png`，由内置 image_gen 以 VoiceLight.png 为参考精修，适度减弱高光与浮雕，保留柔和立体感。

当前编辑提示词：Carefully retouch this EXACT existing YouJustSay app icon, not a redesign. Keep its filled teal speech bubble, shape, three transparent vertical waveform slots, their proportions, composition, position, canvas size and transparent background identical. Reduce the current embossing and shininess by about 45 percent, not 100 percent. Preserve the gentle rounded volume and rich teal tonal shading of the reference. Soften the bright white top-left reflection into a subdued wide teal highlight, reduce the luminous outer rim, make edge bevels thinner and the slot inset shadows shallower. The result should still have clearly visible soft 3D layering, but feel quiet, refined and softly satin rather than glossy glass or a thick inflated badge. Retain filled surfaces and nuanced shading: do NOT turn it into a flat solid silhouette or outline icon. No new shadow outside the shape, no text, no new symbols, no background tile. Preserve true alpha transparency outside and inside the three slots. This is a moderate refinement of the supplied image, not the earlier flat or matte cutout interpretations.

亮暗外观共用同一透明前景，分别使用浅色／近黑色底板；图层缩放为 0.78。配置以 `Resources/AppIcon.icon/icon.json` 为准。

构建脚本通过 actool 将图标编译为 Assets.car 与兼容图标 AppIcon.icns。

规范参考：[Apple Icon Composer](https://developer.apple.com/icon-composer/)。
