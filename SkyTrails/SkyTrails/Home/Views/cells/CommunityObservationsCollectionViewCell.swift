//
//  q_4CommunityObservationsCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class CommunityObservationsCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "q_4CommunityObservationsCollectionViewCell"
        
        // MARK: - Outlets (Connect these from your XIB)
        @IBOutlet weak var cardContainerView: UIView!
        @IBOutlet weak var birdImageView: UIImageView!
        @IBOutlet weak var userProfileImageView: UIImageView!
        @IBOutlet weak var userNameLabel: UILabel!
        @IBOutlet weak var observationCountLabel: UILabel!
        @IBOutlet weak var birdNameLabel: UILabel!
        @IBOutlet weak var locationLabel: UILabel!
        

        private var gradientLayer: CAGradientLayer?
    
    override func awakeFromNib() {
        super.awakeFromNib()

        cardContainerView.layer.cornerRadius = 16
                cardContainerView.clipsToBounds = true
        
        birdImageView.contentMode = .scaleAspectFill
               birdImageView.clipsToBounds = true
                userProfileImageView.clipsToBounds = true
                userProfileImageView.contentMode = .scaleAspectFill
    }
    override func layoutSubviews() {
            super.layoutSubviews()
        
            applyGradientLayer()
            userProfileImageView.layer.cornerRadius = userProfileImageView.frame.height / 2
        }
    func configure(with observation: CommunityObservation, birdImage: UIImage?) {
            birdImageView.image = birdImage
        
            userNameLabel.text = observation.user.name
            userNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
            userNameLabel.textColor = .white
        
            observationCountLabel.text = "\(observation.user.observations) Observations"
            observationCountLabel.textColor = .white
            observationCountLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        
        
            birdNameLabel.text = observation.birdName
            birdNameLabel.textColor = .white
            birdNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        
        
            locationLabel.text = observation.location
            locationLabel.textColor = .white
        locationLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .medium)
        
            // 1. Try to load the user's custom profile image
            if let profileImage = UIImage(named: observation.user.profileImageName) {
                userProfileImageView.image = profileImage
            } else {
                userProfileImageView.image = UIImage(systemName: "person.circle.fill")
                userProfileImageView.tintColor = .systemGray4 
            }
             
            cardContainerView.bringSubviewToFront(userNameLabel)
            cardContainerView.bringSubviewToFront(observationCountLabel)
            cardContainerView.bringSubviewToFront(birdNameLabel)
            cardContainerView.bringSubviewToFront(locationLabel)
            cardContainerView.bringSubviewToFront(userProfileImageView) // Ensure
        }

        // MARK: - Gradient Logic
        
        private func applyGradientLayer() {
            gradientLayer?.removeFromSuperlayer()
            
            let gradient = CAGradientLayer()
            self.gradientLayer = gradient
            
            gradient.colors = [
                UIColor.black.withAlphaComponent(0.2).cgColor,
                UIColor.black.withAlphaComponent(0.7).cgColor
            ]
            
            gradient.locations = [0.5, 1.0]
            gradient.frame = birdImageView.bounds
            
            birdImageView.layer.insertSublayer(gradient, at: 0)
        }

}
