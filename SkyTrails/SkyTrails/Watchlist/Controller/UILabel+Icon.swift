//
//  UILabel+Icon.swift
//  SkyTrails
//
//  Created by SDC-USER on 13/01/26.
//

import UIKit

extension UILabel {
    func addIcon(text: String, iconName: String, iconSize: CGFloat = 10, iconWeight: UIImage.SymbolWeight = .semibold) {
        let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: iconWeight)
        let image = UIImage(systemName: iconName, withConfiguration: config)?
            .withTintColor(self.textColor ?? .label, renderingMode: .alwaysOriginal)
        
        guard let safeImage = image else {
            self.text = text
            return
        }
        
        let attachment = NSTextAttachment(image: safeImage)
        let yOffset = (self.font.capHeight - safeImage.size.height).rounded() / 2
        attachment.bounds = CGRect(x: 0, y: yOffset - 1, width: safeImage.size.width, height: safeImage.size.height)
        
        let attrString = NSMutableAttributedString(attachment: attachment)
        attrString.append(NSAttributedString(string: "  " + text))
        
        self.attributedText = attrString
    }
}
