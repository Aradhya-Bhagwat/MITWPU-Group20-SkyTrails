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
    var viewModel: ViewModel!
    weak var delegate: IdentificationFlowStepDelegate?
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
        setupLeftResetButton()
        setupRightTickButton()

    }
    private func setupRightTickButton() {
        // Create button
        let button = UIButton(type: .system)
        
        // Circle background
        button.backgroundColor = .white
        button.layer.cornerRadius = 20   // for 40x40 size

        button.layer.masksToBounds = true   // important to remove rectangle
        
        // Checkmark icon
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = UIImage(systemName: "checkmark", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .black

        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Add tap action
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // Put inside UIBarButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }
    private func setupLeftResetButton() {
        // Create button
        let button = UIButton(type: .system)
        
        // Circle background
        button.backgroundColor = .white
        button.layer.cornerRadius = 20   // for 40x40 size

        button.layer.masksToBounds = true   // important to remove rectangle
        
        // Checkmark icon
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = UIImage(systemName: "arrow.trianglehead.counterclockwise", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .black

        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Add tap action
        button.addTarget(self, action: #selector(restartTapped), for: .touchUpInside)

        // Put inside UIBarButtonItem
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
    }

    @objc private func nextTapped() {
        delegate?.didFinishStep()
            }
    @objc private func restartTapped() {
        delegate?.didTapLeftButton()
            }
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
  
  
    func didTapPredict(for cell: ResultTableViewCell) {
        print("Predict pressed")
    }

    func didTapAddToWatchlist(for cell: ResultTableViewCell) {
        print("Add to watchlist pressed")
    }

  

  
}

