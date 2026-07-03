import Cocoa
import ImageIO

extension ViewController {
    // MARK: - Person Browser (toolbar button)

    func showPersonBrowser() {
        guard globalVar.imageAIEnabled else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("AI Features Disabled", comment: "AI 功能未开启")
            alert.informativeText = NSLocalizedString("Enable AI features in Settings to use face recognition.", comment: "在设置中开启 AI 功能以使用人脸识别。")
            alert.runModal()
            return
        }

        if let existing = personBrowserOverlay {
            existing.removeFromSuperview()
            personBrowserOverlay = nil
            personBrowserVC = nil
            return
        }

        let container = NSView(frame: view.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        container.identifier = NSUserInterfaceItemIdentifier(rawValue: "PersonBrowserOverlay")

        let panelWidth: CGFloat = 520
        let panelHeight: CGFloat = 520
        let panelX = (view.bounds.width - panelWidth) / 2
        let panelY = (view.bounds.height - panelHeight) / 2

        let panel = DynamicBackgroundView(frame: NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight))
        panel.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 12
        panel.layer?.masksToBounds = true

        let browserVC = PersonBrowserViewController()
        browserVC.onClose = { [weak self] in
            self?.reverseImageSearchTask?.cancel()
            self?.search_aiDebounceTask?.cancel()
            self?.personBrowserVC?.setIndexingState(isIndexing: false)
            self?.personBrowserOverlay?.removeFromSuperview()
            self?.personBrowserOverlay = nil
            self?.personBrowserVC = nil
        }
        browserVC.onPersonSelected = { [weak self] personId in
            log("Face: person selected \(personId)")
            self?.personBrowserOverlay?.removeFromSuperview()
            self?.personBrowserOverlay = nil
            self?.personBrowserVC = nil
            self?.searchPhotosByPerson(personId)
        }
        browserVC.onIndexFolder = { [weak self] in
            self?.indexFacesInCurrentFolder()
        }
        browserVC.onIndexCancel = { [weak self] in
            self?.faceIndexTask?.cancel()
            self?.faceIndexTask = nil
        }
        browserVC.view.frame = panel.bounds
        browserVC.view.autoresizingMask = [.width, .height]
        panel.addSubview(browserVC.view)

        let clickOutside = NSClickGestureRecognizer(target: self, action: #selector(closePersonBrowserAction))
        clickOutside.buttonMask = 1 << 0
        container.addGestureRecognizer(clickOutside)

        container.addSubview(panel)
        view.addSubview(container)

        personBrowserOverlay = container
        personBrowserVC = browserVC
    }

    @objc func closePersonBrowserAction(_ sender: Any? = nil) {
        reverseImageSearchTask?.cancel()
        search_aiDebounceTask?.cancel()
        personBrowserVC?.setIndexingState(isIndexing: false)
        personBrowserOverlay?.removeFromSuperview()
        personBrowserOverlay = nil
        personBrowserVC = nil
    }

    // MARK: - Face Overlay

    private func showFaceOverlay() {
        let photoPath = largeImageView.file.path
        guard let url = URL(string: photoPath),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return }
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        guard imgW > 0, imgH > 0 else { return }

        let loadingLabel = NSTextField(labelWithString: NSLocalizedString("Detecting faces...", comment: "检测人脸..."))
        loadingLabel.font = NSFont.systemFont(ofSize: 12)
        loadingLabel.textColor = .secondaryLabelColor
        loadingLabel.alignment = .center
        loadingLabel.frame = NSRect(x: 0, y: 10, width: 200, height: 20)
        loadingLabel.identifier = NSUserInterfaceItemIdentifier(rawValue: "FaceOverlayLoading")
        largeImageView.addSubview(loadingLabel)

        faceOverlayTask?.cancel()
        faceOverlayTask = Task { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            do {
                try await ImageAIService.shared.ensureRunning()
                guard !Task.isCancelled else { return }
                try? await FaceService.shared.indexFaces(path: url.path)
                guard !Task.isCancelled else { return }
                let matches = try await FaceService.shared.searchFacesByImage(path: url.path, topK: 10, minScore: 0.0)
                guard !Task.isCancelled else { return }
                let samePhoto = matches.filter { $0.photoPath == url.path }

                await MainActor.run {
                    loadingLabel.removeFromSuperview()
                    guard !samePhoto.isEmpty else {
                        let noFace = NSTextField(labelWithString: NSLocalizedString("No faces detected", comment: "未检测到人脸"))
                        noFace.font = NSFont.systemFont(ofSize: 12)
                        noFace.textColor = .secondaryLabelColor
                        noFace.alignment = .center
                        noFace.frame = NSRect(x: 0, y: 10, width: 200, height: 20)
                        noFace.identifier = NSUserInterfaceItemIdentifier(rawValue: "FaceOverlayLoading")
                        self.largeImageView.addSubview(noFace)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { noFace.removeFromSuperview() }
                        return
                    }

                    let overlay = FaceOverlayView(frame: self.largeImageView.bounds)
                    overlay.autoresizingMask = [.width, .height]
                    overlay.identifier = NSUserInterfaceItemIdentifier(rawValue: "FaceOverlayView")
                    overlay.wantsLayer = true
                    overlay.onFaceClick = { [weak self] faceId in
                        self?.onFaceClicked(faceId)
                    }

                    let faceItems: [(id: String, rect: NSRect)] = samePhoto.map { match in
                        let rect = NSRect(
                            x: CGFloat(match.bboxX) / imgW,
                            y: CGFloat(match.bboxY) / imgH,
                            width: CGFloat(match.bboxW) / imgW,
                            height: CGFloat(match.bboxH) / imgH
                        )
                        return (match.faceId, rect)
                    }
                    overlay.updateFaces(faceItems)
                    self.largeImageView.addSubview(overlay, positioned: .above, relativeTo: nil)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { loadingLabel.removeFromSuperview() }
                log("Face overlay failed: \(error.localizedDescription)")
            }
        }
    }

    func hideFaceOverlay() {
        reverseImageSearchTask?.cancel()
        search_aiDebounceTask?.cancel()
        faceSearchTask?.cancel()
        faceSearchTask = nil
        faceOverlayTask?.cancel()
        faceOverlayTask = nil
        let subs = largeImageView.subviews
        subs.first(where: { $0.identifier?.rawValue == "FaceOverlayView" })?.removeFromSuperview()
        subs.first(where: { $0.identifier?.rawValue == "FaceOverlayLoading" })?.removeFromSuperview()
    }

    // MARK: - Apply face search results as collection view filter

    /// Core method: takes a list of absolute file paths, applies as filter
    private func applyFaceFilter(photoPaths: [String]) {
        log("Face: applyFaceFilter with \(photoPaths.count) paths")
        guard !photoPaths.isEmpty else {
            coreAreaView.showInfo(NSLocalizedString("No matching photos found", comment: "未找到匹配照片"), timeOut: 2.0)
            return
        }

        // Convert absolute paths to file:// URLs
        let paths = photoPaths.map { URL(fileURLWithPath: $0).absoluteString }
        publicVar.aiFilterPaths = paths
        publicVar.isAIFilterOn = true
        applyAIFilter()
        publicVar.updateToolbar()

        let msg = String(format: NSLocalizedString("Found %ld matching photos", comment: "找到 %ld 张匹配照片"), paths.count)
        coreAreaView.showInfo(msg, timeOut: 2.0)
    }

    // MARK: - Batch Indexing

    @objc func indexFacesInCurrentFolder() {
        log("Face: indexFacesInCurrentFolder called, imageAIEnabled=\(globalVar.imageAIEnabled)")
        guard globalVar.imageAIEnabled else {
            coreAreaView.showInfo(NSLocalizedString("AI features are disabled", comment: "AI 功能未开启"), timeOut: 3.0)
            return
        }

        // If already indexing, just attach progress to person browser
        if FaceIndexingManager.shared.isBusy {
            let progress = FaceIndexingManager.shared.currentProgress
            coreAreaView.showInfo(String(format: NSLocalizedString("Already indexing: %d/%d", comment: "已在索引中"), progress.done, progress.total), timeOut: 2.0)
            personBrowserVC?.setIndexingState(isIndexing: true, done: progress.done, total: progress.total)
            Task {
                await FaceIndexingManager.shared.attachProgress { [weak self] done, total in
                    DispatchQueue.main.async {
                        self?.personBrowserVC?.setIndexingState(isIndexing: true, done: done, total: total)
                        if done >= total {
                            self?.personBrowserVC?.setIndexingState(isIndexing: false)
                            self?.personBrowserVC?.refresh()
                            self?.coreAreaView.showInfo(NSLocalizedString("Face indexing complete", comment: "人脸索引完成"), timeOut: 3.0)
                        }
                    }
                }
            }
            return
        }

        // Get all image file paths from the current folder's dirModel
        fileDB.lock()
        guard let dirModel = fileDB.db[SortKeyDir(fileDB.curFolder)] else {
            fileDB.unlock()
            coreAreaView.showInfo("No files in current folder", timeOut: 2.0)
            return
        }
        var paths: [String] = []
        for (_, file) in dirModel.files {
            if file.type == .image {
                let barePath = URL(string: file.path)?.path ?? file.path
                paths.append(barePath)
            }
        }
        fileDB.unlock()

        guard !paths.isEmpty else {
            coreAreaView.showInfo("No images in current folder", timeOut: 2.0)
            return
        }

        log("Face: collected \(paths.count) image paths for indexing")
        coreAreaView.showInfo(String(format: NSLocalizedString("Indexing %d faces...", comment: "索引 %d 张人脸中"), paths.count), timeOut: 2.0)

        faceIndexTask?.cancel()
        faceIndexTask = Task { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            await MainActor.run {
                self.personBrowserVC?.setIndexingState(isIndexing: true, done: 0, total: paths.count)
            }
            await FaceIndexingManager.shared.indexPhotosBatch(paths) { done, total in
                if done % 5 == 0 || done == total {
                    guard !Task.isCancelled else { return }
                    DispatchQueue.main.async {
                        let msg = String(format: NSLocalizedString("Faces: %d/%d", comment: "人脸索引进度"), done, total)
                        self.coreAreaView.showInfo(msg, timeOut: 1.0)
                        self.personBrowserVC?.setIndexingState(isIndexing: true, done: done, total: total)
                        log("Face: progress \(msg)")
                    }
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.personBrowserVC?.setIndexingState(isIndexing: false)
                self.coreAreaView.showInfo(NSLocalizedString("Face indexing complete", comment: "人脸索引完成"), timeOut: 3.0)
                self.personBrowserVC?.refresh()
                log("Face: indexing complete, person browser refreshed")
            }
        }
        log("Face: indexing task launched")
    }

    // MARK: - Search triggers

    /// From overlay face click: show options (search or merge)
    private func onFaceClicked(_ faceId: String) {
        guard let window = view.window else {
            searchByFaceId(faceId)
            return
        }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Face Action", comment: "人脸操作")
        alert.informativeText = NSLocalizedString("What would you like to do?", comment: "你想要做什么？")
        alert.addButton(withTitle: NSLocalizedString("Find More Photos", comment: "查找更多照片"))
        alert.addButton(withTitle: NSLocalizedString("Merge into Person...", comment: "合并到已有分组..."))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "取消"))
        alert.beginSheetModal(for: window) { [weak self] response in
            switch response {
            case .alertFirstButtonReturn:
                self?.searchByFaceId(faceId)
            case .alertSecondButtonReturn:
                self?.mergeFaceIntoPerson(faceId)
            default:
                break
            }
        }
    }

    private func mergeFaceIntoPerson(_ faceId: String) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let allPersons = try await FaceService.shared.getPersons()
                await MainActor.run {
                    guard let window = view.window, !allPersons.isEmpty else { return }
                    let picker = PersonPickerPopover(persons: allPersons) { targetId in
                        Task { [weak self] in
                            guard let self = self else { return }
                            do {
                                try await FaceService.shared.mergeFace(faceId: faceId, intoPersonId: targetId)
                            } catch {
                                log("Merge face failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxX)
                }
            } catch {
                log("Load persons for merge failed: \(error.localizedDescription)")
            }
        }
    }

    /// From overlay face click: search by face ID
    private func searchByFaceId(_ faceId: String) {
        hideFaceOverlay()
        reverseImageSearchTask?.cancel()
        search_aiDebounceTask?.cancel()
        faceSearchTask?.cancel()
        faceSearchTask = Task { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            do {
                let matches = try await FaceService.shared.searchFacesByFaceId(faceId: faceId, topK: 100, minScore: 0.5)
                guard !Task.isCancelled else { return }
                let uniquePhotos = Array(Set(matches.map(\.photoPath))).sorted()
                try Task.checkCancellation()
                await MainActor.run { applyFaceFilter(photoPaths: uniquePhotos) }
            } catch {
                guard !Task.isCancelled else { return }
                log("Face search by ID failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("Face search failed: %@", comment: "人脸搜索失败"), error.localizedDescription), timeOut: 3.0)
                }
            }
        }
    }

    /// From person browser: show all photos for a person
    private func searchPhotosByPerson(_ personId: String) {
        log("Face: searchPhotosByPerson \(personId)")
        reverseImageSearchTask?.cancel()
        search_aiDebounceTask?.cancel()
        faceSearchTask?.cancel()
        faceSearchTask = Task { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            do {
                let photos = try await FaceService.shared.getPersonPhotos(id: personId)
                guard !Task.isCancelled else { return }
                log("Face: got \(photos.count) photos for person \(personId)")
                if photos.isEmpty {
                    log("Face: no photos for person \(personId)")
                }
                try Task.checkCancellation()
                await MainActor.run { applyFaceFilter(photoPaths: photos) }
            } catch {
                guard !Task.isCancelled else { return }
                log("Face: search by person failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("Face search failed: %@", comment: "人脸搜索失败"), error.localizedDescription), timeOut: 3.0)
                }
            }
        }
    }

    /// From context menu "Search Faces...": search by reference image
    @objc func searchFacesInImage(_ sender: Any?) {
        guard globalVar.imageAIEnabled else {
            coreAreaView.showInfo(NSLocalizedString("AI features are disabled", comment: "AI 功能未开启"), timeOut: 3.0)
            return
        }
        guard let selectedPaths = getSelectedImagePaths(), !selectedPaths.isEmpty else {
            log("Face: searchFacesInImage no selected image paths")
            return
        }
        let path = selectedPaths[0]
        guard let url = URL(string: path) else {
            log("Face: searchFacesInImage invalid URL for path \(path)")
            return
        }

        log("Face: searchFacesInImage starting for \(url.path)")
        reverseImageSearchTask?.cancel()
        search_aiDebounceTask?.cancel()
        faceSearchTask?.cancel()
        faceSearchTask = Task { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            do {
                try await FaceService.shared.indexFaces(path: url.path)
                guard !Task.isCancelled else { return }
                let matches = try await FaceService.shared.searchFacesByImage(path: url.path, topK: 100, minScore: 0.5)
                guard !Task.isCancelled else { return }
                let uniquePhotos = Array(Set(matches.map(\.photoPath))).sorted()
                try Task.checkCancellation()
                await MainActor.run { applyFaceFilter(photoPaths: uniquePhotos) }
            } catch {
                guard !Task.isCancelled else { return }
                log("Face search failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("Face search failed: %@", comment: "人脸搜索失败"), error.localizedDescription), timeOut: 3.0)
                }
            }
        }
    }

    private func getSelectedImagePaths() -> [String]? {
        if publicVar.isInLargeView {
            return [largeImageView.file.path]
        }
        return publicVar.selectedUrls().map(\.absoluteString)
    }
}
