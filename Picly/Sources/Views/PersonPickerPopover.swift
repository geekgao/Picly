import Cocoa
import ImageIO

class PersonPickerPopover: NSViewController {
    private let persons: [PersonInfo]
    private let onSelect: (String) -> Void
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!

    init(persons: [PersonInfo], onSelect: @escaping (String) -> Void) {
        self.persons = persons
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let height = min(CGFloat(persons.count * 56 + 30), 400)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: height))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true

        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Merge into:", comment: "合并到："))
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 12, y: view.bounds.height - 28, width: 276, height: 20)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(titleLabel)

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 36))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        tableView = NSTableView(frame: scrollView.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = 56
        tableView.target = self
        tableView.doubleAction = #selector(itemClicked)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.width = 290
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        view.addSubview(scrollView)
    }

    @objc private func itemClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < persons.count else { return }
        dismiss(nil)
        onSelect(persons[row].id)
    }

    func show(relativeTo rect: NSRect, of parentView: NSView, preferredEdge: NSRectEdge) {
        let popover = NSPopover()
        popover.contentViewController = self
        popover.behavior = .transient
        popover.show(relativeTo: rect, of: parentView, preferredEdge: preferredEdge)
    }
}

extension PersonPickerPopover: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        persons.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("personPickerCell")
        if let existing = tableView.makeView(withIdentifier: id, owner: nil) as? PersonPickerCell {
            existing.configure(with: persons[row])
            return existing
        }
        let cell = PersonPickerCell(frame: NSRect(x: 0, y: 0, width: 290, height: 56))
        cell.identifier = id
        cell.configure(with: persons[row])
        return cell
    }
}

class PersonPickerCell: NSView {
    private let thumbView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private var loadTask: Task<Void, Never>?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        thumbView.frame = NSRect(x: 8, y: 8, width: 40, height: 40)
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = 20
        thumbView.layer?.masksToBounds = true
        thumbView.imageScaling = .scaleAxesIndependently
        thumbView.image = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil)
        thumbView.contentTintColor = .controlAccentColor
        addSubview(thumbView)

        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.frame = NSRect(x: 56, y: 30, width: 220, height: 18)
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)

        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.frame = NSRect(x: 56, y: 8, width: 220, height: 14)
        addSubview(countLabel)
    }

    func configure(with person: PersonInfo) {
        nameLabel.stringValue = person.name ?? NSLocalizedString("Unknown", comment: "未知")
        countLabel.stringValue = String(format: NSLocalizedString("%d photos · %d faces", comment: ""), person.photoCount, person.faceCount)
        thumbView.image = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil)
        thumbView.contentTintColor = .controlAccentColor

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
                )
                if let cropped = cgImage.cropping(to: cropRect) {
                    image = NSImage(cgImage: cropped, size: NSSize(width: 40, height: 40))
                } else {
                    image = NSImage(cgImage: cgImage, size: NSSize(width: 40, height: 40))
                }
            } else {
                image = NSImage(cgImage: cgImage, size: NSSize(width: 40, height: 40))
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.thumbView.image = image
                self.thumbView.contentTintColor = nil
            }
        }
    }
}
