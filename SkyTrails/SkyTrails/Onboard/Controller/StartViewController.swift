
import UIKit

class StartViewController: UIViewController {

    @IBOutlet weak var segmentOutlet: UISegmentedControl!
    @IBOutlet weak var loginSegmentView: UIView!
    @IBOutlet weak var signupSegmentView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.bringSubviewToFront(signupSegmentView)
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {

        if sender.selectedSegmentIndex == 0 {
            view.bringSubviewToFront(signupSegmentView)
        } else {
            view.bringSubviewToFront(loginSegmentView)
        }
    }
}
