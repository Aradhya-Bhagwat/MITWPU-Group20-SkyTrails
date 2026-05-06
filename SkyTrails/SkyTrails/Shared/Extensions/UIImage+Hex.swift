import UIKit

extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    static func fromHex(_ hex: String) -> UIColor? {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        return UIColor(
            red:   CGFloat((val >> 16) & 0xFF) / 255,
            green: CGFloat((val >> 8)  & 0xFF) / 255,
            blue:  CGFloat( val        & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension UIImage {
    func withTint(_ color: UIColor, alpha: CGFloat = 0.5) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        
        // Handle potential white background by masking it as transparent
        let maskingColors: [CGFloat] = [248, 255, 248, 255, 248, 255]
        let cgImageToUse: CGImage?
        if let cg = self.cgImage {
            cgImageToUse = cg.copy(maskingColorComponents: maskingColors)
        } else {
            cgImageToUse = nil
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            if let masked = cgImageToUse {
                UIImage(cgImage: masked).draw(in: rect)
            } else {
                draw(in: rect)
            }
            
            context.cgContext.setBlendMode(.sourceAtop)
            color.withAlphaComponent(alpha).setFill()
            context.cgContext.fill(rect)
        }
    }
}
