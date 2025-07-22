import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let name: String
    let email: String
    let profile: UserProfile?
    
    init(name: String, email: String, profile: UserProfile? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.profile = profile
    }
}

struct UserProfile: Codable {
    let bio: String
    let avatarURL: URL?
    let location: String?
}