import Foundation

struct Notebook: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var pages: [Page]
    var createdAt: Date
    var isDefault: Bool
    var currentPageIndex: Int
    
    init(name: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.pages = (1...50).map { Page(pageNumber: $0) }
        self.createdAt = Date()
        self.isDefault = isDefault
        self.currentPageIndex = 0
    }
    
    var currentPage: Page {
        pages[currentPageIndex]
    }
    
    var usedPagesCount: Int {
        pages.filter { $0.content.count > 0 && !$0.isTorn }.count
    }
    
    var tornPagesCount: Int {
        pages.filter { $0.isTorn }.count
    }
    
    mutating func updateCurrentPageContent(_ content: String) -> Bool {
        return pages[currentPageIndex].updateContent(content)
    }
    
    mutating func lockCurrentPage() {
        pages[currentPageIndex].lock()
    }
    
    mutating func tearCurrentPage() -> Bool {
        return pages[currentPageIndex].tear()
    }
    
    func getNextAvailablePageIndex() -> Int? {
        for (index, page) in pages.enumerated() {
            if !page.isTorn {
                return index
            }
        }
        return nil
    }
    
    mutating func moveToPage(index: Int) {
        guard index >= 0 && index < pages.count else { return }
        lockCurrentPage() // Lock current page before moving
        currentPageIndex = index
    }
}
