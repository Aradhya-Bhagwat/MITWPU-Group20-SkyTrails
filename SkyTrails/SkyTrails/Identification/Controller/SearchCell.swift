//
//  SearchCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class SearchCell: UITableViewCell, UISearchBarDelegate {
    @IBOutlet weak var searchBar: UISearchBar!


    override func awakeFromNib() {
        super.awakeFromNib()
        searchBar.backgroundImage = UIImage() // Remove default borders if needed
        searchBar.placeholder = "Search for a location"
    }


}

