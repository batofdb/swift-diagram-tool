import UIKit
import Foundation

// Test UIKit View Controller inheritance
class ProfileViewController: UIViewController {
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Setup code
    }
}

class CustomNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        customizeAppearance()
    }
    
    private func customizeAppearance() {
        // Custom navigation appearance
    }
}

// Test UIKit View hierarchy
class CustomScrollView: UIScrollView {
    private let contentView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScrollView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollView()
    }
    
    private func setupScrollView() {
        addSubview(contentView)
    }
}

class CustomTableView: UITableView {
    private var dataSource: [String] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTableView()
    }
    
    private func setupTableView() {
        delegate = self as? UITableViewDelegate
        dataSource = self as? UITableViewDataSource
    }
}

// Test UIKit Control hierarchy
class CustomButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        layer.cornerRadius = 8
        backgroundColor = .systemBlue
    }
}

class CustomTextField: UITextField {
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 16, dy: 8)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 16, dy: 8)
    }
}

// Test complex UIKit relationships
class MainViewController: UIViewController {
    private let customScrollView = CustomScrollView()
    private let customTableView = CustomTableView()
    private let customButton = CustomButton()
    private let customTextField = CustomTextField()
    
    // Properties that should create phantom node relationships
    private var window: UIWindow?
    private var navigationController: UINavigationController?
    private var tabBarController: UITabBarController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    private func setupViews() {
        view.addSubview(customScrollView)
        view.addSubview(customTableView)
        view.addSubview(customButton)
        view.addSubview(customTextField)
    }
}

// Test Foundation inheritance mixed with UIKit
class DataManager: NSObject {
    private var urlSession: URLSession = .shared
    private var fileManager: FileManager = .default
    
    func fetchData() async -> Data? {
        // Implementation
        return nil
    }
}

// Test Core Data integration
class CoreDataManager: NSObject {
    lazy var persistentContainer: NSPersistentContainer = {
        // Implementation
        return NSPersistentContainer(name: "Model")
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
}