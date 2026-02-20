//
//  HomeController+mapnavigation.swift
//  SkyTrails
//
//  Created by SDC-USER on 19/02/26.
//


//
//  HomeViewController+MapNavigation.swift
//  SkyTrails
//
//  Drop this file in alongside HomeViewController.swift.
//  It replaces the two navigation helpers so taps from Home also flow
//  correctly through to the multi-bird map screen.
//

import UIKit

// MARK: - Map Navigation Helpers (extension on HomeViewController)
//
// Replace the existing `navigateToBirdPrediction(bird:statusText:)` method
// in HomeViewController with the version below, and update the
// case 0 / case 1 didSelectItemAt switch to call `navigateToMap(inputs:)`.
