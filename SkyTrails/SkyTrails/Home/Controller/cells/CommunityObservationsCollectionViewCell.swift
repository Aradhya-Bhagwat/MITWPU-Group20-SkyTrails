//
//  q_4CommunityObservationsCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class CommunityObservationsCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "CommunityObservationsCollectionViewCell"
        
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
        
        }
    
    override func layoutSubviews() {
            super.layoutSubviews()
        
            applyGradientLayer()
            userProfileImageView.layer.cornerRadius = userProfileImageView.frame.height / 2
        }
    
    func configure(with observation: CommunityObservation, birdImage: UIImage?) {
        
            let displayUser = observation.displayUser
            birdImageView.image = birdImage
            birdImageView.tintColor = .systemGray4
        
            userNameLabel.text = displayUser.name
            userNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
            userNameLabel.textColor = .white
        
            observationCountLabel.text = "\(displayUser.observations) Observations"
            observationCountLabel.textColor = .white
            observationCountLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        
            birdNameLabel.text = observation.displayBirdName
            birdNameLabel.textColor = .white
            birdNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        
            locationLabel.text = observation.location
            locationLabel.textColor = .white
            locationLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .medium)
        
            if let profileImage = UIImage(named: displayUser.profileImageName) {
                userProfileImageView.image = profileImage
            } else {
                userProfileImageView.image = UIImage(systemName: "person.circle.fill")
                userProfileImageView.tintColor = .systemGray4
               
            }
             
            cardContainerView.bringSubviewToFront(userNameLabel)
            cardContainerView.bringSubviewToFront(observationCountLabel)
            cardContainerView.bringSubviewToFront(birdNameLabel)
            cardContainerView.bringSubviewToFront(locationLabel)
            cardContainerView.bringSubviewToFront(userProfileImageView) 
        }
        
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
