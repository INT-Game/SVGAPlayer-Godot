# SVGAPlayer-Godot

此插件实现了在 Godot 引擎项目中播放 SVGA 动画的方法。

SVGA 是一种跨平台动画格式，通常用于移动应用程序中。

## 功能

### 支持

* Godot3.x
* 播放 SVGA 动画。
* 支持精灵动画、形状和剪切路径。
* 提供对播放的基本控制（播放、停止、步进）。
* 支持循环动画。

### 不支持

* Godot4.x
* 不支持声音播放
* shape解析尚未调试

## 安装

1. 将 `addons/godot-svga-player` 文件夹复制到你的 Godot 项目的 `addons` 文件夹中。
2. 在 `项目设置 -> 插件` 中启用该插件。

## 用法

1. 将 `SVGAPlayer` 节点添加到你的场景中。
2. 使用 `load_svga(path: String)` 方法加载 SVGA 文件。
3. 使用 `play()`、`stop()` 和 `step()` 方法控制动画。
4. 使用 `loop` 属性启用或禁用循环。
5. 连接到 `frame_changed(frame)` 信号，以便在动画帧更改时收到通知。
6. 连接到 `animation_finished()` 信号，以便在动画完成时收到通知。

## 改进

此项目用到了[godobuf](https://github.com/oniksan/godobuf)插件，但是实际使用中发现其proto文件编码速度较慢，影响了加载速度，可以考虑提前加载并缓存。

## 示例

见 `addons/godot-svga-player/example`

## LICENSE

[Apache License 2.0](./LICENSE)
