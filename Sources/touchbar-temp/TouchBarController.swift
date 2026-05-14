import AppKit
import ObjectiveC

final class TouchBarController: NSObject {

    private let itemID = NSTouchBarItem.Identifier("com.touchbar-temp.temperature")
    private weak var tempLabel: NSTextField?
    private var timer: Timer?
    private var reader: TemperatureReader?

    var useColors: Bool {
        get { UserDefaults.standard.object(forKey: "useColors") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "useColors") }
    }

    // MARK: - Lifecycle

    func start(reader: TemperatureReader) {
        self.reader = reader

        let item = makeItem()
        addToSystemTray(item)
        scheduleTimer()
    }

    // MARK: - Touch Bar Item

    private func makeItem() -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: itemID)

        let label = NSTextField(labelWithString: "–°")
        label.font = heavyRoundedFont(size: 17)
        label.textColor = .white
        label.alignment = .center
        label.sizeToFit()

        tempLabel = label
        item.view = label
        return item
    }

    // Adds a single item to the Touch Bar system tray area (right side, next to Siri).
    // Uses NSTouchBarItem.addSystemTrayItem: — a private but stable API used by
    // all major Touch Bar utilities (Pock, Silenz, etc.) since macOS 10.12.2.
    private func addToSystemTray(_ item: NSCustomTouchBarItem) {
        let sel = NSSelectorFromString("addSystemTrayItem:")
        guard let method = class_getClassMethod(NSTouchBarItem.self, sel) else { return }

        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        let fn = unsafeBitCast(method_getImplementation(method), to: Fn.self)
        fn(NSTouchBarItem.self, sel, item)
    }

    // MARK: - Timer

    private func scheduleTimer() {
        update()
        let t = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in self?.update() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Update

    private func update() {
        guard let reader else { return }
        let temp = reader.currentTemperature()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.tempLabel?.stringValue = temp > 0 ? String(format: "%.0f°", temp) : "–°"
            self.tempLabel?.textColor = self.useColors ? self.color(for: temp) : .white
        }
    }

    // Green < 70 °C · Orange 70–85 °C · Red > 85 °C
    private func color(for temp: Double) -> NSColor {
        if temp < 70 { return .systemGreen }
        if temp < 85 { return .systemOrange }
        return .systemRed
    }

    // SF Pro Rounded Heavy — native macOS look, no external font needed
    private func heavyRoundedFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .heavy)
        guard let desc = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: desc, size: size) ?? base
    }
}
