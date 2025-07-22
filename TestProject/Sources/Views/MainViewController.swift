import UIKit

class MainViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    private let userService = UserService()
    private let dataManager = DataManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        loadUsers()
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func loadUsers() {
        userService.fetchUsers { [weak self] users in
            DispatchQueue.main.async {
                self?.refreshTableView()
            }
        }
    }
    
    private func refreshTableView() {
        tableView.reloadData()
    }
}

extension MainViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userService.users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        let user = userService.users[indexPath.row]
        cell.textLabel?.text = user.name
        return cell
    }
}