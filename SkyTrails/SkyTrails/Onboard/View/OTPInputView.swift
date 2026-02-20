import UIKit

class OTPInputView: UIView {
    private let stackView = UIStackView()
    private let numberOfDigits = 6
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
        stackView.spacing = 32 // Increased spacing for better separation
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor)
        ])
        
        for i in 0..<numberOfDigits {
            let textField = createTextField(tag: i)
            textFields.append(textField)
            stackView.addArrangedSubview(textField)
            
            // Upright aspect ratio (width is 80% of height)
            textField.widthAnchor.constraint(equalTo: textField.heightAnchor, multiplier: 1).isActive = true
        }
    }
    
    private func createTextField(tag: Int) -> UITextField {
        let field = UITextField()
        field.tag = tag
        field.textAlignment = .center
        field.font = .boldSystemFont(ofSize: 24)
        field.borderStyle = .roundedRect
        field.keyboardType = .numberPad
        field.backgroundColor = .systemGray6
        field.delegate = self
        field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        return field
    }
    
    @objc private func textChanged(_ textField: UITextField) {
        let text = textField.text ?? ""
        
        if text.count >= 1 {
            textField.text = String(text.prefix(1))
            let nextTag = textField.tag + 1
            if nextTag < numberOfDigits {
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
}

extension OTPInputView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty { // Backspace
            if textField.text?.isEmpty == true {
                let prevTag = textField.tag - 1
                if prevTag >= 0 {
                    textFields[prevTag].text = ""
                    textFields[prevTag].becomeFirstResponder()
                }
            } else {
                textField.text = ""
            }
            onOTPEntered?(self.text)
            return false
        }
        return true
    }
}
