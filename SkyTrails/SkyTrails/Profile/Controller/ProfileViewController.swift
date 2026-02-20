//
//  ProfileViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/02/26.
//

import UIKit

class ProfileViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailButton: UIButton!   // 👈 UIButton now

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadUser()
    }

    // MARK: - UI Setup

    private func setupUI() {

        profileImageView.layer.cornerRadius =
            profileImageView.frame.width / 2

        profileImageView.clipsToBounds = true
    }

    // MARK: - Load User Data

    private func loadUser() {

        guard let user = UserSession.shared.getUser() else {

            logout()
            return
        }

        nameLabel.text = user.name

        emailButton.setTitle(user.email, for: .normal)

        if user.profilePhoto.starts(with: "http") {

            loadImage(from: user.profilePhoto)

        } else {

            profileImageView.image =
                UIImage(named: user.profilePhoto)
        }
    }

    // MARK: - Logout

    @IBAction func logoutTapped(_ sender: UIButton) {
        logout()
    }

    private func logout() {
        if let accessToken = UserSession.shared.getAccessToken() {
            Task {
                try? await SupabaseAuthService.shared.signOut(accessToken: accessToken)
            }
        }

        UserSession.shared.logout()
        goToLogin()
    }

    // MARK: - Navigation

    private func goToLogin() {

        guard let scene =
                UIApplication.shared.connectedScenes.first
                    as? UIWindowScene,
              let window =
                scene.windows.first(where: { $0.isKeyWindow })
        else { return }

        let storyboard = UIStoryboard(name: "Onboard", bundle: nil)

        let startVC = storyboard.instantiateViewController(
            withIdentifier: "StartViewController"
        )

        window.rootViewController = startVC

        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionFlipFromLeft,
            animations: nil
        )
    }
    
    private func loadImage(from urlString: String) {

        guard let url = URL(string: urlString) else { return }

        DispatchQueue.global().async {

            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {

                DispatchQueue.main.async {
                    self.profileImageView.image = image
                }
            }
        }
    }
}
