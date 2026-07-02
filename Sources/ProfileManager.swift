import Foundation

class ProfileManager {
    static let shared = ProfileManager()
    private let profilesKey = "v2raybox_profiles"
    
    var profiles: [Profile] = []
    
    private init() {
        loadProfiles()
    }
    
    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        saveProfiles()
    }
    
    func removeProfile(at index: Int) {
        guard index >= 0 && index < profiles.count else { return }
        profiles.remove(at: index)
        saveProfiles()
    }
    
    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: profilesKey) {
            do {
                profiles = try JSONDecoder().decode([Profile].self, from: data)
            } catch {
                print("Failed to decode profiles: \(error)")
            }
        }
    }
    
    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            UserDefaults.standard.set(data, forKey: profilesKey)
        } catch {
            print("Failed to encode profiles: \(error)")
        }
    }
}
