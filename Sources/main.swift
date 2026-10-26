// Éveil : empêche le Mac de se mettre en veille, depuis la barre des menus.
import AppKit
import IOKit.ps
import IOKit.pwr_mgt
import ServiceManagement

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let defaults = UserDefaults.standard
    var assertion: IOPMAssertionID = 0
    var active = false
    var until: Date?          // nil = indéfiniment
    var timer: Timer?

    let durations: [(String, TimeInterval?)] = [
        ("Indéfiniment", nil), ("15 minutes", 900), ("30 minutes", 1800), ("1 heure", 3600),
        ("2 heures", 7200), ("4 heures", 14400), ("8 heures", 28800),
    ]

    /// true : seul le Mac reste éveillé, l'écran peut s'éteindre.
    var screenMaySleep: Bool {
        get { defaults.bool(forKey: "screenMaySleep") }
        set { defaults.set(newValue, forKey: "screenMaySleep") }
    }
    /// Se désactive tout seul sur batterie sous 20 %.
    var batteryGuard: Bool {
        get { defaults.object(forKey: "batteryGuard") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "batteryGuard") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        status.menu = menu
        refreshIcon()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.tick() }
    }

    func applicationWillTerminate(_ notification: Notification) { stop() }

    // MARK: Veille

    func start(for duration: TimeInterval?) {
        stop()
        let type = (screenMaySleep ? kIOPMAssertPreventUserIdleSystemSleep : kIOPMAssertPreventUserIdleDisplaySleep) as CFString
        let ok = IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                             "Éveil garde le Mac éveillé" as CFString, &assertion)
        guard ok == kIOReturnSuccess else { return }
        active = true
        until = duration.map { Date().addingTimeInterval($0) }
        refreshIcon()
    }

    func stop() {
        if active { IOPMAssertionRelease(assertion) }
        active = false
        until = nil
        refreshIcon()
    }

    func tick() {
        guard active else { return }
        if let until, until <= Date() { return stop() }
        if batteryGuard, let level = batteryLevelOnBattery(), level < 20 { return stop() }
        refreshIcon()
    }

    /// Niveau de batterie en %, ou nil si le Mac est branché (ou n'a pas de batterie).
    func batteryLevelOnBattery() -> Int? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue,
                  let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return cur * 100 / max
        }
        return nil
    }

    func remaining() -> String? {
        guard let until else { return nil }
        let m = max(1, Int(ceil(until.timeIntervalSinceNow / 60)))
        return m >= 60 ? "\(m / 60) h \(String(format: "%02d", m % 60))" : "\(m) min"
    }

    func refreshIcon() {
        let name = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        status.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Éveil")
        status.button?.imagePosition = .imageLeading
        status.button?.title = active ? (remaining().map { " " + $0 } ?? " ∞") : ""
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = NSMenuItem(title: active ? (remaining().map { "Éveillé — encore \($0)" } ?? "Éveillé indéfiniment")
                                             : "La veille fonctionne normalement",
                               action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        if active {
            menu.addItem(item("Laisser dormir maintenant", #selector(stopAction), key: "s"))
        }
        menu.addItem(.separator())

        let header = NSMenuItem(title: "Garder éveillé…", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for (i, (title, _)) in durations.enumerated() {
            let it = item(title, #selector(startAction(_:)), key: i < 9 ? "\(i + 1)" : "")
            it.tag = i
            it.indentationLevel = 1
            menu.addItem(it)
        }

        menu.addItem(.separator())
        let screen = item("Laisser l'écran s'éteindre", #selector(toggleScreen))
        screen.state = screenMaySleep ? .on : .off
        menu.addItem(screen)
        let battery = item("S'arrêter sur batterie sous 20 %", #selector(toggleBattery))
        battery.state = batteryGuard ? .on : .off
        menu.addItem(battery)
        let login = item("Ouvrir au démarrage", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        let quit = item("Quitter Éveil", #selector(NSApplication.terminate(_:)), key: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        it.target = self
        return it
    }

    @objc func startAction(_ sender: NSMenuItem) { start(for: durations[sender.tag].1) }
    @objc func stopAction() { stop() }

    @objc func toggleScreen() {
        screenMaySleep.toggle()
        if active {  // réapplique avec le nouveau mode en gardant l'échéance
            let left = until.map { $0.timeIntervalSinceNow }
            start(for: left)
        }
    }

    @objc func toggleBattery() { batteryGuard.toggle() }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Impossible de modifier l'ouverture au démarrage"
            alert.informativeText = "Place Éveil dans le dossier Applications puis réessaie.\n\(error.localizedDescription)"
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
