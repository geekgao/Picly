<p align="center">
<h1 align="center">Picly</h1>
<h3 align="center">为macOS设计的瀑布流式图片浏览器</h3> 
</p>

[![](https://img.shields.io/github/release/netdcy/Picly.svg?color=blue)](https://github.com/netdcy/Picly/releases/latest "GitHub release") [![](https://img.shields.io/github/downloads/netdcy/Picly/total?color=blue)](https://github.com/netdcy/Picly/releases/latest "GitHub downloads") ![GitHub License](https://img.shields.io/github/license/netdcy/Picly?color=blue)

## 预览

### 浅色模式
![preview](https://netdcy.github.io/Picly/docs/preview_2.png)

### 黑暗模式
![preview](https://netdcy.github.io/Picly/docs/preview_1.png)

## 应用特点:

 - 自适应布局模式、浅色/深色模式

 - 方便的文件管理（操作类似 Finder）

 - 右键手势、快速查找上一个/下一个有图片/视频的文件夹

 - 针对目录下大量图片情况的性能优化

 - 高质量的缩放（减轻摩尔纹等问题）

 - 支持视频播放

 - 支持HDR显示

 - 支持递归模式

## 安装使用

### 系统需求

 - macOS 11.0+

### 隐私与安全性

 - 开源软件
 - 无网络请求

### Homebrew 方式安装

首次安装
```
brew install picly
```
版本升级
```
brew update
brew upgrade picly
```

## 操作说明

### 图片浏览:
 - 双击打开/关闭图片
 - 按住右键/左键滚动滚轮可以缩放
 - 按住中键拖动可以移动窗口
 - 长按左键切换 100%缩放
 - 长按右键切换缩放到视图
### 右键手势:
 - 向右/左：切换到下一个/上一个有图片/视频的文件夹(逻辑上等同于将整个磁盘中的文件夹排序后的下一个)
 - 向上：切换到上级目录
 - 向下：返回到上一次的目录
 - 向上右：切换到与当前文件夹平级的下一个有图片的文件夹
 - 向下右：关闭当前标签页/窗口
### 键盘按键:
 - W：同右键手势 向上
 - A/D：同右键手势 向左/右
 - S：同右键手势 向下

## 性能优化

Picly 针对包含大量图片的文件夹（特别是 exFAT 外置盘和网络驱动器）做了多项性能优化。

### 文件元数据缓存（`DirMetadataCache`）

按目录持久化缓存 `[文件名: (文件大小, 修改日期)]`。当再次打开同一目录时，只有新增或变动的文件需要重新读取属性——不变的文件跳过整个扫描（零 I/O）。缓存文件位于 `~/Library/Application Support/Picly/DirMetadataCache.json`。

### 快速 JPEG/PNG 文件头解析

直接读取文件头部提取图片尺寸，无需创建完整的 `CGImageSource`：
- **JPEG**：只读 8KB，解析 SOF 标记获取像素尺寸和 EXIF 旋转方向
- **PNG**：只读 33 字节，解析 IHDR 块获取尺寸
- 效果：每张图的 I/O 从 ~16KB 降低到 ~8KB（JPEG）/ 33 字节（PNG）

### 视频读取优化

优先通过 **ffprobe** 读取视频尺寸（只读 moov box 头部），而非 `AVAsset(url:)`（解析更多容器元数据）。ffprobe 不可用时回退到 AVAsset。

### 并行处理

后台任务并发数大幅提升：
- **内置 SSD**：图片尺寸读取和缩略图生成最高 8 个并发
- **外置驱动器**：最高 4 个并发（可在高级设置中调整）

### 外置盘 I/O 精简

在 exFAT/NAS 上消除了重复的文件属性请求：
- 修复了重复的 `resourceValues(forKeys:)` 调用（标签属性被读取了两次 -- 对 8500 张图 + 180 个视频的目录，多出 8680 次额外 I/O）
- 外置盘去掉了 `.isSymbolicLinkKey` 和 iCloud 相关属性，只读取必要字段

### 渐进加载与实时布局更新

- 文件夹打开后 **~500ms 内** 即开始显示图片（扫描完文件属性后立即展示）
- 每批尺寸计算完成后立即刷新布局，可见的图片自动调整到正确比例
- 缩略图异步加载，逐个替换占位视图

### 滚动位置保护

当 `DispatchSource` 检测到文件系统事件触发刷新时，滚动位置在刷新前保存、刷新后恢复——阻止视图自动跳转到新增文件。

## 编译

### 环境

Xcode 15.2+

### 第三方库

 - https://github.com/arthenica/ffmpeg-kit
 - https://github.com/attaswift/BTree
 - https://github.com/sindresorhus/Settings

### 构建步骤

1. 克隆此项目和依赖库的代码。
2. 对于ffmpeg-kit，需要预先构建二进制文件。如果你想省时间，可以直接下载它已构建好的二进制库，例如 `ffmpeg-kit-full-gpl-6.0-macos-xcframework.zip` (非LTS版本)。 解压后，在终端执行如下命令以移除quarantine属性：

    ```
    sudo xattr -rd com.apple.quarantine ./ffmpeg-kit-full-gpl-6.0-macos-xcframework
    ```

    (由于项目中止和版权原因，预构建的二进制文件已被移除，[这里](https://github.com/netdcy/ffmpeg-kit/releases/download/v6.0/ffmpeg-kit-full-gpl-6.0-macos-xcframework.zip)是原文件的备份。)

3. 按如下所示组织目录结构：

    ```
    ├── Picly
    │   ├── Picly.xcodeproj
    │   └── Picly
    │       └── Sources
    ├── ffmpeg-kit-build
    │   └── bundle-apple-xcframework-macos
    │       ├── ffmpegkit.xcframework
    │       └── ...
    ├── BTree
    │   ├── Package.swift
    │   └── Sources
    └── Settings
        ├── Package.swift
        └── Sources
    ```

4. 用Xcode打开 `Picly.xcodeproj` ，在菜单栏中点击 'Product' -> 'Build For' -> 'Profiling' 。
5. 然后 'Product' -> 'Show Build Folder in Finder'，就可以看到构建好的app了 `Products/Release/Picly.app` 。

## 支持

如果你感觉这个应用有帮助，欢迎支持开发者！

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/netdcyn)

<img src="https://picly.app/donate.jpg" alt="WeChat Donate" width="350"/>

## 协议

本项目使用GPL许可证。完整的许可证文本请参见 [LICENSE](https://github.com/netdcy/Picly/blob/main/LICENSE) 文件。