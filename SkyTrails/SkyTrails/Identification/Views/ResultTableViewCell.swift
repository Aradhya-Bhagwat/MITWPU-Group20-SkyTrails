//
//  ResultTableViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit
protocol ResultCellDelegate: AnyObject {
    func didTapPredict(for cell: ResultTableViewCell)
    func didTapAddToWatchlist(for cell: ResultTableViewCell)
}

class ResultTableViewCell: UITableViewCell {

    @IBOutlet weak var resultImageView: UIImageView!
    
    @IBOutlet weak var nameLabel: UILabel!
    
    @IBOutlet weak var percentageLabel: UILabel!
    
    
    @IBOutlet weak var menuButton: UIButton!
    weak var delegate: ResultCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        resultImageView.layer.cornerRadius = 8
        resultImageView.clipsToBounds = true
        resultImageView.contentMode = .scaleAspectFill
        setupMenu()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
  
    func configure(image: UIImage?, name: String, percentage: String) {
          resultImageView.image = image
          nameLabel.text = name
          percentageLabel.text = percentage + "%"
          percentageLabel.numberOfLines = 1
         
      }
    func configureHistory(image: UIImage?, name: String, date: String) {
        resultImageView.image = image
        nameLabel.text = name
        percentageLabel.text = date   
    }
    func setupMenu() {
        let predictAction = UIAction(title: "Predict Species",
                                     image: UIImage(systemName: "map")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didTapPredict(for: self)
        }


        let watchlistAction = UIAction(title: "Add to Watchlist",
                                       image: UIImage(systemName: "text.badge.plus")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didTapAddToWatchlist(for: self)
        }

        let menu = UIMenu(title: "", children: [predictAction, watchlistAction])

        menuButton.showsMenuAsPrimaryAction = true   // open menu on tap
        menuButton.menu = menu
    }
    }
