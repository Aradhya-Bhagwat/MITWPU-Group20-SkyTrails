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
        searchBar.backgroundImage = UIImage()
        searchBar.placeholder = "Search for a location"
        applySemanticAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
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
