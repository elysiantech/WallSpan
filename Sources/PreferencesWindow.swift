import AppKit

class PreferencesWindow: NSObject {
    static let shared = PreferencesWindow()

    private var window: NSWindow?
    private var apiKeyField: NSTextField!
    private var intervalPopup: NSPopUpButton!
    private var searchTermsView: NSTextView!

    private let intervalOptions: [(String, TimeInterval)] = [
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("6 hours", 21600),
        ("12 hours", 43200),
        ("24 hours", 86400),
    ]

    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WallSpan Preferences"
        window.center()
        window.isReleasedWhenClosed = false

        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        window.contentView = content

        var y = 380

        // API Key
        let apiLabel = NSTextField(labelWithString: "Unsplash API Key:")
        apiLabel.frame = NSRect(x: 20, y: y, width: 200, height: 18)
        content.addSubview(apiLabel)
        y -= 28

        apiKeyField = NSTextField(frame: NSRect(x: 20, y: y, width: 440, height: 24))
        apiKeyField.stringValue = Preferences.shared.apiKey
        apiKeyField.placeholderString = "Paste your Unsplash access key here"
        content.addSubview(apiKeyField)
        y -= 16

        let apiHint = NSTextField(labelWithString: "Get one free at unsplash.com/developers")
        apiHint.frame = NSRect(x: 20, y: y, width: 440, height: 14)
        apiHint.font = NSFont.systemFont(ofSize: 11)
        apiHint.textColor = .secondaryLabelColor
        content.addSubview(apiHint)
        y -= 36

        // Rotation interval
        let intervalLabel = NSTextField(labelWithString: "Rotate every:")
        intervalLabel.frame = NSRect(x: 20, y: y, width: 200, height: 18)
        content.addSubview(intervalLabel)
        y -= 28

        intervalPopup = NSPopUpButton(frame: NSRect(x: 20, y: y, width: 200, height: 24))
        intervalPopup.addItems(withTitles: intervalOptions.map { $0.0 })
        let currentInterval = Preferences.shared.rotationInterval
        if let idx = intervalOptions.firstIndex(where: { $0.1 == currentInterval }) {
            intervalPopup.selectItem(at: idx)
        } else {
            intervalPopup.selectItem(at: 1)
        }
        content.addSubview(intervalPopup)
        y -= 36

        // Search terms
        let termsLabel = NSTextField(labelWithString: "Search terms (one per line):")
        termsLabel.frame = NSRect(x: 20, y: y, width: 300, height: 18)
        content.addSubview(termsLabel)
        y -= 8

        let scrollHeight = 155
        let scrollY = y - scrollHeight
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: scrollY, width: 440, height: scrollHeight))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        searchTermsView = NSTextView(frame: NSRect(x: 0, y: 0, width: 440, height: scrollHeight))
        searchTermsView.minSize = NSSize(width: 0, height: CGFloat(scrollHeight))
        searchTermsView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        searchTermsView.isVerticallyResizable = true
        searchTermsView.isHorizontallyResizable = false
        searchTermsView.autoresizingMask = [.width]
        searchTermsView.textContainer?.containerSize = NSSize(width: 440, height: CGFloat.greatestFiniteMagnitude)
        searchTermsView.textContainer?.widthTracksTextView = true
        searchTermsView.font = NSFont.systemFont(ofSize: 13)
        searchTermsView.string = Preferences.shared.searchTerms.joined(separator: "\n")
        scrollView.documentView = searchTermsView
        content.addSubview(scrollView)

        // Save button
        let saveButton = NSButton(frame: NSRect(x: 370, y: 20, width: 90, height: 30))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(save)
        content.addSubview(saveButton)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    @objc private func save() {
        let selectedIndex = intervalPopup.indexOfSelectedItem
        let interval = intervalOptions[selectedIndex].1

        let terms = searchTermsView.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Write all at once, notification fires on last write
        Preferences.shared.apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        Preferences.shared.rotationInterval = interval
        Preferences.shared.searchTerms = terms

        window?.close()
    }
}
