//
//  FieldMarksViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class IdentificationFieldMarksViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {

    
    @IBOutlet weak var tableContainerView: UIView!
    
    @IBOutlet weak var fieldMarkTableView: UITableView!
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
        viewModel.fieldMarks.count
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
    @objc func switchChanged(_ sender: UISwitch) {
        print("Row \(sender.tag), isOn = \(sender.isOn)")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fieldmark_cell", for: indexPath)
        let item = viewModel.fieldMarks[indexPath.row]
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
        let toggle = UISwitch()
        toggle.isOn = true
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        cell.selectionStyle = .none
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        styleTableContainer()
        fieldMarkTableView.delegate = self
        fieldMarkTableView.dataSource = self

    }
    
   

}
