import UIKit

enum ThemeService {
    static let colorModeKey = "profile_color_mode"

    static func applySavedTheme() {
        let mode = UserDefaults.standard.string(forKey: colorModeKey) ?? "System Default"
        applyTheme(named: mode)
    }

    static func applyTheme(named mode: String) {
        let style: UIUserInterfaceStyle
        switch mode {
        case "Light":
            style = .light
        case "Dark":
            style = .dark
        default:
            style = .unspecified
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
