import Foundation

public struct UserProfile {
    public var bio: String
    public var avatarURL: URL?
    public var location: String?
    public var website: URL?
    
    public init(bio: String = "", avatarURL: URL? = nil, location: String? = nil, website: URL? = nil) {
        self.bio = bio
        self.avatarURL = avatarURL
        self.location = location
        self.website = website
    }
}