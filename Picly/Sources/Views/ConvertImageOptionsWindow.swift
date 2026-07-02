//
//  ConvertImageOptionsWindow.swift
//  Picly
//

import Foundation
import Cocoa

class ConvertImageOptionsWindow: NSWindow {

    var selectedFormat: ImageExportFormat = .jpeg
    var quality: Int = 90

    private var formatPopUp: NSPopUpButton!
    private var qualitySlider: NSSlider!
    private var qualityLabel: NSTextField!
    private var qualityContainer: NSStackView!
    private var convertButton: NSButton!

    init() {
        let windowSize = NSSize(width: 400, height: 280)
        let windowRect = NSRect(origin: .zero, size: windowSize)

        super.init(contentRect: windowRect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.title = NSLocalizedString("Convert Image", comment: "转换图片格式")

        setupUI()
    }

    private func setupUI() {
        guard let contentView = self.contentView else { return }

        let backgroundView = NSVisualEffectView(frame: contentView.bounds)
        backgroundView.autoresizingMask = [.width, .height]
        backgroundView.material = .underWindowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        contentView.addSubview(backgroundView)

        let mainStack = NSStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        contentView.addSubview(mainStack)

        let contentWidth: CGFloat = 360

        // Format row
        let formatRow = NSStackView()
        formatRow.orientation = .horizontal
        formatRow.alignment = .centerY
        formatRow.spacing = 12

        let formatLabel = NSTextField(labelWithString: NSLocalizedString("Format:", comment: "格式:"))
        formatLabel.font = NSFont.systemFont(ofSize: 13)
        formatLabel.setContentHuggingPriority(.required, for: .horizontal)

        formatPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        formatPopUp.target = self
        formatPopUp.action = #selector(formatChanged)
        for fmt in ImageExportFormat.allCases {
            formatPopUp.addItem(withTitle: fmt.rawValue)
        }
        formatPopUp.selectItem(at: 0)

        formatRow.addArrangedSubview(formatLabel)
        formatRow.addArrangedSubview(formatPopUp)
        mainStack.addArrangedSubview(formatRow)
        formatRow.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        // Quality container
        qualityContainer = NSStackView()
        qualityContainer.orientation = .vertical
        qualityContainer.alignment = .leading
        qualityContainer.spacing = 6
        qualityContainer.translatesAutoresizingMaskIntoConstraints = false

        let qualityLabelRow = NSStackView()
        qualityLabelRow.orientation = .horizontal
        qualityLabelRow.alignment = .centerY
        qualityLabelRow.spacing = 8

        let qualityTitleLabel = NSTextField(labelWithString: NSLocalizedString("Quality:", comment: "质量:"))
        qualityTitleLabel.font = NSFont.systemFont(ofSize: 13)
        qualityTitleLabel.setContentHuggingPriority(.required, for: .horizontal)

        qualityLabel = NSTextField(labelWithString: "\(quality)")
        qualityLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        qualityLabel.alignment = .right
        qualityLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let qualitySpacer = NSView()
        qualitySpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        qualityLabelRow.addArrangedSubview(qualityTitleLabel)
        qualityLabelRow.addArrangedSubview(qualitySpacer)
        qualityLabelRow.addArrangedSubview(qualityLabel)

        qualitySlider = NSSlider(value: Double(quality), minValue: 1, maxValue: 100, target: self, action: #selector(qualityChanged))
        qualitySlider.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        qualityContainer.addArrangedSubview(qualityLabelRow)
        qualityContainer.addArrangedSubview(qualitySlider)
        qualityLabelRow.widthAnchor.constraint(equalTo: qualityContainer.widthAnchor).isActive = true
        mainStack.addArrangedSubview(qualityContainer)
        qualityContainer.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        mainStack.addArrangedSubview(spacer)

        // Buttons
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 12
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: "取消"), target: self, action: #selector(cancelPressed))
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)

        convertButton = NSButton(title: NSLocalizedString("Convert", comment: "转换"), target: self, action: #selector(convertPressed))
        convertButton.keyEquivalent = "\r"
        convertButton.bezelStyle = .push
        convertButton.setContentHuggingPriority(.required, for: .horizontal)

        let buttonSpacer = NSView()
        buttonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        buttonRow.addArrangedSubview(buttonSpacer)
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(convertButton)

        mainStack.addArrangedSubview(buttonRow)
        buttonRow.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        // Layout
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        updateQualityVisibility()
    }

    @objc private func formatChanged() {
        selectedFormat = ImageExportFormat.allCases[formatPopUp.indexOfSelectedItem]
        updateQualityVisibility()
    }

    @objc private func qualityChanged() {
        quality = Int(round(qualitySlider.doubleValue))
        qualityLabel.stringValue = "\(quality)"
    }

    private func updateQualityVisibility() {
        let showQuality = selectedFormat.supportsQuality
        qualityContainer.isHidden = !showQuality
        if showQuality {
            qualityChanged()
        }
    }

    @objc private func convertPressed() {
        self.sheetParent?.endSheet(self, returnCode: .OK)
    }

    @objc private func cancelPressed() {
        self.sheetParent?.endSheet(self, returnCode: .cancel)
    }
}


func showConvertImagePanel(on parentWindow: NSWindow, completion: @escaping (ImageExportFormat, Int) -> Void) {
    let window = ConvertImageOptionsWindow()
    let storeIsKeyEventEnabled = getMainViewController()!.publicVar.isKeyEventEnabled
    getMainViewController()!.publicVar.isKeyEventEnabled = false

    parentWindow.beginSheet(window) { response in
        getMainViewController()!.publicVar.isKeyEventEnabled = storeIsKeyEventEnabled
        if response == .OK {
            completion(window.selectedFormat, window.quality)
        }
    }
}
