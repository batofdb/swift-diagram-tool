import Foundation

class UserService {
    private(set) var users: [User] = []
    private let networkManager = NetworkManager()
    
    func fetchUsers(completion: @escaping ([User]) -> Void) {
        networkManager.request(endpoint: "/users") { [weak self] result in
            switch result {
            case .success(let data):
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    self?.users = users
                    completion(users)
                } catch {
                    print("Failed to decode users: \(error)")
                    completion([])
                }
            case .failure(let error):
                print("Network error: \(error)")
                completion([])
            }
        }
    }
    
    func addUser(_ user: User) {
        users.append(user)
    }
}

class NetworkManager {
    func request(endpoint: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // Simulate network request
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(.success(Data()))
        }
    }
}