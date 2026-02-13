//
//  UIView+Shadow.swift
//  SkyTrails
//
//  Created by SDC-USER on 13/01/26.
//

import UIKit

extension UIView {
    @IBInspectable var shadow: Bool {
        get { layer.shadowOpacity > 0 }
        set {
            if newValue {
                let isDarkMode = traitCollection.userInterfaceStyle == .dark
                layer.shadowColor = UIColor.black.cgColor
                layer.shadowOpacity = isDarkMode ? 0 : 0.1
                layer.shadowOffset = CGSize(width: 0, height: 2)
                layer.shadowRadius = 4
                layer.masksToBounds = false
            } else {
                layer.shadowOpacity = 0
            }
        }
    }
    
    func applyShadow(radius: CGFloat, opacity: Float, offset: CGSize, color: UIColor = .black) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = isDarkMode ? 0 : opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        layer.masksToBounds = false
    }
}
