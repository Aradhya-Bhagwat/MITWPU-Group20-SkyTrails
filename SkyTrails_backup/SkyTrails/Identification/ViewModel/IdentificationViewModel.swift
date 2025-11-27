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

      
        //var historyItems: [History] = []
        
    let migrationHistory: [History] = [
        History(
            imageView: "bird_common_kingfisher",
            specieName: "Common Kingfisher",
            date: Date()         ),
        History(
            imageView: "bird_hoopoe",
            specieName: "Hoopoe",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
        History(
            imageView: "bird_blue_throated_barbet",
            specieName: "Blue-Throated Barbaret",
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        ),
        History(
            imageView: "bird_spoonbill",
            specieName: "SpoonBill",
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date())! 
        )
    ]
    
  //  var birdShape: [BirdShape] = []
    let birdShapes: [BirdShape] = [
        BirdShape(ImageView: "bird_auks_shape", Name: "Auks"),
        BirdShape(ImageView: "bird_chickadees_shape", Name: "Chickadees"),
        BirdShape(ImageView: "bird_owls_shape", Name: "Owls"),
        BirdShape(ImageView: "bird_ducks_shape", Name: "Ducks"),
        BirdShape(ImageView: "bird_hummingbird_shape", Name: "Hummingbird"),
        BirdShape(ImageView: "bird_heron_shape", Name: "Heron"),
        BirdShape(ImageView: "bird_shorebird_shape", Name: "Shorebird"),
        BirdShape(ImageView: "bird_game_bird_shape", Name: "Game Bird"),
        BirdShape(ImageView: "bird_finch_shape", Name: "Finch"),
        BirdShape(ImageView: "bird_doves_shape", Name: "Doves"),
        BirdShape(ImageView: "bird_wrens_shape", Name: "Wrens"),
        BirdShape(ImageView: "bird_hawks_and_falcons_shape", Name: "Hawks & Falcons")
    ]
    
    
}

