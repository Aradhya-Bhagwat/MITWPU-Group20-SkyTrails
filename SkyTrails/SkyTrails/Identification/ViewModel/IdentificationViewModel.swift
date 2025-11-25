//
//  ViewModel.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//
import Foundation

class ViewModel {

        var fieldMarkOptions: [FieldMarkType] = [
            FieldMarkType(symbols: ["bird", "bird.fill"], fieldMarkName: "Size"),
            FieldMarkType(symbols: ["circle", "line.horizontal"], fieldMarkName: "Field Marks"),
            FieldMarkType(symbols: ["location.fill"], fieldMarkName: "Location & Date"),
            FieldMarkType(symbols: ["questionmark.circle"], fieldMarkName: "Shape")
        ]

      
        var historyItems: [History] = []
    
    
    
}

