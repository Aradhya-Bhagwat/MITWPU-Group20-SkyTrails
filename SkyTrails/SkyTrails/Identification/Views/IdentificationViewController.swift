//
//  IdentificationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class IdentificationViewController: UIViewController, UITableViewDelegate,UITableViewDataSource,UICollectionViewDataSource,UICollectionViewDelegate{
 
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var tableview: UITableView!
    @IBOutlet weak var collectionview: UICollectionView!
    
    var viewmodel: ViewModel = ViewModel()
    var history: [History] = []
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return history.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "history_cell", for: indexPath)
        
        guard let historyCell = cell as? historyCollectionViewCell else {
            return cell
        }
        let historyItems = history[indexPath.row]
        historyCell.configureCell(historyItem: historyItems)

        historyCell.layer.backgroundColor = UIColor.white.cgColor
        historyCell.layer.cornerRadius = 12
        historyCell.layer.shadowColor = UIColor.black.cgColor
        historyCell.layer.shadowOpacity = 0.1
        historyCell.layer.shadowOffset = CGSize(width: 0, height: 2)
        historyCell.layer.shadowRadius = 8
        historyCell.layer.masksToBounds = false
        
        return historyCell
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // No color changes here to avoid flash on tab switch
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Apply shadow after the button has its final frame for correct corner radius
        applyCardShadow(to: startButton)
        // Optional: provide a shadowPath to prevent shadow layout changes
        startButton.layer.shadowPath = UIBezierPath(roundedRect: startButton.bounds, cornerRadius: 12).cgPath
    }
    override func viewDidLoad() {
        super.viewDidLoad()
       
        self.title = "Identification"
        self.navigationItem.largeTitleDisplayMode = .always
      
        tableview.delegate = self
        tableview.dataSource = self
        
        // Set button visual appearance early to avoid blue flash
        startButton.backgroundColor = .white
        startButton.setTitleColor(.black, for: .normal)
        startButton.tintColor = .white // prevents default blue tint on system button images/text
        startButton.adjustsImageWhenHighlighted = false
        
        // Optional: set a consistent row height to fit your image
        tableview.rowHeight = 56
    
        applyCardShadow(to: tableview)

        let layout = generateLayout()
        collectionview.setCollectionViewLayout(layout, animated: true)
        collectionview.dataSource = self
        collectionview.delegate = self
        history = viewmodel.migrationHistory
        collectionview.reloadData()
    }
    func applyCardShadow(to view: UIView) {
        // Shadow and corner radius
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.masksToBounds = false
        // Background color
        view.layer.backgroundColor = UIColor.white.cgColor
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewmodel.fieldMarkOptions.count
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
       
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = viewmodel.fieldMarkOptions[indexPath.row]
        cell.textLabel?.text = item.fieldMarkName
        
        if let img = UIImage(named: item.symbols) {
    
            let targetSize = CGSize(width: 28, height: 28)
            let resized = resize(img, to: targetSize)
            cell.imageView?.image = resized
            cell.imageView?.contentMode = .scaleAspectFit
            cell.imageView?.frame = CGRect(origin: .zero, size: targetSize)
        } else {
            cell.imageView?.image = nil
        }
        
        cell.accessoryType = item.isSelected ? .checkmark: .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewmodel.fieldMarkOptions[indexPath.row].isSelected.toggle()
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    func generateLayout() -> UICollectionViewLayout {
        let size  = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(200))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .fixed(10)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 20
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
}
