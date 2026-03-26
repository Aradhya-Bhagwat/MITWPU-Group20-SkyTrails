import UIKit

private final class OTPDigitTextField: UITextField {
    var onDeleteBackward: (() -> Void)?

    override func deleteBackward() {
        onDeleteBackward?()
        super.deleteBackward()
    }
}

class OTPInputView: UIView {
    private let stackView = UIStackView()
    var digitCount: Int = 8 {
        didSet {
            let bounded = max(4, min(10, digitCount))
            if bounded != digitCount {
                digitCount = bounded
                return
            }
            rebuildFields()
        }
    }
    private var textFields: [UITextField] = []
    
    var onOTPEntered: ((String) -> Void)?
    
    var text: String {
        return textFields.compactMap { $0.text }.joined()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 18
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor)
        ])

        rebuildFields()
    }

    private func rebuildFields() {
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        textFields.removeAll()

        for i in 0..<digitCount {
            let textField = createTextField(tag: i)
            textFields.append(textField)
            stackView.addArrangedSubview(textField)

            textField.widthAnchor.constraint(equalTo: textField.heightAnchor, multiplier: 1).isActive = true
        }
    }
    
    private func createTextField(tag: Int) -> UITextField {
        let field = OTPDigitTextField()
        field.tag = tag
        field.textAlignment = .center
        field.font = .boldSystemFont(ofSize: 24)
        field.borderStyle = .roundedRect
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.backgroundColor = .systemGray6
        field.delegate = self
        field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        field.onDeleteBackward = { [weak self, weak field] in
            guard let self, let field else { return }
            self.handleDeleteBackward(in: field)
        }
        return field
    }
    
    @objc private func textChanged(_ textField: UITextField) {
        let text = textField.text ?? ""
        
        if text.count > 1 {
            textField.text = String(text.suffix(1))
        }

        if text.count == 1 {
            let nextTag = textField.tag + 1
            if nextTag < digitCount {
                textFields[nextTag].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
        
        onOTPEntered?(self.text)
    }
    
    func clear() {
        textFields.forEach { $0.text = "" }
        textFields.first?.becomeFirstResponder()
    }

    private func handleDeleteBackward(in textField: UITextField) {
        guard textField.text?.isEmpty == true else { return }

        let previousTag = textField.tag - 1
        guard previousTag >= 0 else {
            onOTPEntered?(self.text)
            return
        }

        let previousField = textFields[previousTag]
        previousField.text = ""
        previousField.becomeFirstResponder()
        onOTPEntered?(self.text)
    }
}

extension OTPInputView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if !string.isEmpty && string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
            return false
        }

        if string.count > 1 {
            applyPastedCode(string, startingAt: textField.tag)
            return false
        }

        if string.isEmpty {
            return true
        }
        return true
    }

    private func applyPastedCode(_ raw: String, startingAt startIndex: Int) {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return }

        var index = startIndex
        for char in digits where index < digitCount {
            textFields[index].text = String(char)
            index += 1
        }

        if index < digitCount {
            textFields[index].becomeFirstResponder()
        } else {
            textFields[digitCount - 1].resignFirstResponder()
        }

        onOTPEntered?(self.text)
    }
}
