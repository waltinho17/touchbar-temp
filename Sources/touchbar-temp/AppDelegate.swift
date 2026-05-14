import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let touchBarController = TouchBarController()
    private let temperatureReader = TemperatureReader()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        touchBarController.start(reader: temperatureReader)
        scheduleMenuBarUpdate()
    }

    private func scheduleMenuBarUpdate() {
        updateMenuBarTemp()
        let t = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in self?.updateMenuBarTemp() }
        RunLoop.main.add(t, forMode: .common)
    }

    private func updateMenuBarTemp() {
        let temp = temperatureReader.currentTemperature()
        guard let button = statusItem.button else { return }
        if temp > 0 {
            button.image = nil
            button.title = String(format: "%.0f°C", temp)
        } else {
            button.image = NSImage(systemSymbolName: "thermometer.medium",
                                   accessibilityDescription: "TouchBar Temp")
            button.title = ""
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "thermometer.medium",
                                   accessibilityDescription: "TouchBar Temp")
        }

        let menu = NSMenu()

        let header = NSMenuItem(title: "TouchBar Temp", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let colorItem = NSMenuItem(title: "Temperatura colorida",
                                   action: #selector(toggleColorMode),
                                   keyEquivalent: "c")
        colorItem.target = self
        colorItem.state = touchBarController.useColors ? .on : .off
        menu.addItem(colorItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sair",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleColorMode() {
        touchBarController.useColors.toggle()
        guard let menu = statusItem.menu else { return }
        if let item = menu.items.first(where: { $0.action == #selector(toggleColorMode) }) {
            item.state = touchBarController.useColors ? .on : .off
        }
    }
}
