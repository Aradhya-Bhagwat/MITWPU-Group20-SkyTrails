import UIKit

final class EditProfileViewController: UIViewController {

    var onProfileUpdated: (() -> Void)?

    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let genderValueLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let contentStack = UIStackView()

    private var selectedGender: String = "Prefer not to say"

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureKeyboardDismissal()
        loadCurrentUser()
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Edit Profile"
        navigationController?.navigationBar.tintColor = .label

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentStack)

        contentStack.addArrangedSubview(makeFieldRow(title: "First Name", field: firstNameField, keyboardType: .default))
        contentStack.addArrangedSubview(makeFieldRow(title: "Last Name", field: lastNameField, keyboardType: .default))
        contentStack.addArrangedSubview(makeGenderRow())

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("Save Changes", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.backgroundColor = .systemBlue
        saveButton.layer.cornerRadius = 14
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            saveButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            saveButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func makeFieldRow(title: String, field: UITextField, keyboardType: UIKeyboardType) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 14
        container.heightAnchor.constraint(equalToConstant: 84).isActive = true

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel

        field.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .none
        field.keyboardType = keyboardType
        field.autocorrectionType = .no
        field.autocapitalizationType = keyboardType == .emailAddress ? .none : .words
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.clearButtonMode = .whileEditing

        container.addSubview(label)
        container.addSubview(field)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    private func makeGenderRow() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 14
        container.heightAnchor.constraint(equalToConstant: 84).isActive = true

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Gender"
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel

        genderValueLabel.translatesAutoresizingMaskIntoConstraints = false
        genderValueLabel.font = .preferredFont(forTextStyle: .body)
        genderValueLabel.adjustsFontForContentSizeCategory = true
        genderValueLabel.textColor = .label
        genderValueLabel.text = selectedGender

        let chevron = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = .secondaryLabel
        chevron.contentMode = .scaleAspectFit

        container.addSubview(label)
        container.addSubview(genderValueLabel)
        container.addSubview(chevron)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            genderValueLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            genderValueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            genderValueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            chevron.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: genderValueLabel.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14),
            
            genderValueLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8)
        ])

        container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(genderTapped)))
        container.isUserInteractionEnabled = true

        return container
    }

    private func loadCurrentUser() {
        guard let user = UserSession.shared.getUser() else { return }

        let parts = user.name.split(separator: " ").map(String.init)
        if parts.isEmpty {
            firstNameField.text = ""
            lastNameField.text = ""
        } else if parts.count == 1 {
            firstNameField.text = parts[0]
            lastNameField.text = ""
        } else {
            firstNameField.text = parts.first
            lastNameField.text = parts.dropFirst().joined(separator: " ")
        }
        
        selectedGender = user.gender.isEmpty ? "Prefer not to say" : user.gender
        genderValueLabel.text = selectedGender
    }

    private func configureKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func genderTapped() {
        dismissKeyboard()
        presentGenderChoice()
    }

    private func presentGenderChoice() {
        let sheet = UIAlertController(title: "Gender", message: nil, preferredStyle: .actionSheet)
        let options = ["Male", "Female", "Prefer not to say"]
        
        for option in options {
            let actionTitle = option == selectedGender ? "\(option) ✓" : option
            sheet.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                self?.selectedGender = option
                self?.genderValueLabel.text = option
            })
        }
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = genderValueLabel
            popover.sourceRect = genderValueLabel.bounds
        }
        
        present(sheet, animated: true)
    }

    @objc private func saveTapped() {
        dismissKeyboard()
        guard var user = UserSession.shared.getUser() else { return }

        let firstName = (firstNameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = (lastNameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !firstName.isEmpty else {
            showError("First name is required.")
            return
        }


        let fullName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        user.name = fullName
        user.gender = selectedGender
        
        UserSession.shared.saveUser(user)

        Task {
            try? await UserSyncService.shared.upsertUser(user)
            await MainActor.run {
                self.onProfileUpdated?()
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Edit Profile", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
