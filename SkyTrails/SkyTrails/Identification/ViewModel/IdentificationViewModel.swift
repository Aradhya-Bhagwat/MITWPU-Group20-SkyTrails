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

      
        
    let migrationHistory: [History] = [
        History(
            imageView: "bird_Common_kingfisher",
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
    
 
    let birdShapes: [BirdShape] = [
        BirdShape(imageView: "bird_auks_shape", name: "Auks"),
        BirdShape(imageView: "bird_chickadees_shape", name: "Chickadees"),
        BirdShape(imageView: "bird_owls_shape", name: "Owls"),
        BirdShape(imageView: "bird_ducks_shape", name: "Ducks"),
        BirdShape(imageView: "bird_hummingbird_shape", name: "Hummingbird"),
        BirdShape(imageView: "bird_heron_shape", name: "Heron"),
        BirdShape(imageView: "bird_shorebird_shape", name: "Shorebird"),
        BirdShape(imageView: "bird_game_bird_shape", name: "Game Bird"),
        BirdShape(imageView: "bird_finch_shape", name: "Finch"),
        BirdShape(imageView: "bird_doves_shape", name: "Doves"),
        BirdShape(imageView: "bird_wrens_shape", name: "Wrens"),
        BirdShape(imageView: "bird_hawks_and_falcons_shape", name: "Hawks & Falcons")
    ]
    
    let fieldMarks: [ChooseFieldMark] = [
        ChooseFieldMark(imageView: "bird_back", name: "Back"),
        ChooseFieldMark(imageView: "bird_beak", name: "Beak"),
        ChooseFieldMark(imageView: "bird_belly", name: "Belly"),
        ChooseFieldMark(imageView: "bird_crown", name: "Crown"),
        ChooseFieldMark(imageView: "bird_eye", name: "Eye"),
        ChooseFieldMark(imageView: "bird_leg", name: "Leg"),
        ChooseFieldMark(imageView: "bird_nape", name: "Nape"),
        ChooseFieldMark(imageView: "bird_tail", name: "Tail"),
        ChooseFieldMark(imageView: "bird_thigh", name: "Thigh"),
        ChooseFieldMark(imageView: "bird_throat", name: "Throat"),
        ChooseFieldMark(imageView: "bird_wings", name: "Wings")
    ]
    let birdResults: [BirdResult] = [
        BirdResult(name: "Asian Fairy Bluebird", percentage: 85, imageView: "bird_asian_fairy_bluebird"),
        BirdResult(name: "Indigo Bunting", percentage: 80, imageView: "bird_indigo_bunting"),
        BirdResult(name: "Blue Grosbeak", percentage: 51, imageView: "bird_blue_grosbeak"),
        BirdResult(name: "Mountain Bluebird", percentage: 40, imageView: "bird_mountain_bluebird")
    ]

}

