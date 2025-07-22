import Foundation

class DataManager {
    private let userDefaults = UserDefaults.standard
    
    func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            userDefaults.set(data, forKey: "user_\(user.id)")
        }
    }
    
    func loadUser(id: UUID) -> User? {
        guard let data = userDefaults.data(forKey: "user_\(id)"),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }
    
    func deleteUser(id: UUID) {
        userDefaults.removeObject(forKey: "user_\(id)")
    }
}