//
//  UIStoryboard+Extension.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit

extension UIStoryboard {
    /// Instantiates a view controller of the specified type, assuming the storyboard ID matches the class name.
    func instantiate<T: UIViewController>(_ type: T.Type) -> T {
        let identifier = String(describing: type)
        guard let vc = self.instantiateViewController(withIdentifier: identifier) as? T else {
            fatalError("Could not instantiate view controller with identifier \(identifier) from storyboard.")
        }
        return vc
    }
    
    /// Convenience initializer for creating a storyboard with a name and default bundle.
    static func named(_ name: String) -> UIStoryboard {
        return UIStoryboard(name: name, bundle: nil)
    }
}