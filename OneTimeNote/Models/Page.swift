import Foundation

struct Page: Identifiable, Codable, Equatable {
    let id: UUID
    var pageNumber: Int
    var content: String
    var isTorn: Bool
    var isLocked: Bool
    var createdAt: Date
    var lastModified: Date
    
    static let maxCharacters = 500
    
    init(pageNumber: Int) {
        self.id = UUID()
        self.pageNumber = pageNumber
        self.content = ""
        self.isTorn = false
        self.isLocked = false
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    var state: PageState {
        if isTorn { return .torn }
        if content.count > 0 && isLocked { return .completed }
        if content.count > 0 { return .writing }
        return .empty
    }
    
    var isUsed: Bool {
        content.count > 0 || isTorn
    }
    
    var canEdit: Bool {
        !isTorn && !isLocked
    }
    
    var remainingCharacters: Int {
        Self.maxCharacters - content.count
    }
    
    mutating func updateContent(_ text: String) -> Bool {
        guard canEdit && text.count <= Self.maxCharacters else { return false }
        content = text
        lastModified = Date()
        return true
    }
    
    mutating func lock() {
        if content.count > 0 {
            isLocked = true
        }
    }
    
    mutating func tear() -> Bool {
        guard !isTorn && content.count > 0 else { return false }
        isTorn = true
        content = ""
        isLocked = true
        return true
    }
}
