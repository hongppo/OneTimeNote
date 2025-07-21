import Foundation

class DataManager {
    private let userDefaults = UserDefaults.standard
    private let notebooksKey = "onetimenode_notebooks_mvp"
    
    func saveNotebooks(_ notebooks: [Notebook]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(notebooks)
            userDefaults.set(data, forKey: notebooksKey)
        } catch {
            print("Failed to save notebooks: \(error)")
        }
    }
    
    func loadNotebooks() -> [Notebook] {
        guard let data = userDefaults.data(forKey: notebooksKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Notebook].self, from: data)
        } catch {
            print("Failed to load notebooks: \(error)")
            return []
        }
    }
}
