import Cocoa

class PersonGalleryViewController: NSViewController {
    private let person: PersonInfo
    private var photoPaths: [String] = []
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var backButton: NSButton!
    private let faceService = FaceService.shared

    init(person: PersonInfo) {
        self.person = person
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = person.name ?? NSLocalizedString("Unknown", comment: "未知")
        setupUI()
        Task { await loadPhotos() }
    }

    private func setupUI() {
        let headerHeight: CGFloat = 50
        let headerView = NSView(frame: NSRect(x: 0, y: view.bounds.height - headerHeight, width: view.bounds.width, height: headerHeight))
        headerView.autoresizingMask = [.width, .minYMargin]

        let titleLabel = NSTextField(labelWithString: title ?? "")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: 10, width: 300, height: 30)
        headerView.addSubview(titleLabel)

        let countLabel = NSTextField(labelWithString: String(format: NSLocalizedString("%d photos", comment: "照片数"), person.photoCount))
        countLabel.font = NSFont.systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabelColor
        countLabel.frame = NSRect(x: 330, y: 15, width: 100, height: 20)
        headerView.addSubview(countLabel)

        view.addSubview(headerView)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 200, height: 150)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(PhotoCollectionViewItem.self, forItemWithIdentifier: .photoItem)

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - headerHeight))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)
    }

    private func loadPhotos() async {
        do {
            photoPaths = try await faceService.getPersonPhotos(id: person.id)
            collectionView.reloadData()
        } catch {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Failed to load photos", comment: "加载照片失败")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

extension PersonGalleryViewController: NSCollectionViewDataSource, NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        photoPaths.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: .photoItem, for: indexPath) as! PhotoCollectionViewItem
        let path = photoPaths[indexPath.item]
        item.configure(with: path)
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let path = photoPaths[indexPath.item]
        if let url = URL(string: path) {
            NSWorkspace.shared.open(url)
        }
    }
}

class PhotoCollectionViewItem: NSCollectionViewItem {
    private let thumbView = NSImageView()
    private var loadTask: Task<Void, Never>?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 150))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        thumbView.frame = view.bounds
        thumbView.autoresizingMask = [.width, .height]
        thumbView.imageScaling = .scaleAxesIndependently
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = 4
        thumbView.layer?.masksToBounds = true
        thumbView.contentTintColor = .secondaryLabelColor
        view.addSubview(thumbView)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        thumbView.image = nil
    }

    func configure(with path: String) {
        guard let url = URL(string: path) else {
            thumbView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            return
        }
        thumbView.image = NSImage(contentsOf: url)
    }
}

extension NSUserInterfaceItemIdentifier {
    static let photoItem = NSUserInterfaceItemIdentifier("PhotoItem")
}
