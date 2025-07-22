import UIKit

class SimpleViewController: UIViewController {
    var userService: UserService
    var dataManager: DataManager
    
    init(userService: UserService, dataManager: DataManager) {
        self.userService = userService
        self.dataManager = dataManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}