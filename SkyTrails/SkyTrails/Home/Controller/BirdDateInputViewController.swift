//
//  BirdDateInputViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

struct BirdDateInput {
    let species: SpeciesData
    var startDate: Date?
    var endDate: Date?
}

struct SpeciesData {
    let id: String
    let name: String
    let imageName: String
}

class BirdDateInputViewController: UIViewController {
    
    var speciesList: [SpeciesData] = []
    var collectedData: [BirdDateInput] = []
    var currentIndex: Int = 0
    
    private let imageView = UIImageView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let pageControl = UIPageControl()
    private let containerView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        
        setupNavigationBar()
        setupUI()
        loadCurrentBird()
    }
    
    private func setupNavigationBar() {
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAdd))
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
        doneButton.tintColor = .white
        let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(didTapDelete))
        navigationItem.rightBarButtonItems = [doneButton, addButton, deleteButton]
        deleteButton.tintColor = .systemRed
    }
    
    private func setupUI() {
      
        view.addSubview(containerView)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .systemGray
        
        containerView.addSubview(imageView)
        containerView.addSubview(tableView)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DateCell")
        tableView.isScrollEnabled = false
        
        pageControl.numberOfPages = collectedData.count
        pageControl.currentPage = currentIndex
        pageControl.pageIndicatorTintColor = .systemGray4
        pageControl.currentPageIndicatorTintColor = .black
        pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        view.addSubview(pageControl)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let safeAreaTop = view.safeAreaInsets.top
        let viewWidth = view.bounds.width
        let viewHeight = view.bounds.height
        let pageControlHeight: CGFloat = 50
        pageControl.frame = CGRect(
            x: 0,
            y: viewHeight - pageControlHeight - view.safeAreaInsets.bottom - 20,
            width: viewWidth,
            height: pageControlHeight
        )
        
        let containerViewY = safeAreaTop + 20
        let containerViewHeight = pageControl.frame.minY - containerViewY - 30 
        containerView.frame = CGRect(
            x: 0,
            y: containerViewY,
            width: viewWidth,
            height: containerViewHeight
        )
        
        let imageViewWidth: CGFloat = 240
        let imageViewHeight: CGFloat = 160
        imageView.frame = CGRect(
            x: (containerView.bounds.width - imageViewWidth) / 2,
            y: 0,
            width: imageViewWidth,
            height: imageViewHeight
        )
        
        let tableViewY = imageView.frame.maxY + 30
        tableView.frame = CGRect(
            x: 0,
            y: tableViewY,
            width: containerView.bounds.width,
            height: containerView.bounds.height - tableViewY
        )
    }
    
    private func loadCurrentBird() {
        guard currentIndex < collectedData.count else { return }
        let data = collectedData[currentIndex]
        
        self.title = data.species.name
        imageView.image = UIImage(named: data.species.imageName)
        
        pageControl.numberOfPages = collectedData.count
        pageControl.currentPage = currentIndex
        
        tableView.reloadData()
    }
    
    @objc private func didTapAdd() {
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        guard let selectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController else { return }
        selectionVC.selectedSpecies = Set(collectedData.map { $0.species.id })
        selectionVC.existingInputs = collectedData
        
        navigationController?.pushViewController(selectionVC, animated: true)
    }
    
    @objc private func didTapDone() {
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        guard let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController else { return }
        
        mapVC.predictionInputs = collectedData
        
        navigationController?.pushViewController(mapVC, animated: true)
    }
    
    @objc private func didTapDelete() {
        guard currentIndex < collectedData.count else { return }
        
        collectedData.remove(at: currentIndex)
        
        if collectedData.isEmpty {
            navigationController?.popViewController(animated: true)
        } else {
            if currentIndex >= collectedData.count {
                currentIndex = collectedData.count - 1
            }
            loadCurrentBird()
        }
    }
    
    @objc private func pageControlChanged(_ sender: UIPageControl) {
        let previousIndex = currentIndex
        currentIndex = sender.currentPage
        
        let transition = CATransition()
        transition.type = .push
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.duration = 0.3
        
        if currentIndex > previousIndex {
            transition.subtype = .fromRight
        } else {
            transition.subtype = .fromLeft
        }
        
        containerView.layer.add(transition, forKey: nil)
        loadCurrentBird()
    }
    
    @objc private func startDateChanged(_ sender: UIDatePicker) {
        if currentIndex < collectedData.count {
            collectedData[currentIndex].startDate = sender.date
        }
    }
    
    @objc private func endDateChanged(_ sender: UIDatePicker) {
        if currentIndex < collectedData.count {
            collectedData[currentIndex].endDate = sender.date
        }
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        let previousIndex = currentIndex
        
        if gesture.direction == .left {
            if currentIndex < collectedData.count - 1 {
                currentIndex += 1
            }
        } else if gesture.direction == .right {
            if currentIndex > 0 {
                currentIndex -= 1
            }
        }
        
        if currentIndex != previousIndex {
            let transition = CATransition()
            transition.type = .push
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            transition.duration = 0.3
            
            if currentIndex > previousIndex {
                transition.subtype = .fromRight
            } else {
                transition.subtype = .fromLeft
            }
            
            containerView.layer.add(transition, forKey: nil)
            loadCurrentBird()
        }
    }

}

extension BirdDateInputViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "DateCell")
        cell.selectionStyle = .none
        
        guard currentIndex < collectedData.count else { return cell }
        let data = collectedData[currentIndex]
        
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        
        if indexPath.row == 0 {
            cell.textLabel?.text = "Start Date"
            datePicker.date = data.startDate ?? Date()
            datePicker.addTarget(self, action: #selector(startDateChanged(_:)), for: .valueChanged)
        } else {
            cell.textLabel?.text = "End Date"
            datePicker.date = data.endDate ?? Date()
            datePicker.addTarget(self, action: #selector(endDateChanged(_:)), for: .valueChanged)
        }

        cell.accessoryView = datePicker
        
        return cell
    }
}
