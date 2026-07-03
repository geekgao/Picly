import Cocoa
import ImageIO

class PersonBrowserViewController: NSViewController {
    var onClose: (() -> Void)?
    var onPersonSelected: ((String) -> Void)?
    var onIndexFolder: (() -> Void)?
    private var persons: [PersonInfo] = []
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!

    private var closeButton: NSButton!
    private var titleLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var spinner: NSProgressIndicator!
    private var selectedIndex: Int?

    override func loadView() {
        let v = DynamicBackgroundView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        v.wantsLayer = true
        v.layer?.cornerRadius = 10
        v.layer?.masksToBounds = true
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        load()
    }

    private func setupUI() {

        let titleBar = NSView(frame: NSRect(x: 0, y: view.bounds.height - 40, width: view.bounds.width, height: 40))
        titleBar.autoresizingMask = [.width, .minYMargin]

        titleLabel = NSTextField(labelWithString: NSLocalizedString("People", comment: "人物"))
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 16, y: 10, width: 200, height: 22)
        titleBar.addSubview(titleLabel)

        closeButton = NSButton(frame: NSRect(x: view.bounds.width - 36, y: 8, width: 24, height: 24))
        closeButton.autoresizingMask = [.minXMargin, .minYMargin]
        closeButton.bezelStyle = .smallSquare
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closePersonBrowser)
        titleBar.addSubview(closeButton)

        let indexButton = NSButton(frame: NSRect(x: view.bounds.width - 64, y: 8, width: 24, height: 24))
        indexButton.autoresizingMask = [.minXMargin, .minYMargin]
        indexButton.bezelStyle = .smallSquare
        indexButton.isBordered = false
        indexButton.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Reindex")
        indexButton.contentTintColor = .secondaryLabelColor
        indexButton.target = self
        indexButton.action = #selector(indexFolderAction)
        indexButton.toolTip = NSLocalizedString("Index faces in current folder", comment: "索引当前文件夹人脸")
        titleBar.addSubview(indexButton)

        view.addSubview(titleBar)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 140, height: 180)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(PersonCollectionViewItem.self, forItemWithIdentifier: .personItem)

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 40))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)

        spinner = NSProgressIndicator(frame: NSRect(x: view.bounds.midX - 12, y: view.bounds.midY + 4, width: 24, height: 24))
        spinner.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        spinner.style = .spinning
        spinner.controlSize = .small
        view.addSubview(spinner)

        statusLabel = NSTextField(labelWithString: NSLocalizedString("Loading people...", comment: "加载人物..."))
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 0, y: view.bounds.midY - 20, width: view.bounds.width, height: 20)
        statusLabel.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        view.addSubview(statusLabel)

        collectionView.isHidden = true
    }

    @objc private func closePersonBrowser() {
        onClose?()
    }

    @objc private func indexFolderAction() {
        log("Person browser: indexFolder requested")
        onIndexFolder?()
    }

    private func load() {
        spinner.startAnimation(nil)
        spinner.isHidden = false
        statusLabel.stringValue = NSLocalizedString("Loading people...", comment: "加载人物...")
        statusLabel.isHidden = false
        log("Person browser: starting load")

        Task { @MainActor in
            do {
                let url = URL(string: "http://127.0.0.1:8972/api/v1/persons")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 15

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw ImageAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1,
                                                  body: String(data: data, encoding: .utf8) ?? "")
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let resp = try decoder.decode(PersonsListResponse.self, from: data)
                log("Person browser: decoded \(resp.persons.count) persons")

                self.persons = resp.persons
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.statusLabel.isHidden = true

                if self.persons.isEmpty {
                    self.statusLabel.stringValue = NSLocalizedString("No people found", comment: "未找到人物")
                    self.statusLabel.isHidden = false
                }

                self.collectionView.isHidden = false
                self.collectionView.reloadData()
                self.collectionView.needsDisplay = true
                self.scrollView.needsDisplay = true
                self.view.needsLayout = true
                self.view.layoutSubtreeIfNeeded()
                log("Person browser: loaded successfully")
            } catch {
                self.spinner.stopAnimation(nil)
                self.statusLabel.stringValue = NSLocalizedString("Failed to load", comment: "加载失败")
                self.statusLabel.isHidden = false
                log("Person browser load failed: \(error.localizedDescription)")
            }
        }
    }

    func refresh() {
        load()
    }

    // MARK: - Rename

    func renamePerson(_ person: PersonInfo) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Rename Person", comment: "重命名人物")
        alert.informativeText = NSLocalizedString("Enter a name for this person:", comment: "为此人物输入名称：")
        alert.addButton(withTitle: NSLocalizedString("Save", comment: "保存"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "取消"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.stringValue = person.name ?? ""
        textField.placeholderString = NSLocalizedString("e.g. Mom, John", comment: "如：妈妈、小明")
        alert.accessoryView = textField

        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                let newName = textField.stringValue.trimmingCharacters(in: .whitespaces)
                let finalName: String? = newName.isEmpty ? nil : newName
                Task {
                    do {
                        try await FaceService.shared.updatePersonName(id: person.id, name: finalName)
                        await MainActor.run { self.refresh() }
                    } catch {
                        log("Rename failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Merge

    func showMergePicker(for sourcePersonId: String) {
        let otherPersons = persons.filter { $0.id != sourcePersonId }
        guard !otherPersons.isEmpty else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("No other persons", comment: "没有其他人物")
            alert.informativeText = NSLocalizedString("There are no other persons to merge into.", comment: "没有其他人物可合并。")
            alert.runModal()
            return
        }

        guard let window = view.window else { return }
        let picker = PersonPickerPopover(persons: otherPersons) { [weak self] targetId in
            Task {
                do {
                    try await FaceService.shared.mergePersons(fromId: sourcePersonId, intoId: targetId)
                    await MainActor.run { self?.refresh() }
                } catch {
                    log("Merge failed: \(error.localizedDescription)")
                }
            }
        }
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxX)
    }
}

extension PersonBrowserViewController: NSCollectionViewDataSource, NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        persons.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: .personItem, for: indexPath) as! PersonCollectionViewItem
        let person = persons[indexPath.item]
        item.configure(with: person)
        item.onRename = { [weak self] in self?.renamePerson(person) }
        item.onMerge = { [weak self] in self?.showMergePicker(for: person.id) }
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let person = persons[indexPath.item]
        log("Person browser: clicked person \(person.id)")
        onClose?()
        onPersonSelected?(person.id)
    }
}

class PersonCollectionViewItem: NSCollectionViewItem {
    private let faceImageView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private var loadTask: Task<Void, Never>?
    var onRename: (() -> Void)?
    var onMerge: (() -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 140, height: 180))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        faceImageView.frame = NSRect(x: 20, y: 50, width: 100, height: 100)
        faceImageView.wantsLayer = true
        faceImageView.layer?.cornerRadius = 50
        faceImageView.layer?.masksToBounds = true
        faceImageView.imageScaling = .scaleAxesIndependently
        view.addSubview(faceImageView)

        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.frame = NSRect(x: 0, y: 28, width: 140, height: 18)
        nameLabel.lineBreakMode = .byTruncatingTail
        view.addSubview(nameLabel)

        countLabel.font = NSFont.systemFont(ofSize: 10)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .center
        countLabel.frame = NSRect(x: 0, y: 8, width: 140, height: 14)
        view.addSubview(countLabel)

        // Double-click to rename
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(doubleClickAction))
        doubleClick.numberOfClicksRequired = 2
        view.addGestureRecognizer(doubleClick)
    }

    @objc private func doubleClickAction() {
        onRename?()
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("Rename...", comment: "重命名..."), action: #selector(renameAction), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Merge into...", comment: "合并到..."), action: #selector(mergeAction), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func renameAction() { onRename?() }
    @objc private func mergeAction() { onMerge?() }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        faceImageView.image = nil
    }

    func configure(with person: PersonInfo) {
        nameLabel.stringValue = person.name ?? NSLocalizedString("Unknown", comment: "未知")
        countLabel.stringValue = String(format: NSLocalizedString("%d photos", comment: "照片数"), person.photoCount)
        faceImageView.image = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil)
        faceImageView.contentTintColor = .controlAccentColor

        guard let photoPath = person.coverPhotoPath else { return }

        loadTask = Task {
            let url = URL(fileURLWithPath: photoPath)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return }

            let image: NSImage
            if let bx = person.coverBboxX, let by = person.coverBboxY,
               let bw = person.coverBboxW, let bh = person.coverBboxH,
               bw > 0, bh > 0 {
                let centerX = CGFloat(bx + bw / 2)
                let centerY = CGFloat(by + bh / 2)
                let cropSize = max(CGFloat(bw), CGFloat(bh)) * 1.8
                let cropRect = CGRect(
                    x: max(0, centerX - cropSize / 2),
                    y: max(0, centerY - cropSize / 2),
                    width: min(CGFloat(cgImage.width) - max(0, centerX - cropSize / 2), cropSize),
                    height: min(CGFloat(cgImage.height) - max(0, centerY - cropSize / 2), cropSize)
                ) as CGRect

                if let cropped = cgImage.cropping(to: cropRect) {
                    image = NSImage(cgImage: cropped, size: NSSize(width: 100, height: 100))
                } else {
                    image = NSImage(cgImage: cgImage, size: NSSize(width: 100, height: 100))
                }
            } else {
                image = NSImage(cgImage: cgImage, size: NSSize(width: 100, height: 100))
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.faceImageView.image = image
                self.faceImageView.contentTintColor = nil
            }
        }
    }
}

extension NSUserInterfaceItemIdentifier {
    static let personItem = NSUserInterfaceItemIdentifier("PersonItem")
}
