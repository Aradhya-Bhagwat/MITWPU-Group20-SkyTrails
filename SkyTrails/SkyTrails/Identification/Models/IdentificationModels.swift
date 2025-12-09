//
//  Models.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import Foundation

struct History: Codable {
    var imageView: String
    var specieName: String
    var date: String
}


struct FieldMarkType: Codable {
    var symbols: String
    var fieldMarkName: String
    var isSelected: Bool? = false
}


struct BirdShape: Codable {
    var imageView: String
    var name: String
    var sizeCategory: [Int]? = nil
}


struct ChooseFieldMark: Codable {
    var imageView: String
    var name: String
    var isSelected: Bool? = false  // JSON may omit it
}



struct ResultModel: Codable {
    var imageView: String
}



struct BirdResult: Codable {
    let name: String
    let percentage: Int
    let imageView: String
}




struct IdentificationModels: Codable {

    var histories: [History] = []
    var fieldMarkOptions: [FieldMarkType] = []
    var birdShapes: [BirdShape] = []
    var chooseFieldMarks: [ChooseFieldMark] = []
    var birdResults: [BirdResult] = []

    init() {
        do {
            let response = try load()

            print("✅ JSON LOADED SUCCESSFULLY")

            histories = response.histories
            fieldMarkOptions = response.fieldMarkOptions
            birdShapes = response.birdShapes
            chooseFieldMarks = response.chooseFieldMarks
            birdResults = response.birdResults

        } catch {
            print("❌ IDENTIFICATION JSON LOAD FAILED:", error)
        }
    }

    

    enum CodingKeys: String, CodingKey {
        case histories = "histories"
        case fieldMarkOptions = "field_mark_options"
        case birdShapes = "bird_shapes"
        case chooseFieldMarks = "field_marks"
        case birdResults = "bird_results"
    }
}


extension IdentificationModels {

    func load(from filename: String = "identification_data") throws -> IdentificationModels {

        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
 
            throw NSError(domain: "IdentificationModels",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "\(filename).json not found"])
        }


        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        return try decoder.decode(IdentificationModels.self, from: data)
    }
}

