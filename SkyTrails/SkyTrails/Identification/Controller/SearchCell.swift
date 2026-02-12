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
        setupTraitChangeHandling()
        searchBar.backgroundImage = UIImage()
        searchBar.placeholder = "Search for a location"
        applySemanticAppearance()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }

    private func applySemanticAppearance() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        searchBar.tintColor = .systemBlue
        searchBar.searchTextField.textColor = .label
        searchBar.searchTextField.backgroundColor = .tertiarySystemBackground
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search for a location",
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
    }

}
