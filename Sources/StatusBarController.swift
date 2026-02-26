import AppKit

class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let wallpaperManager = WallpaperManager()
    private let unsplashService = UnsplashService()
    private var timer: Timer?
    private var currentCredit: String?
    private var lastError: String?
    private var isLoading = false
    private var isPaused = false

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "WallSpan")
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesChanged),
            name: Preferences.changedNotification,
            object: nil
        )

        startTimer()
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        if let credit = currentCredit {
            let item = NSMenuItem(title: credit, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(NSMenuItem.separator())
        }

        if let error = lastError {
            let item = NSMenuItem(title: error, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(NSMenuItem.separator())
        }

        if isLoading {
            let item = NSMenuItem(title: "Loading wallpaper...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(NSMenuItem.separator())
        }

        if Preferences.shared.apiKey.isEmpty {
            let item = NSMenuItem(title: "⚠ Set API key in Preferences", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(NSMenuItem.separator())
        }

        let nextItem = NSMenuItem(title: "Next Wallpaper", action: #selector(nextWallpaper), keyEquivalent: "n")
        nextItem.target = self
        nextItem.isEnabled = !isLoading
        menu.addItem(nextItem)

        let pauseTitle = isPaused ? "Resume Auto-Rotate" : "Pause Auto-Rotate"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit WallSpan", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func nextWallpaper() {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil

        NSLog("[WallSpan] Fetching random photo...")
        unsplashService.fetchRandomPhoto { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let photo):
                NSLog("[WallSpan] Got photo by %@, downloading from %@", photo.photographer, photo.imageURL.absoluteString)
                DispatchQueue.main.async {
                    self.currentCredit = "📷 \(photo.photographer) on Unsplash"
                }
                self.wallpaperManager.applyWallpaper(from: photo.imageURL) { error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if let error = error {
                            NSLog("[WallSpan] Wallpaper error: %@", error.localizedDescription)
                            self.lastError = "Error: \(error.localizedDescription)"
                        } else {
                            NSLog("[WallSpan] Wallpaper set successfully")
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.lastError = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    @objc private func togglePause() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            timer = nil
        } else {
            startTimer()
        }
    }

    @objc private func showPreferences() {
        PreferencesWindow.shared.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func preferencesChanged() {
        if !isPaused {
            startTimer()
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        let interval = Preferences.shared.rotationInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.nextWallpaper()
        }
        // Fetch on launch / preference change
        nextWallpaper()
    }
}
