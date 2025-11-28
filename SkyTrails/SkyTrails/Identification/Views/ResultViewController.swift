//
//  ResultViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class ResultViewController: UIViewController,UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var resultTableView: UITableView!
    var viewModel: ViewModel = ViewModel()

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
        viewModel.birdResults.count
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
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "result_cell", for: indexPath)
        let item = viewModel.birdResults[indexPath.row]
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = "\(item.percentage)%"
         cell.detailTextLabel?.textColor = .gray
         cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)
        if let img = UIImage(named: item.imageView) {
    
            let targetSize = CGSize(width: 100, height: 100)
            let resized = resize(img, to: targetSize)
            cell.imageView?.image = resized
            cell.imageView?.contentMode = .scaleAspectFill
            cell.imageView?.frame = CGRect(origin: .zero, size: targetSize)
            cell.imageView?.layer.cornerRadius = 10
        } else {
            cell.imageView?.image = nil
        }
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        styleTableContainer()
        resultTableView.delegate = self
        resultTableView.dataSource = self

    }
   

  
}
