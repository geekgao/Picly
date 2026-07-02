<p align="center">
<h1 align="center">Picly</h1>
<h3 align="center">macOS 瀑布流图片浏览器 — 增强分支</h3> 
</p>

基于 [netdcy/Picly](https://github.com/netdcy/Picly) 的功能增强版，新增 AI 语义搜索、地理位置筛选、自然语言查询、图片格式转换，以及针对外置卷的大幅性能优化。

## 新增功能

### AI 语义搜索
集成设备端 AI 服务器（`imageai`），对图片进行语义索引和搜索。支持自然语言查询，如"海滩日落"、"红色汽车"。

### 地理位置搜索
- **GPS 索引**：提取图片 EXIF GPS 坐标，构建可搜索的地理位置索引
- **邻近搜索**：用自然语言查找某位置附近的照片（如"东京附近"、"巴黎的照片"），支持可调搜索半径
- **反向地理编码**：使用 CLGeocoder（含重试与超时逻辑）可靠解析地名；回退到 MKLocalSearch 和内置国家中心坐标
- **地理过滤器**：在当前文件夹中筛选出满足地理查询的照片，并显示计数

### 自然语言搜索
单次查询中同时支持日期、地点和关键词过滤：
- 日期范围："上周的照片"、"2024年3月"
- 地点："上海附近"、"在日本"
- 关键词："生日派对"、"文档"
- 组合查询："东京附近一月的照片"

### 图片格式转换
支持 JPEG、PNG、WebP 等格式互转，可设置质量、尺寸和输出目录。支持 UI 批量转换和右键菜单转换。

### 外置卷 I/O 优化
大幅减少 exFAT、FAT32、网络驱动器上的 I/O：
- 惰性属性读取 — 仅在当前排序模式需要时才读取文件日期/大小
- 修复了重复的 `resourceValues(forKeys:)` 调用（标签属性被读取两次）
- 外置盘去掉了 `.isSymbolicLinkKey` 和 iCloud 属性
- 可配置并发数（内置 SSD 最高 8 个，外置盘最高 4 个）

### 文件元数据缓存（`DirMetadataCache`）
按目录持久化缓存 `[文件名: (文件大小, 修改日期)]`。再次打开同一目录时只读取新增或变动的文件——不变文件跳过整个扫描（零 I/O）。缓存位于 `~/Library/Application Support/Picly/DirMetadataCache.json`。

### TaskPool — 结构化并发
自定义线程池，用于后台任务：
- 固定大小的工作线程，支持阻塞安全队列
- 优先级排队（缩略图加载优先于尺寸读取）
- 切换目录时优雅取消

### EnhancedIndex — 文件追踪
跨会话追踪文件的创建、删除和移动。用于保持 AI 索引和地理缓存的一致性，即使文件在外部被移动。

### 其他改进
- **ImageAI 模型面板**：查看 AI 索引状态、模型加载和每文件分析结果
- **收藏夹弹出窗口**：快速访问带搜索功能的收藏夹
- **文件信息窗口**：详细的元数据查看器
- **Finder 标签集成**：读取并按 Finder 标签筛选
- **ConvertProcess**：基于 FFmpeg 的图片格式转换管道
- **瀑布流/对齐/网格布局切换**：工具栏一键切换
- **布局配置**：保存和恢复布局设置
- **滚动位置保护**：文件系统事件触发刷新时保持滚动位置
- **渐进加载**：~500ms 内显示图片，实时更新宽高比

## 编译

### 环境

Xcode 15.2+, macOS 12.0+

### 依赖库

- [ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit) — 视频处理
- [BTree](https://github.com/attaswift/BTree) — 有序集合
- [Settings](https://github.com/sindresorhus/Settings) — 设置面板

### 构建步骤

1. 克隆本仓库和依赖库到同级目录。
2. 对于 ffmpeg-kit，构建为二进制或下载预编译 xcframework：
   ```
   sudo xattr -rd com.apple.quarantine ./ffmpeg-kit-full-gpl-6.0-macos-xcframework
   ```
3. 按以下结构组织目录：
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
4. 用 Xcode 打开 `Picly.xcodeproj`，点击 `Product → Build For → Profiling`。
5. 构建产物位于 `Products/Release/Picly.app`。

## 协议

GPL License。完整协议文本见 [LICENSE](LICENSE)。
