import AppKit
import ObjectiveC

final class TouchBarController: NSObject, NSTouchBarDelegate {

    private let itemID = NSTouchBarItem.Identifier("com.touchbar-temp.temperature")
    private var systemTrayItem: NSCustomTouchBarItem?  // must be retained
    private var touchBarRef: NSTouchBar?               // must be retained
    private weak var tempButton: NSButton?
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
        systemTrayItem = item

        // Small delay so the Touch Bar system is fully initialised before we inject.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.addToSystemTray(item)
        }
        scheduleTimer()
    }

    // MARK: - Touch Bar Item

    private func makeItem() -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: itemID)
        item.customizationLabel = "CPU Temperature"

        // NSButton sizes itself correctly inside the Touch Bar;
        // NSTextField with sizeToFit() can collapse to zero before layout.
        let btn = NSButton(title: "–°", target: self, action: #selector(toggleColorsFromBar))
        btn.bezelStyle = .rounded
        btn.isBordered = false
        btn.font = heavyRoundedFont(size: 17)
        btn.contentTintColor = .white

        tempButton = btn
        item.view = btn
        return item
    }

    @objc private func toggleColorsFromBar() {
        useColors.toggle()
    }

    // MARK: - System Tray Injection

    // Shows the temperature in the Touch Bar system tray (right side, next to Siri).
    //
    // How it works:
    //  1. presentSystemModalTouchBar:placement:1 — registers our item as the
    //     "system tray item" and briefly shows a modal Touch Bar.
    //  2. After 400ms, minimizeSystemModalTouchBar: — collapses the modal back to
    //     the app's normal Touch Bar while keeping the temperature icon in the
    //     system tray area. This is the same pattern used by apps like Silenz.
    private func addToSystemTray(_ item: NSCustomTouchBarItem) {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [itemID]
        self.touchBarRef = bar

        presentModal(bar)

        // Brief delay so the system registers the modal before we minimize it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.minimizeModal(self.touchBarRef)
        }
    }

    private func presentModal(_ bar: NSTouchBar) {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject?, Int64, NSString?) -> Void
        let sel = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        guard let m = class_getClassMethod(NSTouchBar.self, sel) else { return }
        let fn = unsafeBitCast(method_getImplementation(m), to: Fn.self)
        fn(NSTouchBar.self, sel, bar, 1, itemID.rawValue as NSString)
    }

    private func minimizeModal(_ bar: NSTouchBar?) {
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let sel = NSSelectorFromString("minimizeSystemModalTouchBar:")
        guard let m = class_getClassMethod(NSTouchBar.self, sel) else { return }
        let fn = unsafeBitCast(method_getImplementation(m), to: Fn.self)
        fn(NSTouchBar.self, sel, bar)
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == itemID else { return nil }
        return systemTrayItem
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
            let title = temp > 0 ? String(format: "%.0f°", temp) : "–°"
            self.tempButton?.title = title
            self.tempButton?.contentTintColor = self.useColors ? self.color(for: temp) : .white
        }
    }

    // Green < 70 °C · Orange 70–85 °C · Red > 85 °C
    private func color(for temp: Double) -> NSColor {
        if temp < 70 { return .systemGreen }
        if temp < 85 { return .systemOrange }
        return .systemRed
    }

    // MARK: - Font

    // SF Pro Rounded Heavy — native macOS look, no external font needed
    private func heavyRoundedFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .heavy)
        guard let desc = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: desc, size: size) ?? base
    }
}
