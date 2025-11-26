//
//  Coordinator.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

protocol Coordinator {
    var navigationController: UINavigationController { get set }
    func start()
}
