import UIKit

final class EditProfileViewController: UIViewController {

    var onProfileUpdated: (() -> Void)?

    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let saveButton = UIButton(type: .system)
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
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
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabel

        field.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .none
        field.keyboardType = keyboardType
        field.autocorrectionType = .no
        field.autocapitalizationType = keyboardType == .emailAddress ? .none : .words
        field.font = .systemFont(ofSize: 17, weight: .regular)
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
    }

    @objc private func saveTapped() {
        guard var user = UserSession.shared.getUser() else { return }

        let firstName = (firstNameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = (lastNameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !firstName.isEmpty else {
            showError("First name is required.")
            return
        }


        let fullName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        user.name = fullName
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
