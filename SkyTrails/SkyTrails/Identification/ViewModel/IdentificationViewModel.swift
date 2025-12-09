import Foundation

class ViewModel {
    var selectedSizeCategory: Int?

    private var model = IdentificationModels()

    init() {
        print("📌 ViewModel initialized")
    }
   

    var histories: [History] {
        get { model.histories }
        set { model.histories = newValue }
    }

    var fieldMarkOptions: [FieldMarkType] {
        get { model.fieldMarkOptions }
        set { model.fieldMarkOptions = newValue }
    }

    var birdShapes: [BirdShape] {
        get { model.birdShapes }
        set { model.birdShapes = newValue }
    }

    var fieldMarks: [ChooseFieldMark] {
        get { model.chooseFieldMarks }
        set { model.chooseFieldMarks = newValue }
    }

    var birdResults: [BirdResult] {
        get { model.birdResults }
        set { model.birdResults = newValue }
    }
}

