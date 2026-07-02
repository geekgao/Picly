//
//  ActionsSettingsViewController.swift
//  Picly
//

import Settings
import Cocoa

final class ActionsSettingsViewController: NSViewController, SettingsPane {
    let paneIdentifier = Settings.PaneIdentifier.actions
    let paneTitle = NSLocalizedString("Actions", comment: "操作（设置里的面板）")
    let toolbarItemIcon = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "")!

    override var nibName: NSNib.Name? { "ActionsSettingsViewController" }
    
    @IBOutlet weak var radioEnterKeyRename: NSButton!
    @IBOutlet weak var radioEnterKeyOpen: NSButton!
    @IBOutlet weak var radioEscKeyGoBack: NSButton!
    @IBOutlet weak var radioEscKeyCloseWindow: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        radioEnterKeyOpen.state = globalVar.isEnterKeyToOpen ? .on : .off
        radioEnterKeyRename.state = globalVar.isEnterKeyToOpen ? .off : .on

        radioEscKeyGoBack.state = globalVar.isEscKeyToGoBack ? .on : .off
        radioEscKeyCloseWindow.state = globalVar.isEscKeyToGoBack ? .off : .on

        // MARK: RTL support
        if let container = radioEnterKeyRename.superview {
            convertToLeadingLayoutForRTL(container)
        }
        if let container = radioEscKeyGoBack.superview {
            convertToLeadingLayoutForRTL(container)
        }
    }

    @IBAction func enterKeyFuncToggled(_ sender: NSButton) {
        let tag = sender.tag
        if tag == 0 {
            globalVar.isEnterKeyToOpen = false
        } else if tag == 1 {
            globalVar.isEnterKeyToOpen = true
        }
        UserDefaults.standard.set(globalVar.isEnterKeyToOpen, forKey: "isEnterKeyToOpen")
    }
    
    @IBAction func escKeyFuncToggled(_ sender: NSButton) {
        let tag = sender.tag
        if tag == 0 {
            globalVar.isEscKeyToGoBack = true
        } else if tag == 1 {
            globalVar.isEscKeyToGoBack = false
        }
        UserDefaults.standard.set(globalVar.isEscKeyToGoBack, forKey: "isEscKeyToGoBack")
    }
}
