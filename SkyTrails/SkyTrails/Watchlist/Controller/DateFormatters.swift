//
//  DateFormatters.swift
//  SkyTrails
//
//  Created by SDC-USER on 13/01/26.
//

import Foundation

enum DateFormatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
}
