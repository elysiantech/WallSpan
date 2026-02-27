import AppKit

struct PhotoPreview {
    let photo: UnsplashPhoto
    let thumbnail: NSImage
}

class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let wallpaperManager = WallpaperManager()
    private let unsplashService = UnsplashService()
    private var timer: Timer?

    // Preview buffer - circular, max 10
    private var previewBuffer: [PhotoPreview] = []
    private var previewIndex: Int = -1
    private let maxPreviews = 10

    private var appliedCredit: String?
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

        // Show current preview if available
        if previewIndex >= 0 && previewIndex < previewBuffer.count {
            let preview = previewBuffer[previewIndex]
            let previewItem = NSMenuItem()
            let previewView = createPreviewView(image: preview.thumbnail, credit: "📷 \(preview.photo.photographer)")
            previewItem.view = previewView
            menu.addItem(previewItem)

            // Apply button
            let applyItem = NSMenuItem(title: "Apply This Wallpaper", action: #selector(applyCurrentPreview), keyEquivalent: "a")
            applyItem.target = self
            applyItem.isEnabled = !isLoading
            menu.addItem(applyItem)

            menu.addItem(NSMenuItem.separator())
        }

        // Show applied wallpaper credit
        if let credit = appliedCredit {
            let item = NSMenuItem(title: "Current: \(credit)", action: nil, keyEquivalent: "")
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
            let item = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
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

    // MARK: - Preview View

    private func createPreviewView(image: NSImage, credit: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 160))

        let imageView = NSImageView(frame: NSRect(x: 10, y: 10, width: 260, height: 140))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        container.addSubview(imageView)

        // Previous button (left arrow) - only if there's history
        if previewIndex > 0 {
            let prevButton = NSButton(frame: NSRect(x: 15, y: 65, width: 30, height: 30))
            prevButton.image = NSImage(systemSymbolName: "chevron.left.circle.fill", accessibilityDescription: "Previous")
            prevButton.imageScaling = .scaleProportionallyUpOrDown
            prevButton.isBordered = false
            prevButton.wantsLayer = true
            prevButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
            prevButton.layer?.cornerRadius = 15
            prevButton.contentTintColor = .white
            prevButton.target = self
            prevButton.action = #selector(previousPreview)
            container.addSubview(prevButton)
        }

        // Next button (right arrow) - always visible, fetches new when at end
        let nextButton = NSButton(frame: NSRect(x: 235, y: 65, width: 30, height: 30))
        nextButton.image = NSImage(systemSymbolName: "chevron.right.circle.fill", accessibilityDescription: "Next")
        nextButton.imageScaling = .scaleProportionallyUpOrDown
        nextButton.isBordered = false
        nextButton.wantsLayer = true
        nextButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        nextButton.layer?.cornerRadius = 15
        nextButton.contentTintColor = .white
        nextButton.target = self
        nextButton.action = #selector(nextOrFetchPreview)
        nextButton.isEnabled = !isLoading
        container.addSubview(nextButton)

        // Semi-transparent background for text at bottom
        let labelBg = NSView(frame: NSRect(x: 10, y: 10, width: 260, height: 26))
        labelBg.wantsLayer = true
        labelBg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        labelBg.layer?.cornerRadius = 8
        labelBg.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        container.addSubview(labelBg)

        // Credit on left, position on right
        let label = NSTextField(labelWithString: credit)
        label.frame = NSRect(x: 15, y: 14, width: 180, height: 18)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.alignment = .left
        container.addSubview(label)

        let posLabel = NSTextField(labelWithString: "\(previewIndex + 1)/\(previewBuffer.count)")
        posLabel.frame = NSRect(x: 200, y: 14, width: 60, height: 18)
        posLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        posLabel.textColor = .white.withAlphaComponent(0.7)
        posLabel.alignment = .right
        container.addSubview(posLabel)

        return container
    }

    // MARK: - Actions

    @objc private func fetchNewPreview() {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil

        NSLog("[WallSpan] Fetching preview...")
        unsplashService.fetchRandomPhoto { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let photo):
                NSLog("[WallSpan] Got photo by %@, fetching thumbnail", photo.photographer)
                self.downloadThumbnail(for: photo)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.lastError = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func downloadThumbnail(for photo: UnsplashPhoto) {
        URLSession.shared.dataTask(with: photo.thumbnailURL) { [weak self] data, _, _ in
            guard let self = self, let data = data, let image = NSImage(data: data) else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.lastError = "Failed to load thumbnail"
                }
                return
            }
            DispatchQueue.main.async {
                self.addPreview(PhotoPreview(photo: photo, thumbnail: image))
                self.isLoading = false
            }
        }.resume()
    }

    private func addPreview(_ preview: PhotoPreview) {
        // If we're not at the end, truncate forward history
        if previewIndex < previewBuffer.count - 1 {
            previewBuffer = Array(previewBuffer.prefix(previewIndex + 1))
        }

        // Add new preview
        previewBuffer.append(preview)

        // Enforce max size (circular buffer)
        if previewBuffer.count > maxPreviews {
            previewBuffer.removeFirst()
        }

        // Move to newest
        previewIndex = previewBuffer.count - 1
    }

    @objc private func previousPreview() {
        if previewIndex > 0 {
            previewIndex -= 1
            refreshMenu()
        }
    }

    @objc private func nextPreview() {
        if previewIndex < previewBuffer.count - 1 {
            previewIndex += 1
        }
    }

    @objc private func nextOrFetchPreview() {
        // If there's more history ahead, just move forward
        if previewIndex < previewBuffer.count - 1 {
            previewIndex += 1
            refreshMenu()
        } else {
            // At the end, fetch a new one
            fetchNewPreviewAndRefresh()
        }
    }

    private func fetchNewPreviewAndRefresh() {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        refreshMenu()

        NSLog("[WallSpan] Fetching preview...")
        unsplashService.fetchRandomPhoto { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let photo):
                NSLog("[WallSpan] Got photo by %@, fetching thumbnail", photo.photographer)
                URLSession.shared.dataTask(with: photo.thumbnailURL) { [weak self] data, _, _ in
                    guard let self = self, let data = data, let image = NSImage(data: data) else {
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            self?.lastError = "Failed to load thumbnail"
                            self?.refreshMenu()
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.addPreview(PhotoPreview(photo: photo, thumbnail: image))
                        self.isLoading = false
                        self.refreshMenu()
                    }
                }.resume()
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.lastError = "Error: \(error.localizedDescription)"
                    self.refreshMenu()
                }
            }
        }
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        menuWillOpen(menu)
    }

    @objc private func applyCurrentPreview() {
        guard previewIndex >= 0 && previewIndex < previewBuffer.count else { return }
        guard !isLoading else { return }

        let preview = previewBuffer[previewIndex]
        isLoading = true
        lastError = nil

        NSLog("[WallSpan] Applying wallpaper by %@", preview.photo.photographer)
        wallpaperManager.applyWallpaper(from: preview.photo.imageURL) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    NSLog("[WallSpan] Wallpaper error: %@", error.localizedDescription)
                    self?.lastError = "Error: \(error.localizedDescription)"
                } else {
                    NSLog("[WallSpan] Wallpaper set successfully")
                    self?.appliedCredit = preview.photo.photographer
                }
            }
        }
    }

    /// Auto-rotate: fetch and apply directly (legacy behavior for timer)
    private func autoRotate() {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil

        unsplashService.fetchRandomPhoto { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let photo):
                // Add to buffer for history
                self.downloadThumbnail(for: photo)
                self.wallpaperManager.applyWallpaper(from: photo.imageURL) { error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if let error = error {
                            self.lastError = "Error: \(error.localizedDescription)"
                        } else {
                            self.appliedCredit = photo.photographer
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
            self?.autoRotate()
        }
        // Fetch preview on launch
        fetchNewPreview()
    }
}
