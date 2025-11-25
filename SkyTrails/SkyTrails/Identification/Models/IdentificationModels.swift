//
//  Models.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//
import Foundation
struct History{
    var imageView : String
    var timeSymbol : String
    var specieName : String
    var time : Date
}


struct FieldMarkType{
    var symbols : [String]
    var fieldMarkName : String
    var isSelected: Bool = false
}
struct BirdShape{
    var ImageView : [String]
    var Name : String
}
struct ChooseFieldMark{
    var ImageView : [String]
    var Name : String
    var isSelected: Bool = false
}
struct result{
    var ImageView : String
    
}
