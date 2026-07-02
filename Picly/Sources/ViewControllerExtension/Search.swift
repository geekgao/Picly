//
//  Search.swift
//  Picly
//

import Foundation
import Cocoa
import AVFoundation
import DiskArbitration
import BTree
import CoreLocation

extension ViewController {
    
    class SearchOverlayView: NSView {
        // weak var searchField: NSSearchField?
        weak var containerView: NSView?
        weak var viewController: ViewController?
        
        override func mouseDown(with event: NSEvent) {
            let location = event.locationInWindow
            let point = convert(location, from: nil)
            
            if let containerView = containerView, !containerView.frame.contains(point) {
                viewController?.closeSearchOverlay()
            }
        }
    }

    func showSearchOverlay() {
        if publicVar.isInLargeView {return}
        if searchOverlay == nil {

            // 创建半透明背景，使用自定义 SearchOverlayView
            // Create semi-transparent background using custom SearchOverlayView
            let overlay = SearchOverlayView(frame: view.bounds)
            overlay.wantsLayer = true
            overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.0).cgColor
            
            let checkboxFontSize = NSFont.systemFontSize + 1
            let fullPathCheckboxTitle = NSLocalizedString("Use Full Path", comment: "使用完整路径")
            let fullPathCheckboxWidth = 25 + fullPathCheckboxTitle.size(withAttributes: [.font: NSFont.systemFont(ofSize: checkboxFontSize)]).width
            let filterButtonTitle = NSLocalizedString("Apply Filter", comment: "应用筛选")
            let filterButtonFont = NSFont.systemFont(ofSize: 13.5)
            let filterButtonWidth = 25 + filterButtonTitle.size(withAttributes: [.font: filterButtonFont]).width.rounded()
            let btnSize = CGSize(width: 34, height: 28)
            let checkboxH: CGFloat = 22
            let rightButtonsTotalWidth: CGFloat = filterButtonWidth + btnSize.width * 3 + 5 + 5 + 5 + 5  // filter + color + geo + ai + spacing
            var bottomRowLeftWidth: CGFloat = 0
            bottomRowLeftWidth += publicVar.isRecursiveMode ? fullPathCheckboxWidth + 5 : 0
            let containerWidth = 12 + max(bottomRowLeftWidth, 220 + rightButtonsTotalWidth)
            let searchFieldWidth = containerWidth - 12
            
            // 创建搜索框容器视图 - 增加高度以容纳两行
            // Create search box container view - increase height to accommodate two rows
            let containerHeight: CGFloat = 82
            let topRowY: CGFloat = 40
            let bottomRowY: CGFloat = 8
            let containerView = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
            let effectView = NSVisualEffectView(frame: containerView.bounds)
            effectView.autoresizingMask = [.width, .height]
            effectView.material = .popover
            effectView.blendingMode = .withinWindow
            effectView.state = .active
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = 10
            effectView.layer?.masksToBounds = true
            containerView.addSubview(effectView)
            
            // 创建搜索框 - 放在上面一行
            // Create search box - place on top row
            searchField = NSSearchField(frame: NSRect(x: 6, y: topRowY, width: searchFieldWidth, height: 34))
            searchField?.placeholderString = NSLocalizedString("Search...", comment: "搜索...")
            searchField?.stringValue = search_searchText
            searchField?.delegate = self
            searchField?.target = self
            searchField?.action = #selector(searchFieldDidChange(_:))
            searchField?.focusRingType = .none
            if let cell = searchField?.cell as? NSSearchFieldCell {
                cell.font = NSFont.systemFont(ofSize: 14)
            }
            
            // AI 搜索状态标签 - 默认隐藏
            // AI search status label - hidden by default
            let aiLabel = NSTextField(labelWithString: NSLocalizedString("AI Searching...", comment: "AI搜索中..."))
            aiLabel.frame = NSRect(x: 6, y: bottomRowY, width: 200, height: checkboxH)
            aiLabel.font = NSFont.systemFont(ofSize: 13)
            aiLabel.textColor = .secondaryLabelColor
            aiLabel.isHidden = true
            searchAILabel = aiLabel

            // Geo 搜索状态标签 - 默认隐藏
            let geoLabel = NSTextField(labelWithString: "")
            geoLabel.frame = NSRect(x: 6, y: bottomRowY, width: 200, height: checkboxH)
            geoLabel.font = NSFont.systemFont(ofSize: 13)
            geoLabel.textColor = .secondaryLabelColor
            geoLabel.isHidden = true
            searchGeoLabel = geoLabel

            // 创建 AI 搜索模式切换按钮
            // Create AI search mode toggle button
            let aiButton = NSButton()
            aiButton.bezelStyle = .rounded
            aiButton.isBordered = true
            aiButton.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "AI Search")
            aiButton.imagePosition = .imageOnly
            aiButton.target = self
            aiButton.action = #selector(aiSearchButtonClicked(_:))
            searchAIModeButton = aiButton

            // 创建地理位置搜索模式切换按钮
            // Create geolocation search mode toggle button
            let geoButton = NSButton()
            geoButton.bezelStyle = .rounded
            geoButton.isBordered = true
            geoButton.image = NSImage(systemSymbolName: "mappin.and.ellipse", accessibilityDescription: "Location Search")
            geoButton.imagePosition = .imageOnly
            geoButton.target = self
            geoButton.action = #selector(geoSearchButtonClicked(_:))
            searchGeoModeButton = geoButton

            // 创建颜色搜索模式切换按钮
            // Create color search mode toggle button
            let colorButton = NSButton()
            colorButton.bezelStyle = .rounded
            colorButton.isBordered = true
            colorButton.image = NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: "Color Search")
            colorButton.imagePosition = .imageOnly
            colorButton.target = self
            colorButton.action = #selector(colorSearchButtonClicked(_:))
            searchColorModeButton = colorButton
            // Create use full path checkbox - place on bottom row
            let fullPathCheckbox = NSButton(checkboxWithTitle: fullPathCheckboxTitle, target: self, action: #selector(fullPathCheckboxChanged(_:)))
            fullPathCheckbox.frame = NSRect(x: 6, y: bottomRowY, width: fullPathCheckboxWidth, height: checkboxH)
            fullPathCheckbox.state = search_isUseFullPath ? .on : .off
            searchFullPathCheckbox = fullPathCheckbox
            
            // 创建应用筛选按钮 - 放在右侧
            // Create apply filter button - place on right side
            let filterButtonX = containerWidth - 6 - filterButtonWidth
            let filterButton = NSButton(frame: NSRect(x: filterButtonX, y: bottomRowY, width: filterButtonWidth, height: btnSize.height))
            filterButton.title = filterButtonTitle
            filterButton.font = filterButtonFont
            filterButton.bezelStyle = .regularSquare
            filterButton.target = self
            filterButton.action = #selector(filterButtonClicked(_:))
            filterButton.isEnabled = !search_searchText.isEmpty
            searchFilterButton = filterButton

            // 创建 AI 搜索按钮 - 放在筛选按钮左边
            // Create AI search button - place to the left of filter button
            let aiButtonX = filterButtonX - 5 - btnSize.width
            aiButton.frame = NSRect(x: aiButtonX, y: bottomRowY, width: btnSize.width, height: btnSize.height)

            // 创建地理搜索按钮 - 放在 AI 按钮左边
            let geoButtonX = aiButtonX - 5 - btnSize.width
            geoButton.frame = NSRect(x: geoButtonX, y: bottomRowY, width: btnSize.width, height: btnSize.height)

            // 创建颜色搜索按钮 - 放在地理搜索按钮左边
            let colorButtonX = geoButtonX - 5 - btnSize.width
            colorButton.frame = NSRect(x: colorButtonX, y: bottomRowY, width: btnSize.width, height: btnSize.height)

            // 添加所有控件到容器视图
            // Add all controls to container view
            containerView.addSubview(searchField!)
            if publicVar.isRecursiveMode {
                containerView.addSubview(fullPathCheckbox)
            }
            containerView.addSubview(colorButton)
            containerView.addSubview(geoButton)
            containerView.addSubview(aiButton)
            containerView.addSubview(filterButton)
            containerView.addSubview(aiLabel)
            containerView.addSubview(geoLabel)
            
            // 设置容器视图位置
            // Set container view position
            if view.userInterfaceLayoutDirection == .rightToLeft {
                containerView.frame.origin.x = 30
            } else {
                containerView.frame.origin.x = view.bounds.width - containerView.frame.width - 30
            }
            containerView.frame.origin.y = view.bounds.height - containerView.frame.height - 20
            // 另外注意在viewDidLayout()中实时调整位置
            // Also note: adjust position in real-time in viewDidLayout()
            
            overlay.addSubview(containerView)
            
            // 设置引用
            // Set references
            overlay.containerView = containerView
            overlay.viewController = self
            searchOverlay = overlay
            
            view.addSubview(searchOverlay!)
            
        }
        
        if let containerView = searchOverlay?.containerView {
            containerView.wantsLayer = true
            containerView.layer?.cornerRadius = 10
            containerView.layer?.masksToBounds = false
            containerView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.3).cgColor
            containerView.layer?.shadowOffset = CGSize(width: 0, height: -4)
            containerView.layer?.shadowRadius = 12
            containerView.layer?.shadowOpacity = 0.5
        }
        
        // 如果 AI 过滤仍活跃，恢复 AI 模式 UI
        // Restore AI mode UI if AI filter is still active
        if publicVar.isAIFilterOn && !search_isAIMode {
            search_isAIMode = true
        }
        // 恢复地理搜索模式
        if publicVar.isGeoFilterOn && !search_isGeoMode {
            search_isGeoMode = true
        }
        // 恢复颜色搜索模式
        if publicVar.isColorFilterOn && !search_isColorMode {
            search_isColorMode = true
        }
        updateAIModeUI()
        updateGeoModeUI()
        updateColorModeUI()
        
        publicVar.isKeyEventEnabled = false
        publicVar.isInSearchState = true
        // searchOverlay?.isHidden = false
        searchField?.becomeFirstResponder()
    }

    @objc func closeSearchOverlay() {
        publicVar.isKeyEventEnabled = true
        publicVar.isInSearchState = false
//        if searchOverlay?.isHidden == false {
//            searchOverlay?.isHidden = true
//            view.window?.makeFirstResponder(collectionView)
//        }
        search_aiDebounceTask?.cancel()
        search_geocoder = nil
        search_isAIMode = false
        search_isGeoMode = false
        search_isColorMode = false
        publicVar.isColorFilterOn = false
        publicVar.colorFilterPaths = []
        searchColorPickedColors.removeAll()
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: NSColorPanel.shared)
        NSColorPanel.shared.orderOut(nil)
        publicVar.isGeolocationSearchMode = false
        if searchOverlay != nil {
            searchOverlay?.removeFromSuperview()
            searchOverlay = nil
            searchField = nil
            searchAIModeButton = nil
            searchFilterButton = nil
            searchFullPathCheckbox = nil
            searchAILabel = nil
            searchGeoModeButton = nil
            searchGeoLabel = nil
            searchColorModeButton = nil
            view.window?.makeFirstResponder(collectionView)
        }
    }
    
    func updateAIModeUI() {
        guard let aiBtn = searchAIModeButton else { return }
        let isAI = search_isAIMode
        aiBtn.state = isAI ? .on : .off
        aiBtn.contentTintColor = isAI ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
        aiBtn.bezelColor = isAI ? NSColor.controlAccentColor.withAlphaComponent(0.2) : nil
        
        searchFullPathCheckbox?.isHidden = isAI || search_isGeoMode || search_isColorMode
        searchFilterButton?.isEnabled = (isAI || search_isGeoMode || search_isColorMode) ? false : !search_searchText.isEmpty
        searchAILabel?.isHidden = !isAI || !publicVar.aiIsSearching
        if isAI {
            searchField?.placeholderString = NSLocalizedString("AI Search...", comment: "AI搜索...")
        } else if search_isGeoMode {
            searchField?.placeholderString = NSLocalizedString("Location Search...", comment: "地理位置搜索...")
        } else if search_isColorMode {
            searchField?.placeholderString = NSLocalizedString("Color code e.g. #FF0000 or 255,0,0", comment: "颜色代码输入提示")
        } else {
            searchField?.placeholderString = NSLocalizedString("Search...", comment: "搜索...")
        }
    }

    func updateGeoModeUI() {
        guard let geoBtn = searchGeoModeButton else { return }
        let isGeo = search_isGeoMode
        geoBtn.state = isGeo ? .on : .off
        geoBtn.contentTintColor = isGeo ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
        geoBtn.bezelColor = isGeo ? NSColor.controlAccentColor.withAlphaComponent(0.2) : nil
        searchGeoLabel?.isHidden = true
        updateAIModeUI()
    }

    /// Parse a color code string to (r, g, b) in 0-1 range.
    /// Supports: #RRGGBB, #RGB, R,G,B, R G B (0-255 or 0.0-1.0).
    private func parseColorCode(_ text: String) -> (r: Double, g: Double, b: Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // #RRGGBB or #RGB
        if trimmed.hasPrefix("#") {
            let hex = String(trimmed.dropFirst())
            if hex.count == 6 {
                if let val = Int(hex, radix: 16) {
                    return (Double((val >> 16) & 0xFF) / 255.0,
                            Double((val >> 8) & 0xFF) / 255.0,
                            Double(val & 0xFF) / 255.0)
                }
            }
            if hex.count == 3 {
                if let val = Int(hex, radix: 16) {
                    let r = Double((val >> 8) & 0xF) / 15.0
                    let g = Double((val >> 4) & 0xF) / 15.0
                    let b = Double(val & 0xF) / 15.0
                    return (r, g, b)
                }
            }
            return nil
        }

        // R,G,B or R G B — comma or space separated
        let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: ", "))
            .filter { !$0.isEmpty }
        guard parts.count == 3 else { return nil }

        let values = parts.compactMap { Double($0) }
        guard values.count == 3 else { return nil }

        // Detect whether values are in 0-255 or 0.0-1.0 range
        if values.allSatisfy({ $0 > 1.0 }) {
            return (values[0] / 255.0, values[1] / 255.0, values[2] / 255.0)
        }
        return (values[0], values[1], values[2])
    }

    func updateColorModeUI() {
        guard let colorBtn = searchColorModeButton else { return }
        let isColor = search_isColorMode
        colorBtn.state = isColor ? .on : .off
        colorBtn.contentTintColor = isColor ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
        colorBtn.bezelColor = isColor ? NSColor.controlAccentColor.withAlphaComponent(0.2) : nil
        updateAIModeUI()
    }

    @objc func colorSearchButtonClicked(_ sender: NSButton) {
        guard globalVar.imageAIEnabled else {
            showInformationLong(title: NSLocalizedString("Info", comment: "说明"), message: NSLocalizedString("AI search is disabled. Enable it in Settings > Advanced.", comment: "AI搜索未启用"))
            return
        }
        let wasColorFilterOn = publicVar.isColorFilterOn
        search_isColorMode.toggle()
        if search_isColorMode {
            search_aiDebounceTask?.cancel()
            search_geocoder = nil
            search_isAIMode = false
            search_isGeoMode = false
            publicVar.isGeolocationSearchMode = false
            publicVar.isGeoFilterOn = false
            publicVar.geoFilterPaths = []
            publicVar.isAIFilterOn = false
            publicVar.aiFilterPaths = []
            searchColorPickedColors.removeAll()
            // Show color picker — search triggers when panel closes
            NSColorPanel.shared.showsAlpha = false
            NotificationCenter.default.addObserver(self, selector: #selector(colorPanelWillClose(_:)), name: NSWindow.willCloseNotification, object: NSColorPanel.shared)
            NSColorPanel.shared.orderFront(nil)
            searchField?.stringValue = ""
            search_searchText = ""
            searchField?.placeholderString = NSLocalizedString("Color code e.g. #FF0000 or 255,0,0", comment: "颜色代码输入提示")
        } else {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: NSColorPanel.shared)
            NSColorPanel.shared.orderOut(nil)
            publicVar.isColorFilterOn = false
            publicVar.colorFilterPaths = []
            searchColorPickedColors.removeAll()
            updateColorModeUI()
            if wasColorFilterOn {
                applyColorFilter()
                publicVar.updateToolbar()
            }
        }
        updateColorModeUI()
        updateGeoModeUI()
    }

    @objc private func colorPanelWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: NSColorPanel.shared)
        guard search_isColorMode else { return }
        let nsColor = NSColorPanel.shared.color
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))

        let hex = String(format: "#%02X%02X%02X", r, g, b)
        searchField?.stringValue = hex
        search_searchText = hex

        searchColorPickedColors = [(Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))]
        performColorSearch()
    }

    func performColorSearch() {
        guard search_isColorMode, !searchColorPickedColors.isEmpty else { return }

        search_aiDebounceTask?.cancel()
        search_aiDebounceTask = Task { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            await MainActor.run {
                self.publicVar.aiIsSearching = true
                self.startIndeterminate()
            }
            do {
                let results = try await ImageAIService.shared.searchByColor(colors: searchColorPickedColors, tolerance: 0.15, topK: 500)
                guard !Task.isCancelled else { return }
                let allPaths = results.compactMap { URL(fileURLWithPath: $0.image.path).absoluteString }
                let folderPrefix = fileDB.curFolder.hasSuffix("/") ? fileDB.curFolder : fileDB.curFolder + "/"
                let paths = allPaths.filter { $0.hasPrefix(folderPrefix) }
                await MainActor.run { [paths] in
                    guard !Task.isCancelled else { return }
                    self.publicVar.aiIsSearching = false
                    self.hideProgress()
                    if paths.isEmpty {
                        self.coreAreaView.showInfo(NSLocalizedString("No images matching these colors", comment: "颜色搜索无匹配"), timeOut: 2.0)
                        return
                    }
                    self.publicVar.colorFilterPaths = paths
                    self.publicVar.isColorFilterOn = true
                    self.applyColorFilter()
                    publicVar.updateToolbar()
                    coreAreaView.showInfo(String(format: NSLocalizedString("Found %d images matching colors", comment: "颜色搜索结果数"), paths.count), timeOut: 2.0)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.publicVar.aiIsSearching = false
                    self.hideProgress()
                    log("Color search error: \(error.localizedDescription)")
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("Color search failed: %@", comment: "颜色搜索失败"), error.localizedDescription), timeOut: 3.0)
                }
            }
        }
    }

    func applyColorFilter() {
        publicVar.isFilenameFilterOn = false
        publicVar.isAIFilterOn = false
        publicVar.isGeoFilterOn = false
        let isFiltering = publicVar.isColorFilterOn && !publicVar.colorFilterPaths.isEmpty
        dirURLCache.removeAll()

        if isFiltering {
            fileDB.lock()
            guard let dirModel = fileDB.db[SortKeyDir(fileDB.curFolder)] else {
                fileDB.unlock()
                return
            }
            var refSize = DEFAULT_SIZE
            for (_, file) in dirModel.files {
                if let size = file.originalSize, size.width > 0, size.height > 0 {
                    refSize = size
                    break
                }
            }

            let colorSet = Set(publicVar.colorFilterPaths)
            var filtered = [(SortKeyFile, FileModel)]()
            var seenPaths = Set<String>()
            for (key, file) in dirModel.files {
                if colorSet.contains(file.path) {
                    filtered.append((key, file))
                    seenPaths.insert(file.path)
                }
            }
            let sortType = publicVar.profile.sortType
            let isSortFolderFirst = publicVar.profile.isSortFolderFirst
            let isSortUseFullPath = publicVar.profile.isSortUseFullPath
            for path in publicVar.colorFilterPaths {
                guard !seenPaths.contains(path) else { continue }
                let sortKey = SortKeyFile(path, createDate: Date(), modDate: Date(), addDate: Date(), size: 0, isDir: false, isInSameDir: false, sortType: sortType, isSortFolderFirst: isSortFolderFirst, isSortUseFullPath: isSortUseFullPath, randomSeed: 0)
                let fileModel = FileModel(path: path, ver: fileDB.ver, isDir: false)
                fileModel.originalSize = refSize
                fileModel.canBeCalcued = true
                let url = URL(string: path)
                fileModel.ext = url?.pathExtension.lowercased() ?? ""
                fileModel.type = globalVar.HandledImageExtensions.contains(fileModel.ext) ? .image : .other
                filtered.append((sortKey, fileModel))
            }
            filtered.sort { $0.0 < $1.0 }
            for (_, file) in filtered {
                if file.originalSize == nil || file.originalSize!.width == 0 {
                    file.originalSize = refSize
                }
                file.canBeCalcued = true
            }
            dirModel.files = Map<SortKeyFile, FileModel>(sortedElements: filtered)
            dirModel.aiOrderedPaths = []
            dirModel.isFiltered = true

            fileDB.ver += 1
            dirModel.ver = fileDB.ver
            var id = 0; var idInImage = 0; var idInImageAndVideo = 0
            var imageCount = 0; var videoCount = 0
            for (_, file) in dirModel.files {
                file.ver = fileDB.ver
                if !file.isDir {
                    let ext = file.ext
                    if publicVar.HandledImageAndRawExtensions.contains(ext) {
                        file.idInImage = idInImage; idInImage += 1
                        imageCount += 1
                    }
                    if publicVar.HandledFileExtensions.contains(ext) {
                        file.id = id; id += 1
                    }
                    if publicVar.HandledImageAndRawExtensions.contains(ext) || publicVar.HandledVideoExtensions.contains(ext) {
                        file.idInImageAndVideo = idInImageAndVideo; idInImageAndVideo += 1
                    }
                    if publicVar.HandledVideoExtensions.contains(ext) {
                        videoCount += 1
                    }
                }
            }
            dirModel.imageCount = imageCount
            dirModel.videoCount = videoCount
            dirModel.fileCount = id
            dirModel.layoutCalcPos = 0
            fileDB.unlock()

            readInfoTaskPoolLock.lock()
            readInfoTaskPool.removeAll()
            readInfoTaskPoolLock.unlock()
            let curFolder = fileDB.curFolder
            recalcLayout(curFolder)
            refreshCollectionView(needLoadThumbPriority: true)
        } else {
            fileDB.lock()
            let curFolder = fileDB.curFolder
            fileDB.unlock()
            if let folderURL = URL(string: curFolder) {
                DirMetadataCache.shared.removeCache(for: folderURL)
            }
            refreshCollectionView(needLoadThumbPriority: true)
        }
    }

    @objc func geoSearchButtonClicked(_ sender: NSButton) {
        let wasGeoFilterOn = publicVar.isGeoFilterOn
        search_isGeoMode.toggle()
        search_isColorMode = false
        search_isAIMode = false
        search_aiDebounceTask?.cancel()
        search_geocoder = nil
        publicVar.isGeolocationSearchMode = search_isGeoMode
        if !search_isGeoMode {
            publicVar.isGeoFilterOn = false
            publicVar.geoFilterPaths = []
            publicVar.isAIFilterOn = false
            publicVar.isColorFilterOn = false
            publicVar.colorFilterPaths = []
            updateGeoModeUI()
            if wasGeoFilterOn {
                searchField?.stringValue = ""
                search_searchText = ""
                searchFilterButton?.isEnabled = false
                applyGeoFilter()
                publicVar.updateToolbar()
            }
        } else {
            updateGeoModeUI()
        }
    }

    func performGeoSearch(_ query: String) {
        guard !query.isEmpty else {
            publicVar.isGeoFilterOn = false
            publicVar.geoFilterPaths = []
            searchGeoLabel?.isHidden = true
            if publicVar.isFilenameFilterOn {
                applyFilter()
            } else {
                refreshCollectionView(needLoadThumbPriority: true)
            }
            return
        }

        // Cancel any in-flight geocoding request by releasing the old geocoder
        search_geocoder = nil

        searchGeoLabel?.stringValue = NSLocalizedString("Geocoding...", comment: "地理编码中...")
        searchGeoLabel?.isHidden = false

        let geocoder = CLGeocoder()
        search_geocoder = geocoder

        geocoder.geocodeAddressString(query) { [weak self] placemarks, error in
            guard let self = self, self.search_isGeoMode else { return }
            self.search_geocoder = nil
            DispatchQueue.main.async {
                self.searchGeoLabel?.isHidden = true
                if let error = error as? CLError {
                    switch error.code {
                    case .geocodeFoundNoResult, .geocodeFoundPartialResult:
                        self.coreAreaView.showInfo(String(format: NSLocalizedString("Location not found: \"%@\"", comment: "未找到位置"), query), timeOut: 2.0)
                    case .network:
                        self.coreAreaView.showInfo(NSLocalizedString("Geocode failed: network unavailable", comment: "地理编码无网络"), timeOut: 3.0)
                    case .geocodeCanceled:
                        break
                    default:
                        self.coreAreaView.showInfo(String(format: NSLocalizedString("Geocode failed: %@", comment: "地理编码失败"), error.localizedDescription), timeOut: 3.0)
                    }
                    return
                }
                if let error = error {
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("Geocode failed: %@", comment: "地理编码失败"), error.localizedDescription), timeOut: 3.0)
                    return
                }
                guard let placemarks = placemarks, !placemarks.isEmpty else {
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("Location not found: %@", comment: "未找到位置"), query), timeOut: 2.0)
                    return
                }
                if GeoCache.shared.count == 0 {
                    self.coreAreaView.showInfo(NSLocalizedString("No GPS data found. Browse photos first to index their location.", comment: "无GPS索引"), timeOut: 4.0)
                    return
                }

                // Check if all results are POI-level (region < 1km) — CLGeocoder likely
                // returned local businesses instead of the geographic entity the user meant.
                let allArePOI = placemarks.allSatisfy { pm in
                    (pm.region as? CLCircularRegion)?.radius ?? 0 < 1000
                }

                // Fallback country coordinates when CLGeocoder returns local POIs
                // instead of the country the user meant (common on macOS in CJK locales).
                // Only countries — city-level disambiguation is the user's responsibility
                // (type "Arezzo Italy" not just "Arezzo").
                let fallbackCountries: [String: (lat: Double, lon: Double)] = [
                    "italy": (41.8719, 12.5674),
                    "意大利": (41.8719, 12.5674),
                    "france": (46.6034, 1.8883),
                    "法国": (46.6034, 1.8883),
                    "germany": (51.1657, 10.4515),
                    "德国": (51.1657, 10.4515),
                    "spain": (40.4637, -3.7492),
                    "西班牙": (40.4637, -3.7492),
                    "japan": (36.2048, 138.2529),
                    "日本": (36.2048, 138.2529),
                    "china": (35.8617, 104.1954),
                    "中国": (35.8617, 104.1954),
                    "uk": (55.3781, -3.4360),
                    "united kingdom": (55.3781, -3.4360),
                    "英国": (55.3781, -3.4360),
                    "usa": (39.8283, -98.5795),
                    "united states": (39.8283, -98.5795),
                    "美国": (39.8283, -98.5795),
                    "australia": (-25.2744, 133.7751),
                    "澳大利亚": (-25.2744, 133.7751),
                    "canada": (56.1304, -106.3468),
                    "加拿大": (56.1304, -106.3468),
                    "switzerland": (46.8182, 8.2275),
                    "瑞士": (46.8182, 8.2275),
                    "netherlands": (52.1326, 5.2913),
                    "荷兰": (52.1326, 5.2913),
                    "korea": (35.9078, 127.7669),
                    "韩国": (35.9078, 127.7669),
                    "thailand": (15.8700, 100.9925),
                    "泰国": (15.8700, 100.9925),
                ]

                var allPaths = Set<String>()
                var foundPlaceName: String?

                // Helper: search GeoCache around one coordinate with adaptive radius
                func searchAround(lat: Double, lon: Double, radiusKm: Double, label: String) {
                    log("GeoSearch: \(label) -> \(String(format: "%.4f,%.4f", lat, lon))  radius=\(String(format: "%.0f", radiusKm))km")
                    let results = GeoCache.shared.search(lat: lat, lon: lon, radiusKm: radiusKm)
                    for r in results {
                        allPaths.insert(r.path)
                    }
                }

                // 1. Try CLGeocoder results
                for pm in placemarks {
                    guard let loc = pm.location else { continue }
                    let coord = loc.coordinate
                    let regionRadius = (pm.region as? CLCircularRegion)?.radius ?? 0
                    let radiusKm: Double
                    if regionRadius < 1000 {
                        radiusKm = 50.0
                    } else {
                        radiusKm = max(min(regionRadius / 1000.0 * 1.5, 500.0), 50.0)
                    }
                    searchAround(lat: coord.latitude, lon: coord.longitude, radiusKm: radiusKm, label: (pm.name ?? "?") + " [query: \(query)]")
                    if foundPlaceName == nil { foundPlaceName = pm.name }
                }

                // 2. Fallback: when the query contains a known country name, search
                // with built-in country center coordinates (500 km radius).
                // City-level disambiguation ("Arezzo" → Arezzo, Italy vs HK building)
                // is the user's responsibility — add "Italy" to the query.
                let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
                let matchedCountry = fallbackCountries
                    .filter { queryLower.contains($0.key) }
                    .sorted { $0.key.count > $1.key.count }
                    .first
                if let (countryKey, fb) = matchedCountry {
                    if allArePOI {
                        log("GeoSearch: CL results are POI-level; discarding, using fallback '\(countryKey)'")
                        allPaths.removeAll()
                    } else {
                        log("GeoSearch: also searching fallback '\(countryKey)'")
                    }
                    foundPlaceName = query
                    searchAround(lat: fb.lat, lon: fb.lon, radiusKm: 500.0, label: "fallback: \(countryKey)")
                }

                if allPaths.isEmpty {
                    let coords = placemarks.compactMap { $0.location?.coordinate }
                    let coordStr = coords.map { String(format: "%.4f,%.4f", $0.latitude, $0.longitude) }.joined(separator: "; ")
                    log("GeoSearch: no results for \(query) — geocoded to \(coordStr)")
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("No photos near %@", comment: "附近无匹配"), query), timeOut: 3.0)
                    return
                }

                let folderPrefix = self.fileDB.curFolder.hasSuffix("/") ? self.fileDB.curFolder : self.fileDB.curFolder + "/"
                let knownPaths = Set(self.fileDB.db[SortKeyDir(self.fileDB.curFolder)]?.files.map { $0.1.path } ?? [])
                let scopedPaths = allPaths.filter { $0.hasPrefix(folderPrefix) && knownPaths.contains($0) }

                if scopedPaths.isEmpty {
                    self.coreAreaView.showInfo(String(format: NSLocalizedString("Geo results only in other folders — navigate to the folder and search again", comment: "搜索结果在其他文件夹"), allPaths.count), timeOut: 3.0)
                    return
                }

                self.publicVar.geoFilterPaths = Array(scopedPaths)
                self.publicVar.isGeoFilterOn = true
                self.applyGeoFilter()
                self.publicVar.updateToolbar()
                let placeName = foundPlaceName ?? query
                self.coreAreaView.showInfo(String(format: NSLocalizedString("Found %d photos near %@", comment: "找到照片数"), scopedPaths.count, placeName), timeOut: 2.0)
            }
        }
    }

    func applyGeoFilter() {
        publicVar.isFilenameFilterOn = false
        publicVar.isAIFilterOn = false
        publicVar.isColorFilterOn = false
        let isFiltering = publicVar.isGeoFilterOn && !publicVar.geoFilterPaths.isEmpty
        dirURLCache.removeAll()

        if isFiltering {
            fileDB.lock()
            guard let dirModel = fileDB.db[SortKeyDir(fileDB.curFolder)] else {
                fileDB.unlock()
                return
            }
            let geoSet = Set(publicVar.geoFilterPaths)
            var filtered = [(SortKeyFile, FileModel)]()
            for (key, file) in dirModel.files {
                if geoSet.contains(file.path) {
                    filtered.append((key, file))
                }
            }
            filtered.sort { $0.0 < $1.0 }
            dirModel.files = Map<SortKeyFile, FileModel>(sortedElements: filtered)
            dirModel.aiOrderedPaths = []
            dirModel.isFiltered = true

            fileDB.ver += 1
            dirModel.ver = fileDB.ver
            var id = 0; var idInImage = 0; var idInImageAndVideo = 0
            var imageCount = 0; var videoCount = 0
            for (_, file) in dirModel.files {
                file.ver = fileDB.ver
                if !file.isDir {
                    let ext = file.ext
                    if publicVar.HandledImageAndRawExtensions.contains(ext) {
                        file.idInImage = idInImage; idInImage += 1
                        imageCount += 1
                    }
                    if publicVar.HandledFileExtensions.contains(ext) {
                        file.id = id; id += 1
                    }
                    if publicVar.HandledImageAndRawExtensions.contains(ext) || publicVar.HandledVideoExtensions.contains(ext) {
                        file.idInImageAndVideo = idInImageAndVideo; idInImageAndVideo += 1
                    }
                    if publicVar.HandledVideoExtensions.contains(ext) {
                        videoCount += 1
                    }
                }
            }
            dirModel.imageCount = imageCount
            dirModel.videoCount = videoCount
            dirModel.fileCount = id
            dirModel.layoutCalcPos = min(dirModel.layoutCalcPos, dirModel.files.count)
            fileDB.unlock()

            readInfoTaskPoolLock.lock()
            readInfoTaskPool.removeAll()
            readInfoTaskPoolLock.unlock()
            loadImageTaskPool.lock.lock()
            loadImageTaskPool.removeAllQueue()
            collectionView.reloadData()
            collectionView.collectionViewLayout?.invalidateLayout()
            collectionView.layoutSubtreeIfNeeded()

            fileDB.lock()
            let curFolder = fileDB.curFolder
            loadImageTaskPool.makeQueue(curFolder)
            if let dirModel = fileDB.db[SortKeyDir(curFolder)] {
                let loadCount = min(dirModel.files.count, 50)
                for i in 0..<loadCount {
                    if let file = dirModel.fileForDisplay(atOffset: i), file.image == nil,
                       let key = dirModel.files.first(where: { $0.1.path == file.path })?.0 {
                        loadImageTaskPool.pool[curFolder]?.insert((curFolder, dirModel, key, file, dirModel.ver, OtherTaskInfo(isFromScroll: true, isPriorityScheduled: true)), at: 0)
                        loadImageTaskPoolSemaphore.signal()
                    }
                }
            }
            fileDB.unlock()
            loadImageTaskPool.lock.unlock()
        } else {
            fileDB.lock()
            let curFolder = fileDB.curFolder
            fileDB.unlock()
            if let folderURL = URL(string: curFolder) {
                DirMetadataCache.shared.removeCache(for: folderURL)
            }
            refreshCollectionView(needLoadThumbPriority: true)
        }
    }

    @objc func aiSearchButtonClicked(_ sender: NSButton) {
        guard globalVar.imageAIEnabled else {
            showInformationLong(title: NSLocalizedString("Info", comment: "说明"), message: NSLocalizedString("AI search is disabled. Enable it in Settings > Advanced.", comment: "AI搜索未启用"))
            return
        }
        let wasAIFilterOn = publicVar.isAIFilterOn
        search_isAIMode.toggle()
        search_isColorMode = false
        if search_isAIMode {
            // Switching to AI — turn off geo mode
            search_geocoder = nil
            search_isGeoMode = false
            publicVar.isGeolocationSearchMode = false
            publicVar.isGeoFilterOn = false
            publicVar.geoFilterPaths = []
        }
        if !search_isAIMode {
            search_aiDebounceTask?.cancel()
            publicVar.isAIFilterOn = false
            publicVar.aiFilterPaths = []
            publicVar.isColorFilterOn = false
            publicVar.colorFilterPaths = []
            updateAIModeUI()
            updateGeoModeUI()
            if wasAIFilterOn {
                searchField?.stringValue = ""
                search_searchText = ""
                searchFilterButton?.isEnabled = false
                applyAIFilter()
                publicVar.updateToolbar()
            }
        } else {
            updateAIModeUI()
            updateGeoModeUI()
        }
    }
    
    func performAISearch(_ query: String) {
        search_aiDebounceTask?.cancel()
        guard !query.isEmpty else {
            publicVar.isAIFilterOn = false
            publicVar.aiFilterPaths = []
            if publicVar.isFilenameFilterOn {
                applyFilter()
            } else {
                refreshCollectionView(needLoadThumbPriority: true)
            }
            return
        }
        search_aiDebounceTask = Task { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            await MainActor.run {
                self.publicVar.aiIsSearching = true
                self.searchAILabel?.stringValue = NSLocalizedString("AI Searching...", comment: "AI搜索中...")
                self.searchAILabel?.isHidden = false
                self.startIndeterminate()
            }
            do {
                let filter = await parseNaturalLanguageFilter(from: query)
                // Send empty q for metadata-only queries (no content to search by)
                let searchQuery = filter.cleanedQuery.isEmpty ? "" : filter.cleanedQuery
                let results = try await ImageAIService.shared.search(query: searchQuery, topK: 200, filter: filter.filter)
                guard !Task.isCancelled else { return }
                log("AI search: query='\(searchQuery)' rawResults=\(results.count) hasFilter=\(filter.filter.hasAny)")
                let allPaths = results.compactMap { URL(fileURLWithPath: $0.image.path).absoluteString }
                let folderPrefix = fileDB.curFolder.hasSuffix("/") ? fileDB.curFolder : fileDB.curFolder + "/"
                let paths = allPaths.filter { $0.hasPrefix(folderPrefix) }
                await MainActor.run { [paths, query, allPaths] in
                    guard !Task.isCancelled else { return }
                    self.publicVar.aiIsSearching = false
                    self.searchAILabel?.isHidden = true
                    self.hideProgress()
                    if paths.isEmpty {
                        if allPaths.isEmpty {
                            coreAreaView.showInfo(String(format: NSLocalizedString("AI: no results for \"%@\"", comment: "AI搜索无结果"), query), timeOut: 2.0)
                        } else {
                            coreAreaView.showInfo(String(format: NSLocalizedString("AI: %d results in subfolders — navigate into subfolder to search", comment: "AI搜索结果在子文件夹中"), allPaths.count), timeOut: 3.0)
                        }
                        return
                    }
                    self.publicVar.aiFilterPaths = paths
                    self.publicVar.isAIFilterOn = true
                    self.applyAIFilter()
                    publicVar.updateToolbar()
                    let count = paths.count
                    coreAreaView.showInfo(String(format: NSLocalizedString("AI: %d results for \"%@\"", comment: "AI搜索结果数"), count, query), timeOut: 2.0)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.publicVar.aiIsSearching = false
                    self.searchAILabel?.isHidden = true
                    self.hideProgress()
                    log("AI search error: \(error.localizedDescription)")
                    coreAreaView.showInfo(String(format: NSLocalizedString("AI search failed: %@", comment: "AI搜索失败"), error.localizedDescription), timeOut: 3.0)
                }
            }
        }
    }

    private func parseNaturalLanguageFilter(from query: String) async -> (filter: SearchFilter, cleanedQuery: String) {
        var text = query
        var dateFrom: Date?
        var dateTo: Date?

        // Try each date pattern; first match wins
        let patterns: [(String, (Int, Int, Int) -> (Date, Date)?)] = [
            // "2025年10月22日" (Chinese with day)
            ("(\\d{4})年(\\d{1,2})月(\\d{1,2})日", { y, m, d in
                let cal = Calendar.current
                var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 0
                return cal.date(from: c).map { ($0, cal.date(byAdding: .day, value: 1, to: $0)!) }
            }),
            // "2025年10月" (Chinese month)
            ("(\\d{4})年(\\d{1,2})月", { y, m, _ in
                let cal = Calendar.current
                var c = DateComponents(); c.year = y; c.month = m; c.day = 1; c.hour = 0
                guard let from = cal.date(from: c) else { return nil }
                var nc = DateComponents(); nc.year = m == 12 ? y + 1 : y; nc.month = m == 12 ? 1 : m + 1; nc.day = 1
                return (from, cal.date(from: nc)!)
            }),
            // "2025年" (Chinese year)
            ("(\\d{4})年", { y, _, _ in
                let cal = Calendar.current
                var c = DateComponents(); c.year = y; c.month = 1; c.day = 1
                guard let from = cal.date(from: c) else { return nil }
                var nc = DateComponents(); nc.year = y + 1; nc.month = 1; nc.day = 1
                return (from, cal.date(from: nc)!)
            }),
            // "2008-10-22" (ISO)
            ("(\\d{4})-(\\d{1,2})-(\\d{1,2})", { y, m, d in
                let cal = Calendar.current
                var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 0
                return cal.date(from: c).map { ($0, cal.date(byAdding: .day, value: 1, to: $0)!) }
            }),
            // "20081022" (compact, 8 consecutive digits)
            ("(\\d{4})(\\d{2})(\\d{2})", { y, m, d in
                let cal = Calendar.current
                var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 0
                return cal.date(from: c).map { ($0, cal.date(byAdding: .day, value: 1, to: $0)!) }
            }),
            // "10/22/2008" (MM/DD/YYYY)
            ("(\\d{1,2})/(\\d{1,2})/(\\d{4})", { m, d, y in
                let cal = Calendar.current
                var c = DateComponents(); c.month = m; c.day = d; c.year = y; c.hour = 0
                return cal.date(from: c).map { ($0, cal.date(byAdding: .day, value: 1, to: $0)!) }
            }),
        ]

        for (pattern, makeDates) in patterns {
            guard dateFrom == nil, let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                let nsText = text as NSString
                let groupCount = match.numberOfRanges
                let groups = (0..<groupCount).map { nsText.substring(with: match.range(at: $0)) }
                guard groups.count >= 4,
                      let y = Int(groups[1]), let m = Int(groups[2]), let d = Int(groups[3]),
                      let (from, to) = makeDates(y, m, d) else { continue }
                dateFrom = from; dateTo = to
                // Replace the full match (group 0) including word boundaries
                text = nsText.replacingCharacters(in: match.range(at: 0), with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        var filter = SearchFilter()
        filter.dateFrom = dateFrom
        filter.dateTo = dateTo

        return (filter, text)
    }
    
    func applyAIFilter() {
        publicVar.isFilenameFilterOn = false
        publicVar.isColorFilterOn = false
        let isFiltering = publicVar.isAIFilterOn && !publicVar.aiFilterPaths.isEmpty
        dirURLCache.removeAll()

        if isFiltering {
            fileDB.lock()
            guard let dirModel = fileDB.db[SortKeyDir(fileDB.curFolder)] else {
                fileDB.unlock()
                return
            }
            // 从当前目录已有的文件中取一个 originalSize 作为虚拟条目基准尺寸
            var refSize = DEFAULT_SIZE
            for (_, file) in dirModel.files {
                if let size = file.originalSize, size.width > 0, size.height > 0 {
                    refSize = size
                    break
                }
            }

            let aiSet = Set(publicVar.aiFilterPaths)
            var filtered = [(SortKeyFile, FileModel)]()
            var seenPaths = Set<String>()
            for (key, file) in dirModel.files {
                if aiSet.contains(file.path) {
                    filtered.append((key, file))
                    seenPaths.insert(file.path)
                }
            }
            let sortType = publicVar.profile.sortType
            let isSortFolderFirst = publicVar.profile.isSortFolderFirst
            let isSortUseFullPath = publicVar.profile.isSortUseFullPath
            for path in publicVar.aiFilterPaths {
                guard !seenPaths.contains(path) else { continue }
                let sortKey = SortKeyFile(path, createDate: Date(), modDate: Date(), addDate: Date(), size: 0, isDir: false, isInSameDir: false, sortType: sortType, isSortFolderFirst: isSortFolderFirst, isSortUseFullPath: isSortUseFullPath, randomSeed: 0)
                let fileModel = FileModel(path: path, ver: fileDB.ver, isDir: false)
                fileModel.originalSize = refSize
                fileModel.canBeCalcued = true
                let url = URL(string: path)
                fileModel.ext = url?.pathExtension.lowercased() ?? ""
                fileModel.type = globalVar.HandledImageExtensions.contains(fileModel.ext) ? .image : .other
                filtered.append((sortKey, fileModel))
            }
            filtered.sort { $0.0 < $1.0 }
            for (_, file) in filtered {
                if file.originalSize == nil || file.originalSize!.width == 0 {
                    file.originalSize = refSize
                }
                file.canBeCalcued = true
            }
            log("AI apply: totalFiles=\(dirModel.files.count) matchedInDir=\(filtered.count - (publicVar.aiFilterPaths.count - seenPaths.count)) virtualAdded=\(publicVar.aiFilterPaths.count - seenPaths.count) refSize=\(refSize)")
            dirModel.files = Map<SortKeyFile, FileModel>(sortedElements: filtered)
            dirModel.aiOrderedPaths = publicVar.aiFilterPaths
            dirModel.isFiltered = true

            fileDB.ver += 1
            dirModel.ver = fileDB.ver
            var id = 0; var idInImage = 0; var idInImageAndVideo = 0
            var imageCount = 0; var videoCount = 0
            for (_, file) in dirModel.files {
                file.ver = fileDB.ver
                if !file.isDir {
                    let ext = file.ext
                    if publicVar.HandledImageAndRawExtensions.contains(ext) {
                        file.idInImage = idInImage; idInImage += 1
                        imageCount += 1
                    }
                    if publicVar.HandledFileExtensions.contains(ext) {
                        file.id = id; id += 1
                    }
                    if publicVar.HandledImageAndRawExtensions.contains(ext) || publicVar.HandledVideoExtensions.contains(ext) {
                        file.idInImageAndVideo = idInImageAndVideo; idInImageAndVideo += 1
                    }
                    if publicVar.HandledVideoExtensions.contains(ext) {
                        videoCount += 1
                    }
                }
            }
            dirModel.imageCount = imageCount
            dirModel.videoCount = videoCount
            dirModel.fileCount = id
            dirModel.layoutCalcPos = 0
            fileDB.unlock()

            readInfoTaskPoolLock.lock()
            readInfoTaskPool.removeAll()
            readInfoTaskPoolLock.unlock()
            let curFolder = fileDB.curFolder
            recalcLayout(curFolder)
            refreshCollectionView(needLoadThumbPriority: true)
        } else {
            fileDB.lock()
            let curFolder = fileDB.curFolder
            fileDB.unlock()
            if let folderURL = URL(string: curFolder) {
                DirMetadataCache.shared.removeCache(for: folderURL)
            }
            refreshCollectionView(needLoadThumbPriority: true)
        }
    }
    
    func toggleSearchOverlay() {
        if publicVar.isInLargeView {return}
        if searchOverlay == nil {
            showSearchOverlay()
        }else{
            closeSearchOverlay()
        }
    }
    
    func getFileNameForSearch(path: String) -> String? {
        if search_isUseFullPath && publicVar.isRecursiveMode {
            return path.removingPercentEncoding?.replacingOccurrences(of: "file://", with: "")
        } else {
            if path.hasSuffix("/") {
                return path.dropLast().components(separatedBy: "/").last?.removingPercentEncoding
            }
            return path.components(separatedBy: "/").last?.removingPercentEncoding
        }
    }

    func performSearch(searchText: String, isEnterKey: Bool, isReverse: Bool = false, forceUseRegex: Bool = false, firstMatch: Bool = false) -> Bool {
        // 如果搜索文本为空，不执行搜索
        // If search text is empty, don't perform search
        if searchText.isEmpty {
            return true
        }
        
        // 获取当前选中的索引
        // Get currently selected index
        let currentSelectedIndex = collectionView.selectionIndexPaths.min()?.item ?? -1
        
        fileDB.lock()
        let files = fileDB.db[SortKeyDir(fileDB.curFolder)]?.files ?? [:]
        
        // 检查当前选中项是否符合搜索条件
        // Check if currently selected item matches search condition
        if !firstMatch,
           let currentIndex = collectionView.selectionIndexPaths.min()?.item,
           let currentFileName = getFileNameForSearch(path: files.element(atOffset: currentIndex).1.path),
           isSearchMatch(fileName: currentFileName, searchText: searchText, forceUseRegex: forceUseRegex) {
            if isEnterKey {
                // 查找下一个或上一个匹配项
                // Find next or previous match
                var foundIndex: Int?
                if isReverse {
                    for (index, file) in files.enumerated().reversed() {
                        if let fileName = getFileNameForSearch(path: file.1.path) {
                            if isSearchMatch(fileName: fileName, searchText: searchText, forceUseRegex: forceUseRegex) && index < currentSelectedIndex {
                                foundIndex = index
                                break
                            }
                        }
                    }
                    
                    // 如果到头了，则跳转到末尾，直到当前项之后（从而实现循环跳转）
                    // If reached beginning, jump to end until after current item (to achieve circular navigation)
                    if foundIndex == nil {
                        for (index, file) in files.enumerated().reversed() {
                            if let fileName = getFileNameForSearch(path: file.1.path) {
                                if isSearchMatch(fileName: fileName, searchText: searchText, forceUseRegex: forceUseRegex) && index >= currentSelectedIndex {
                                    foundIndex = index
                                    break
                                }
                            }
                        }
                    }
                } else {
                    for (index, file) in files.enumerated() {
                        if let fileName = getFileNameForSearch(path: file.1.path) {
                            if isSearchMatch(fileName: fileName, searchText: searchText, forceUseRegex: forceUseRegex) && index > currentSelectedIndex {
                                foundIndex = index
                                break
                            }
                        }
                    }
                    
                    // 如果到底了，则跳转到开头，直到当前项之前（从而实现循环跳转）
                    // If reached end, jump to beginning until before current item (to achieve circular navigation)
                    if foundIndex == nil {
                        for (index, file) in files.enumerated() {
                            if let fileName = getFileNameForSearch(path: file.1.path) {
                                if isSearchMatch(fileName: fileName, searchText: searchText, forceUseRegex: forceUseRegex) && index <= currentSelectedIndex {
                                    foundIndex = index
                                    break
                                }
                            }
                        }
                    }
                }
                
                fileDB.unlock()
                
                // 如果找到匹配项，选中并滚动到该项
                // If match found, select and scroll to that item
                if let index = foundIndex {
                    if index >= 0 && index < collectionView.numberOfItems(inSection: 0) {
                        let indexPath = IndexPath(item: index, section: 0)
                        collectionView.deselectAll(nil)
                        collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestHorizontalEdge)
                        collectionView.reloadData()
                        collectionView.delegate?.collectionView?(collectionView, shouldSelectItemsAt: [indexPath])
                        collectionView.selectItems(at: [indexPath], scrollPosition: [])
                        collectionView.delegate?.collectionView?(collectionView, didSelectItemsAt: [indexPath])
                        setLoadThumbPriority(ifNeedVisable: true)
                        return true
                    }
                }
                
                return true
            } else {
                fileDB.unlock()
                return true
            }
        } else {
            // 当前选中项不符合搜索条件，取消所有选择
            // Currently selected item doesn't match search condition, deselect all
            collectionView.deselectAll(nil)
        }
        
        // 从头开始查找第一个匹配项
        // Search from beginning for first match
        var foundIndex: Int?
        for (index, file) in files.enumerated() {
            if let fileName = getFileNameForSearch(path: file.1.path) {
                if isSearchMatch(fileName: fileName, searchText: searchText, forceUseRegex: forceUseRegex) {
                    foundIndex = index
                    break
                }
            }
        }
        fileDB.unlock()
        
        // 如果找到匹配项，选中并滚动到该项
        // If match found, select and scroll to that item
        if let index = foundIndex {
            if index >= 0 && index < collectionView.numberOfItems(inSection: 0) {
                let indexPath = IndexPath(item: index, section: 0)
                collectionView.deselectAll(nil)
                collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestHorizontalEdge)
                collectionView.reloadData()
                collectionView.delegate?.collectionView?(collectionView, shouldSelectItemsAt: [indexPath])
                collectionView.selectItems(at: [indexPath], scrollPosition: [])
                collectionView.delegate?.collectionView?(collectionView, didSelectItemsAt: [indexPath])
                setLoadThumbPriority(ifNeedVisable: true)
                return true
            }
        }
        
        return false
    }
    
    func isSearchMatch(fileName _fileName: String, searchText _searchText: String, forceUseRegex: Bool) -> Bool {
        if forceUseRegex {
            do {
                let fileName = _fileName
                let searchText = _searchText
                let regex = try NSRegularExpression(pattern: searchText, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: fileName.utf16.count)
                return regex.firstMatch(in: fileName, options: [], range: range) != nil
            } catch {
                return false
            }
        } else {
            let fileName = _fileName.localizedLowercase
            let searchText = _searchText.localizedLowercase
            var result = fileName.contains(searchText)
            if globalVar.usePinyinSearch {
                result = result || convertToPinyin(fileName, toPinyinFull: true).contains(searchText)
            }
            if globalVar.usePinyinInitialSearch {
                result = result || convertToPinyin(fileName, toPinyinFull: false).contains(searchText)
            }
            return result
        }
    }

    @objc private func searchFieldDidChange(_ sender: NSSearchField) {
        let searchText = sender.stringValue
        searchFilterButton?.isEnabled = !searchText.isEmpty
        
        if search_isAIMode {
            search_searchText = searchText
            return
        }
        
        if search_isGeoMode {
            search_searchText = searchText
            return
        }
        
        // 标记并移除 ASCII 值为 3 的字符 (Shift+小键盘Enter)
        // Mark and remove character with ASCII value 3 (Shift+numpad Enter)
        var containsSpecialCharacter = false
        let filteredText = searchText.filter { character in
            if character.asciiValue == 3 {
                containsSpecialCharacter = true
                // 过滤掉该字符
                // Filter out this character
                return false
            }
            return true
        }
        
        // 如果存在特殊字符，则执行向上搜索
        // If special character exists, perform reverse search
        if containsSpecialCharacter {
            sender.stringValue = filteredText
            search_searchText = filteredText
            _ = performSearch(searchText: filteredText, isEnterKey: true, isReverse: true)
        }else{
            search_searchText = filteredText
            _ = performSearch(searchText: filteredText, isEnterKey: false)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if search_isGeoMode {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let searchText = searchField?.stringValue ?? ""
                if !searchText.isEmpty {
                    performGeoSearch(searchText)
                }
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                search_isGeoMode = false
                publicVar.isGeolocationSearchMode = false
                publicVar.isGeoFilterOn = false
                publicVar.geoFilterPaths = []
                searchField?.stringValue = ""
                closeSearchOverlay()
                refreshCollectionView(needLoadThumbPriority: true)
                publicVar.updateToolbar()
                return true
            }
            return false
        }
        if search_isAIMode {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let searchText = searchField?.stringValue ?? ""
                if !searchText.isEmpty {
                    performAISearch(searchText)
                }
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                closeSearchOverlay()
                return true
            }
            return false
        }
        if search_isColorMode {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let searchText = searchField?.stringValue ?? ""
                if !searchText.isEmpty, let (r, g, b) = parseColorCode(searchText) {
                    searchColorPickedColors = [(r, g, b)]
                    searchField?.stringValue = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
                    performColorSearch()
                } else if !searchText.isEmpty {
                    coreAreaView.showInfo(NSLocalizedString("Invalid color code. Use #RRGGBB or R,G,B", comment: "颜色代码格式错误"), timeOut: 2.0)
                }
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if publicVar.isColorFilterOn {
                    publicVar.isColorFilterOn = false
                    publicVar.colorFilterPaths = []
                    closeSearchOverlay()
                    applyColorFilter()
                    publicVar.updateToolbar()
                } else {
                    closeSearchOverlay()
                }
                return true
            }
            return false
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let searchText = searchField?.stringValue ?? ""
            let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
            _ = performSearch(searchText: searchText, isEnterKey: true, isReverse: isShiftPressed)
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            closeSearchOverlay()
            return true
        }
        return false
    }

    @objc private func filterButtonClicked(_ sender: NSButton) {
        applyFilter()
    }
    
    func applyFilter(isReset: Bool = false) {
        if isReset {
            search_filterText = ""
            publicVar.isAIFilterOn = false
            publicVar.aiFilterPaths = []
            search_isAIMode = false
            publicVar.isGeoFilterOn = false
            publicVar.geoFilterPaths = []
            search_isGeoMode = false
            publicVar.isColorFilterOn = false
            publicVar.colorFilterPaths = []
            search_isColorMode = false
        } else {
            search_filterText = searchField?.stringValue ?? ""
            // 文件名筛选时关闭其他模式
            publicVar.isGeoFilterOn = false
            publicVar.geoFilterPaths = []
            search_isGeoMode = false
            publicVar.isColorFilterOn = false
            publicVar.colorFilterPaths = []
            search_isColorMode = false
        }
        search_filterIsUseFullPath = search_isUseFullPath
        publicVar.isFilenameFilterOn = search_filterText == "" ? false : true
        // 清空 DirMetadataCache，强制 treeTraversal 重新扫描，避免使用旧过滤后的 BTree
        // Clear DirMetadataCache to force treeTraversal re-scan, preventing use of stale filtered BTree
        fileDB.lock()
        let curFolder = fileDB.curFolder
        fileDB.unlock()
        dirURLCache.removeAll()
        if let folderURL = URL(string: curFolder) {
            DirMetadataCache.shared.removeCache(for: folderURL)
        }
        refreshCollectionView(needLoadThumbPriority: true)
        if isReset {
            publicVar.updateToolbar()
        }
    }
    
    // 添加新的响应方法
    // Add new response method
    @objc private func fullPathCheckboxChanged(_ sender: NSButton) {
        search_isUseFullPath = (sender.state == .on)
        // 当切换使用完整路径选项时，重新执行搜索
        // When toggling use full path option, re-execute search
        let searchText = searchField?.stringValue ?? ""
        _ = performSearch(searchText: searchText, isEnterKey: false)
    }
    
    func quickSearch(_ character: String) {
        
        let quickSearchAutoHideDuration = 2.5
        
        // 清除之前的计时器
        // Clear previous timer
        quickSearchTimer?.invalidate()
        
        // 添加新字符到搜索文本
        // Add new character to search text
        if character == "backspace" {
            quickSearchText = String(quickSearchText.dropLast())
        }else{
            quickSearchText += character
        }
        
        // 执行搜索
        // Execute search
        if quickSearchText != "" {
            if !performSearch(searchText: "^"+quickSearchText, isEnterKey: false, forceUseRegex: true, firstMatch: true) {
                _ = performSearch(searchText: quickSearchText, isEnterKey: false, forceUseRegex: false, firstMatch: true)
            }
        }
        coreAreaView.showInfo(NSLocalizedString("Quick Search", comment: "快速搜索")+": "+quickSearchText, timeOut: quickSearchAutoHideDuration, duration: 0.1, cannotBeCleard: true)
        
        if !publicVar.isCollectionViewFirstResponder {
            view.window?.makeFirstResponder(collectionView)
        }
        
        // 设置新的计时器,n秒后清空搜索文本
        // Set new timer, clear search text after n seconds
        quickSearchState = true
        quickSearchTimer = Timer.scheduledTimer(withTimeInterval: quickSearchAutoHideDuration, repeats: false) { [weak self] _ in
            self?.quickSearchText = ""
            self?.quickSearchState = false
        }
    }
}
