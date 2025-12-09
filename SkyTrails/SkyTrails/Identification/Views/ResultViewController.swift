//
//  ResultViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class ResultViewController: UIViewController,UITableViewDelegate, UITableViewDataSource,ResultCellDelegate{

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
//    func resize(_ image: UIImage, to size: CGSize) -> UIImage {
//        let renderer = UIGraphicsImageRenderer(size: size)
//        return renderer.image { _ in
//            image.draw(in: CGRect(origin: .zero, size: size))
//        }
//    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResultTableViewCell", for: indexPath) as! ResultTableViewCell
       
        let item = viewModel.birdResults[indexPath.row]
       
        let img = UIImage(named: item.imageView)

    cell.configure(image: img,
                   name: item.name,
                   percentage: "\(item.percentage)"
    )
    
        cell.delegate = self
        return cell
    }
  
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resultTableView.register(
            UINib(nibName: "ResultTableViewCell", bundle: nil),
            forCellReuseIdentifier: "ResultTableViewCell"
        )
        resultTableView.rowHeight = 75
        styleTableContainer()
        resultTableView.delegate = self
        resultTableView.dataSource = self
        resultTableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))


    }
    func didTapPredict(for cell: ResultTableViewCell) {
        print("Predict pressed")
    }

    func didTapAddToWatchlist(for cell: ResultTableViewCell) {
        print("Add to watchlist pressed")
    }

  

  
}

