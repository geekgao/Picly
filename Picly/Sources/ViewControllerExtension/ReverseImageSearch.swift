import Foundation
import Cocoa

extension ViewController {

    func showReverseImageSearchOverlay() {
        if reverseImageSearchOverlay != nil { return }

        let overlay = NSView(frame: view.bounds)
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.0).cgColor

        let panelWidth: CGFloat = 500
        let panelHeight: CGFloat = 320
        let panelX = (view.bounds.width - panelWidth) / 2
        let panelY = view.bounds.height - panelHeight - 60

        let containerView = NSView(frame: NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight))

        let effectView = NSVisualEffectView(frame: containerView.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .popover
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        containerView.addSubview(effectView)

        let topPadding: CGFloat = 16
        let sidePadding: CGFloat = 20
        let elementSpacing: CGFloat = 12
        let contentWidth = panelWidth - sidePadding * 2

        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Reverse Image Search", comment: "以图搜图"))
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.frame = NSRect(x: sidePadding, y: panelHeight - topPadding - 22, width: contentWidth - 40, height: 22)
        containerView.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: NSLocalizedString("Find visually similar photos (similar scene, similar object, similar composition)", comment: "寻找视觉上相似的照片（相似场景、相似物体、相似构图）"))
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: sidePadding, y: panelHeight - topPadding - 22 - 18, width: contentWidth - 40, height: 16)
        containerView.addSubview(subtitleLabel)

        let closeButton = NSButton(frame: NSRect(x: panelWidth - sidePadding - 24, y: panelHeight - topPadding - 22, width: 24, height: 24))
        closeButton.bezelStyle = .smallSquare
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeReverseImageSearchOverlay)
        containerView.addSubview(closeButton)

        let dropZoneTop = topPadding + 22 + 18 + 16 + elementSpacing
        let dropZoneHeight: CGFloat = 156
        let dropZoneView = ReverseImageDropView(frame: NSRect(x: sidePadding, y: panelHeight - dropZoneTop - dropZoneHeight, width: contentWidth, height: dropZoneHeight))
        dropZoneView.wantsLayer = true
        dropZoneView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        dropZoneView.layer?.cornerRadius = 10
        dropZoneView.layer?.borderWidth = 2
        dropZoneView.layer?.borderColor = NSColor.separatorColor.cgColor
        dropZoneView.viewController = self
        reverseImageDropZone = dropZoneView
        containerView.addSubview(dropZoneView)

        let dropIconSize: CGFloat = 48
        let dropIcon = NSImageView(frame: NSRect(x: (contentWidth - dropIconSize) / 2, y: dropZoneHeight - dropIconSize - 40, width: dropIconSize, height: dropIconSize))
        dropIcon.image = NSImage(systemSymbolName: "photo.badge.plus", accessibilityDescription: nil)
        dropIcon.contentTintColor = .secondaryLabelColor
        dropIcon.isEditable = false
        dropZoneView.addSubview(dropIcon)
        reverseImageDropIcon = dropIcon

        let dropLabel = NSTextField(labelWithString: NSLocalizedString("Drag image here or click to browse", comment: "拖拽图片到这里，或点击选择"))
        dropLabel.font = NSFont.systemFont(ofSize: 13)
        dropLabel.textColor = .secondaryLabelColor
        dropLabel.alignment = .center
        dropLabel.frame = NSRect(x: 0, y: 20, width: contentWidth, height: 20)
        dropZoneView.addSubview(dropLabel)

        let bottomRowTop = panelHeight - dropZoneTop - dropZoneHeight - elementSpacing
        let chooseButton = NSButton(title: NSLocalizedString("Choose Image...", comment: "选择图片..."), target: self, action: #selector(reverseImageChooseFile))
        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .regular
        chooseButton.frame = NSRect(x: (panelWidth - 160) / 2, y: bottomRowTop - 30, width: 160, height: 30)
        containerView.addSubview(chooseButton)
        reverseImageChooseButton = chooseButton

        let queryImagePreview = NSImageView(frame: NSRect(x: panelWidth - sidePadding - 56, y: panelHeight - dropZoneTop - dropZoneHeight + 12, width: 48, height: 48))
        queryImagePreview.wantsLayer = true
        queryImagePreview.layer?.cornerRadius = 6
        queryImagePreview.layer?.masksToBounds = true
        queryImagePreview.isHidden = true
        queryImagePreview.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(queryImagePreview)
        reverseImagePreview = queryImagePreview

        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: sidePadding, y: 14, width: contentWidth, height: 18)
        statusLabel.isHidden = true
        containerView.addSubview(statusLabel)
        reverseImageStatusLabel = statusLabel

        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = false
        containerView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.3).cgColor
        containerView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        containerView.layer?.shadowRadius = 12
        containerView.layer?.shadowOpacity = 0.5

        overlay.addSubview(containerView)
        reverseImageSearchOverlay = overlay

        view.addSubview(overlay)
    }

    @objc func closeReverseImageSearchOverlay() {
        reverseImageSearchTask?.cancel()
        reverseImageSearchTask = nil
        reverseImageSearchOverlay?.removeFromSuperview()
        reverseImageSearchOverlay = nil
        reverseImageDropZone = nil
        reverseImageDropIcon = nil
        reverseImagePreview = nil
        reverseImageStatusLabel = nil
        reverseImageChooseButton = nil
        view.window?.makeFirstResponder(collectionView)
    }

    @objc func reverseImageChooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .gif, .bmp, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = NSLocalizedString("Select an image to search by", comment: "选择搜索用图片")
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            self.startReverseImageSearch(with: url.path)
        }
    }

    func handleReverseImagePaste() {
        let pasteboard = NSPasteboard.general
        guard let types = pasteboard.types else { return }

        if types.contains(.fileURL) {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
               let url = urls.first,
               globalVar.HandledImageExtensions.contains(url.pathExtension.lowercased()) {
                startReverseImageSearch(with: url.path)
                return
            }
        }

        if types.contains(.tiff) || types.contains(.png) {
            let tempDir = FileManager.default.temporaryDirectory
            let tempPath = tempDir.appendingPathComponent("pasted_search_image_\(UUID().uuidString).png")
            if let image = NSImage(pasteboard: pasteboard),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: tempPath)
                startReverseImageSearch(with: tempPath.path)
            }
        }
    }

    func startReverseImageSearch(with imagePath: String) {
        guard globalVar.imageAIEnabled else {
            showInformationLong(title: NSLocalizedString("Info", comment: "说明"),
                               message: NSLocalizedString("AI search is disabled. Enable it in Settings > Advanced.", comment: "AI搜索未启用"))
            return
        }

        reverseImageStatusLabel?.isHidden = false
        reverseImageStatusLabel?.stringValue = NSLocalizedString("Indexing image...", comment: "正在处理图片...")
        reverseImageDropIcon?.isHidden = true
        reverseImageChooseButton?.isEnabled = false

        if let preview = reverseImagePreview {
            preview.isHidden = false
            preview.image = NSImage(contentsOfFile: imagePath)
        }

        reverseImageSearchTask?.cancel()
        reverseImageSearchTask = Task { [weak self] in
            guard let self = self, !Task.isCancelled else { return }

            await MainActor.run {
                self.reverseImageStatusLabel?.stringValue = NSLocalizedString("AI Searching...", comment: "AI搜索中...")
                self.startIndeterminate()
            }

            do {
                let results = try await ImageAIService.shared.searchByImage(path: imagePath, topK: 200)

                guard !Task.isCancelled else { return }
                log("Reverse image search: results=\(results.count)")

                let allPaths = results.compactMap { URL(fileURLWithPath: $0.image.path).absoluteString }
                let folderPrefix = fileDB.curFolder.hasSuffix("/") ? fileDB.curFolder : fileDB.curFolder + "/"
                let paths = allPaths.filter { $0.hasPrefix(folderPrefix) }

                await MainActor.run { [paths, allPaths] in
                    guard !Task.isCancelled else { return }
                    self.reverseImageStatusLabel?.isHidden = true
                    self.hideProgress()
                    self.closeReverseImageSearchOverlay()

                    if paths.isEmpty {
                        if allPaths.isEmpty {
                            self.coreAreaView.showInfo(NSLocalizedString("No similar images found", comment: "未找到相似图片"), timeOut: 2.0)
                        } else {
                            self.coreAreaView.showInfo(String(format: NSLocalizedString("Found %ld results in subfolders", comment: "在子文件夹中找到 %ld 个结果"), allPaths.count), timeOut: 3.0)
                        }
                        return
                    }

                    self.publicVar.aiFilterPaths = paths
                    self.publicVar.isAIFilterOn = true
                    self.applyAIFilter()
                    self.publicVar.updateToolbar()
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("Found %ld similar images", comment: "找到 %ld 张相似图片"), paths.count), timeOut: 2.0)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.reverseImageStatusLabel?.isHidden = true
                    self.reverseImageChooseButton?.isEnabled = true
                    self.hideProgress()
                    log("Reverse image search error: \(error.localizedDescription)")
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("AI search failed: %@", comment: "AI搜索失败: %@"), error.localizedDescription), timeOut: 3.0)
                }
            }
        }
    }

    @objc func reverseImageSearchFromSelected() {
        guard let url = publicVar.selectedUrls().first,
              globalVar.HandledImageExtensions.contains(url.pathExtension.lowercased()) else {
            coreAreaView.showInfo(NSLocalizedString("Please select an image file", comment: "请选择图片文件"), timeOut: 2.0)
            return
        }
        startReverseImageSearch(with: url.path)
    }
}

class ReverseImageDropView: NSView {
    weak var viewController: ViewController?
    private var isHovering = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isHovering = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1)
        }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHovering = false
        resetAppearance()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isHovering = false
        resetAppearance()
    }

    private func resetAppearance() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
            layer?.transform = CATransform3DIdentity
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHovering = false
        resetAppearance()

        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           globalVar.HandledImageExtensions.contains(url.pathExtension.lowercased()) {
            viewController?.startReverseImageSearch(with: url.path)
            return true
        }
        if let image = NSImage(pasteboard: pasteboard),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let tempDir = FileManager.default.temporaryDirectory
            let tempPath = tempDir.appendingPathComponent("dropped_search_image_\(UUID().uuidString).png")
            try? pngData.write(to: tempPath)
            viewController?.startReverseImageSearch(with: tempPath.path)
            return true
        }
        return false
    }

    override func mouseDown(with event: NSEvent) {
        viewController?.reverseImageChooseFile()
    }
}
