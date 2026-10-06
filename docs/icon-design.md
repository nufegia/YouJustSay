# YouJustSay 图标

当前使用 `Assets/VoiceSoft.png`：内置 image_gen 以原始 VoiceLight.png 为参考，适度减弱高光与浮雕，保留实体和柔和立体感。原图保留供回退；亮暗版本共用此前景，分别使用浅底和近黑底。

当前编辑提示词：Carefully retouch this EXACT existing YouJustSay app icon, not a redesign. Keep its filled teal speech bubble, shape, three transparent vertical waveform slots, their proportions, composition, position, canvas size and transparent background identical. Reduce the current embossing and shininess by about 45 percent, not 100 percent. Preserve the gentle rounded volume and rich teal tonal shading of the reference. Soften the bright white top-left reflection into a subdued wide teal highlight, reduce the luminous outer rim, make edge bevels thinner and the slot inset shadows shallower. The result should still have clearly visible soft 3D layering, but feel quiet, refined and softly satin rather than glossy glass or a thick inflated badge. Retain filled surfaces and nuanced shading: do NOT turn it into a flat solid silhouette or outline icon. No new shadow outside the shape, no text, no new symbols, no background tile. Preserve true alpha transparency outside and inside the three slots. This is a moderate refinement of the supplied image, not the earlier flat or matte cutout interpretations.

使用内置 image_gen 生图模型生成；暗色版以亮色版为参考编辑，未使用 CLI 生图。

前景资源：`Resources/AppIcon.icon/Assets/VoiceLight.png`、`VoiceDark.png`。保留原始透明通道。当前采用同一前景图层，亮暗外观仅切换浅色／近黑色底板，避免系统切换时替换图片资源；图层缩放 0.78。VoiceDark.png 保留为原始设计素材。已导出亮暗预览并由 actool 打包为 Assets.car 与兼容图标。

## 生成提示词

亮色：Create a production macOS application icon FOREGROUND LAYER for YouJustSay, an extremely minimal speech-to-text utility. Square 1024x1024 canvas, transparent background. A single centered sculpted teal speech bubble, with three clean vertical rounded audio-waveform slots cut out in its middle, communicating speaking and dictation. Bubble width approximately 600px, height 540px, centered in the canvas, tiny integrated tail bottom-left. Restrained Apple native Liquid Glass design language: elegant rounded geometry, slight 3D thickness, satin translucent teal glass, soft top-left illumination and very subtle edge highlight, crisp legible silhouette. LIGHT APPEARANCE glyph: rich deep teal that contrasts against a near-white icon tile. Only the foreground symbol, NO app icon rounded-square tile, NO background, NO floor, NO surrounding drop shadow, NO letters, NO words, NO microphone stand, NO additional objects, NO mockup. Large simple shapes that remain clear at 32 pixels. Output a single icon foreground, not a comparison sheet.

暗色：Make the DARK APPEARANCE version of this macOS app icon foreground. Preserve the EXACT silhouette, placement, dimensions, speech bubble tail and three waveform cutout positions and sizes. Only change the teal material to a softer luminous pale icy aqua satin glass, suited to a dark charcoal icon tile. Subtle 3D, restrained smooth shading, clean edges. Avoid strong shine, neon bloom, or extra decoration. Keep actual transparent background and transparent cutout holes. No background tile, no text, no extra objects. Same square canvas as input.

规范参考：[Apple Icon Composer](https://developer.apple.com/icon-composer/)。
