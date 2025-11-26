//
//  ViewModel.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//
import Foundation

class ViewModel {

   
    var fieldMarkOptions: [FieldMarkType] = [
        FieldMarkType(symbols: "icn_size", fieldMarkName: "Size"),
        FieldMarkType(symbols: "icn_field_marks", fieldMarkName: "Field Marks"),
        FieldMarkType(symbols: "icn_location_date_pin", fieldMarkName: "Location & Date"),
        FieldMarkType(symbols: "icn_shape_bird_question", fieldMarkName: "Shape")
    ]

      
        var historyItems: [History] = []
        
    let migrationHistory: [History] = [
        History(
            imageView: "bird_common_kingfisher",
            specieName: "Common Kingfisher",
            date: Date() // today
        ),
        History(
            imageView: "bird_hoopoe",
            specieName: "Hoopoe",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())! // yesterday
        ),
        History(
            imageView: "bird_blue_throated_barbet",
            specieName: "Blue-Throated Barbaret",
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date())! // 5 days ago
        ),
        History(
            imageView: "bird_spoonbill",
            specieName: "SpoonBill",
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date())! // 10 days ago
        )
    ]
    
    
}

