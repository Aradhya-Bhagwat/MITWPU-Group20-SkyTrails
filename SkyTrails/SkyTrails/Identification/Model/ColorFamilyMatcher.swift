import UIKit

enum ColorFamily {
    case red, orange, yellow, green, blue, purple, brown, white, black, grey
}

struct ColorFamilyMatcher {

    static func family(from hex: String) -> ColorFamily {
        guard let color = UIColor.fromHex(hex) else { return .grey }
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        // 1. Convert hex to UIColor, get HSB components
        // 2. If brightness < 0.15 → .black
        if b < 0.15 { return .black }
        
        // 3. If saturation < 0.15 && brightness > 0.85 → .white
        if s < 0.15 && b > 0.85 { return .white }
        
        // 4. If saturation < 0.15 → .grey
        if s < 0.15 { return .grey }
        
        // Brown heuristic: Orange/Red hue with medium/low brightness
        if ((h >= 0.0 && h <= 0.12) || h >= 0.95) && b < 0.6 && s > 0.2 {
            return .brown
        }
        
        // 5. Map hue (0–1 scale) to family:
        switch h {
        case 0.0...0.04, 0.96...1.0: 
            return .red
        case 0.04...0.11: 
            return .orange
        case 0.11...0.18: 
            return .yellow
        case 0.18...0.44: 
            return .green
        case 0.44...0.68: 
            return .blue
        case 0.68...0.80: 
            return .purple
        case 0.80...0.96: 
            return .red // pink/magenta maps to red
        default: 
            return .grey
        }
    }

    private static let adjacency: [ColorFamily: Set<ColorFamily>] = [
        .red:    [.orange, .purple],
        .orange: [.red, .yellow, .brown],
        .yellow: [.orange, .green],
        .green:  [.yellow, .blue],
        .blue:   [.green, .purple],
        .purple: [.blue, .red],
        .brown:  [.orange, .black],
        .white:  [.grey],
        .black:  [.grey, .brown],
        .grey:   [.white, .black]
    ]

    static func points(userHex: String, birdHex: String) -> Int {
        let userFamily = family(from: userHex)
        let birdFamily = family(from: birdHex)
        if userFamily == birdFamily { return 10 }
        if adjacency[userFamily]?.contains(birdFamily) == true { return 5 }
        return 0
    }
}
