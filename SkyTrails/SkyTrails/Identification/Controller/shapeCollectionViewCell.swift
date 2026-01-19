//
//  shapeCollectionViewCell.swift
//  SkyTrails
//
//  Created by Disha Jain on 18/01/26.
//

import UIKit

class shapeCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var shapeImageView: UIImageView!
    
    @IBOutlet weak var shapeNameLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    func configure(with shapeName: String, imageName: String) {
        shapeNameLabel.text = shapeName
        shapeImageView.image = UIImage(named: imageName) }

}
