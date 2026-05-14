import AppKit
import ObjectiveC

final class TouchBarController: NSObject, NSTouchBarDelegate {

    private let itemID = NSTouchBarItem.Identifier("com.touchbar-temp.temperature")
    private weak var tempLabel: NSTextField?
    private var touchBar: NSTouchBar?
    private var timer: Timer?
    private var reader: TemperatureReader?

    var useColors: Bool {
        get { UserDefaults.standard.object(forKey: "useColors") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "useColors") }
    }

    // MARK: - Lifecycle

    func start(reader: TemperatureReader) {
        self.reader = reader

        touchBar = NSTouchBar()
        touchBar?.delegate = self
        touchBar?.defaultItemIdentifiers = [itemID]

        presentInSystemTray()
        scheduleTimer()
    }

    // MARK: - Touch Bar Presentation

    // presentSystemModalTouchBar:placement:systemTrayItemIdentifier: is a documented
    // AppKit API (macOS 10.12.2+) but not always bridged in Swift headers.
    // We call it via ObjC runtime to stay forward-compatible.
    private func presentInSystemTray() {
        guard let tb = touchBar else { return }

        let selName = "presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"
        let sel = NSSelectorFromString(selName)

        guard let method = class_getClassMethod(NSTouchBar.self, sel) else {
            // Touch Bar not supported on this machine.
            return
        }

        typealias PresentFn = @convention(c) (AnyObject, Selector, AnyObject?, Int64, NSString?) -> Void
        let imp = method_getImplementation(method)
        let fn = unsafeBitCast(imp, to: PresentFn.self)
        fn(NSTouchBar.self, sel, tb, 1, itemID.rawValue as NSString)
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

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == itemID else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)

        let label = NSTextField(labelWithString: "–°")
        label.font = heavyRoundedFont(size: 17)
        label.textColor = .white
        label.alignment = .center
        label.sizeToFit()

        tempLabel = label
        item.view = label
        return item
    }

    // SF Pro Rounded Heavy — native macOS look, no external font needed
    private func heavyRoundedFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .heavy)
        guard let desc = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: desc, size: size) ?? base
    }
}
