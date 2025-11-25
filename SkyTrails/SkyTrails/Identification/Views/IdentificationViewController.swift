//
//  IdentificationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class IdentificationViewController: UIViewController, UITableViewDelegate,UITableViewDataSource {
    
    
    @IBOutlet weak var tableview: UITableView!
    
    var viewmodel: ViewModel = ViewModel()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Identification"
        self.navigationItem.largeTitleDisplayMode = .always
        tableview.delegate = self
        tableview.dataSource = self

        // Do any additional setup after loading the view.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewmodel.fieldMarkOptions.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
   func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
       let item = viewmodel.fieldMarkOptions[indexPath.row]
       cell.textLabel?.text = item.fieldMarkName
       cell.imageView?.image = UIImage(systemName: item.symbols.first!)
       cell.accessoryType = item.isSelected ? .checkmark: .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewmodel.fieldMarkOptions[indexPath.row].isSelected.toggle()
        tableView.reloadRows(at: [indexPath], with: .none)
        
        
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
