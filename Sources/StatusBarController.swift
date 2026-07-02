import Cocoa

class StatusBarController {
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var serversMenu: NSMenu
    
    private var currentProfileIndex: Int = -1
    private var isConnected: Bool = false
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "V2Box"
        }
        
        menu = NSMenu()
        
        let connectItem = NSMenuItem(title: "Connect", action: #selector(toggleConnection(_:)), keyEquivalent: "")
        connectItem.target = self
        menu.addItem(connectItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let serversItem = NSMenuItem(title: "Servers", action: nil, keyEquivalent: "")
        serversMenu = NSMenu()
        serversItem.submenu = serversMenu
        menu.addItem(serversItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let pasteItem = NSMenuItem(title: "Import from Clipboard", action: #selector(importFromClipboard), keyEquivalent: "v")
        pasteItem.target = self
        menu.addItem(pasteItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        updateServersMenu()
    }
    
    @objc func toggleConnection(_ sender: NSMenuItem) {
        if isConnected {
            VPNManager.shared.stopVPN()
            sender.title = "Connect"
            statusItem.button?.title = "V2Box"
            isConnected = false
        } else {
            if currentProfileIndex >= 0 && currentProfileIndex < ProfileManager.shared.profiles.count {
                let profile = ProfileManager.shared.profiles[currentProfileIndex]
                VPNManager.shared.startVPN(profile: profile)
                sender.title = "Disconnect"
                statusItem.button?.title = "V2Box (On)"
                isConnected = true
            } else {
                let alert = NSAlert()
                alert.messageText = "No Server Selected"
                alert.informativeText = "Please select a server before connecting."
                alert.runModal()
            }
        }
    }
    
    @objc func importFromClipboard() {
        guard let items = NSPasteboard.general.pasteboardItems else { return }
        for item in items {
            if let string = item.string(forType: .string) {
                if let profile = LinkParser.parse(link: string) {
                    ProfileManager.shared.addProfile(profile)
                    updateServersMenu()
                    print("Added profile: \(profile.name)")
                }
            }
        }
    }
    
    private func updateServersMenu() {
        serversMenu.removeAllItems()
        let profiles = ProfileManager.shared.profiles
        
        for (index, profile) in profiles.enumerated() {
            let item = NSMenuItem(title: profile.name, action: #selector(selectServer(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            if index == currentProfileIndex {
                item.state = .on
            }
            serversMenu.addItem(item)
        }
        
        if profiles.isEmpty {
            let emptyItem = NSMenuItem(title: "No Servers", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            serversMenu.addItem(emptyItem)
        } else {
            // Select the first one by default if none selected
            if currentProfileIndex == -1 {
                currentProfileIndex = 0
                serversMenu.items.first?.state = .on
            }
        }
    }
    
    @objc func selectServer(_ sender: NSMenuItem) {
        currentProfileIndex = sender.tag
        updateServersMenu()
        
        if isConnected {
            // Restart connection with new server
            VPNManager.shared.stopVPN()
            let profile = ProfileManager.shared.profiles[currentProfileIndex]
            VPNManager.shared.startVPN(profile: profile)
        }
    }
    
    @objc func quitApp() {
        if isConnected {
            VPNManager.shared.stopVPN()
        }
        NSApplication.shared.terminate(self)
    }
}
