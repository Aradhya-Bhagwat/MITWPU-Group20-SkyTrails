//
//  ShapeViewController.swift
//  SkyTrails
//
//  Created by Disha Jain on 27/11/25.
//

import UIKit

class IdentificationShapeViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    
    
    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var shapeTableView: UITableView!
    
    @IBOutlet weak var progressView: UIProgressView!

    var viewModel: ViewModel = ViewModel()
    var selectedSizeIndex: Int?
    var filteredShapes: [BirdShape] = []

    weak var delegate: IdentificationFlowStepDelegate?

    func styleTableContainer() {
        tableContainerView.backgroundColor = .white
        tableContainerView.layer.cornerRadius = 12
        tableContainerView.layer.shadowColor = UIColor.black.cgColor
        tableContainerView.layer.shadowOpacity = 0.1
        tableContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        tableContainerView.layer.shadowRadius = 8
        tableContainerView.layer.masksToBounds = false
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredShapes.count
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedShape = filteredShapes[indexPath.row]
         viewModel.data.shape = selectedShape.name
        delegate?.didTapShapes()

    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "shape_cell", for: indexPath)
        let item = filteredShapes[indexPath.row]
        cell.textLabel?.text = item.name
        if let img = UIImage(named: item.imageView) {
    
            let targetSize = CGSize(width: 60, height: 60)
            let resized = resize(img, to: targetSize)
            cell.imageView?.image = resized
            cell.imageView?.contentMode = .scaleAspectFill
            cell.imageView?.frame = CGRect(origin: .zero, size: targetSize)
        } else {
            cell.imageView?.image = nil
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        styleTableContainer()
        applySizeFilter()
        shapeTableView.delegate = self
        shapeTableView.dataSource = self


    }
   
    func applySizeFilter() {
        guard let sizeIndex = selectedSizeIndex else {
            filteredShapes = viewModel.birdShapes
            return
        }

        filteredShapes = viewModel.birdShapes.filter { shape in
            shape.sizeCategory?.contains(sizeIndex) ?? false
        }
    }

  

   

}
extension IdentificationShapeViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
