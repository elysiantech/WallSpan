import Foundation

enum DisplayMode: String {
    case span = "span"
    case individual = "individual"
}

class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    static let changedNotification = Notification.Name("WallSpanPreferencesChanged")

    var apiKey: String {
        get { defaults.string(forKey: "unsplashAPIKey") ?? "" }
        set {
            defaults.set(newValue, forKey: "unsplashAPIKey")
            NotificationCenter.default.post(name: Self.changedNotification, object: nil)
        }
    }

    var displayMode: DisplayMode {
        get {
            let raw = defaults.string(forKey: "displayMode") ?? "span"
            return DisplayMode(rawValue: raw) ?? .span
        }
        set {
            defaults.set(newValue.rawValue, forKey: "displayMode")
            NotificationCenter.default.post(name: Self.changedNotification, object: nil)
        }
    }

    var rotationInterval: TimeInterval {
        get {
            let val = defaults.double(forKey: "rotationInterval")
            return val > 0 ? val : 1800
        }
        set {
            defaults.set(newValue, forKey: "rotationInterval")
            NotificationCenter.default.post(name: Self.changedNotification, object: nil)
        }
    }

    var searchTerms: [String] {
        get {
            defaults.stringArray(forKey: "searchTerms") ?? [
                "bridge night city lights",
                "nebula astrophotography",
                "night bridge long exposure",
                "galaxy nebula stars",
                "suspension bridge night",
                "milky way astrophotography",
                "bridge cityscape night",
                "deep space nebula hubble"
            ]
        }
        set {
            defaults.set(newValue, forKey: "searchTerms")
            NotificationCenter.default.post(name: Self.changedNotification, object: nil)
        }
    }
}
