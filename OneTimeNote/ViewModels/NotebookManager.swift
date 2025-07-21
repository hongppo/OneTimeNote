import SwiftUI
import Combine

@MainActor
class NotebookManager: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var currentNotebook: Notebook?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingToast: Bool = false
    @Published var toastMessage: String = ""
    
    private let dataManager = DataManager()
    private var autoSaveTimer: Timer?
    private var saveWorkItem: DispatchWorkItem?
    
    init() {
        loadNotebooks()
        startAutoSave()
    }
    
    // MARK: - Data Management
    
    func loadNotebooks() {
        isLoading = true
        notebooks = dataManager.loadNotebooks()
        
        if notebooks.isEmpty {
            let defaultNotebook = Notebook(name: "나의 첫 노트", isDefault: true)
            notebooks.append(defaultNotebook)
            currentNotebook = defaultNotebook
            saveNotebooks()
        } else {
            currentNotebook = notebooks.first
        }
        
        isLoading = false
    }
    
    func saveNotebooks() {
        saveWorkItem?.cancel()
        saveWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.dataManager.saveNotebooks(self.notebooks)
        }
        
        if let workItem = saveWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }
    
    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.saveNotebooks()
        }
    }
    
    // MARK: - Notebook Management
    
    func createNotebook(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showToast("노트북 이름을 입력하세요")
            return
        }
        
        let notebook = Notebook(name: trimmedName)
        notebooks.append(notebook)
        currentNotebook = notebook
        saveNotebooks()
        showToast("새 노트북이 생성되었습니다")
    }
    
    func deleteNotebook(_ notebook: Notebook) {
        guard !notebook.isDefault else {
            showToast("기본 노트북은 삭제할 수 없습니다")
            return
        }
        
        notebooks.removeAll { $0.id == notebook.id }
        
        if currentNotebook?.id == notebook.id {
            currentNotebook = notebooks.first
        }
        
        saveNotebooks()
        showToast("노트북이 삭제되었습니다")
    }
    
    func selectNotebook(_ notebook: Notebook) {
        if currentNotebook?.id != notebook.id {
            // Lock current page before switching
            if var current = currentNotebook,
               let index = notebooks.firstIndex(where: { $0.id == current.id }) {
                current.lockCurrentPage()
                notebooks[index] = current
            }
            
            currentNotebook = notebooks.first(where: { $0.id == notebook.id })
            saveNotebooks()
        }
    }
    
    // MARK: - Page Management
    
    func updateCurrentPageContent(_ content: String) {
        guard var notebook = currentNotebook else { return }
        
        if notebook.updateCurrentPageContent(content) {
            if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
                notebooks[index] = notebook
                currentNotebook = notebook
            }
        }
    }
    
    func navigateToPage(_ direction: Int) {
        guard var notebook = currentNotebook else { return }
        
        let newIndex = notebook.currentPageIndex + direction
        guard newIndex >= 0 && newIndex < notebook.pages.count else { return }
        
        notebook.moveToPage(index: newIndex)
        
        // Skip torn pages
        while notebook.pages[notebook.currentPageIndex].isTorn {
            let nextIndex = notebook.currentPageIndex + direction
            if nextIndex < 0 || nextIndex >= notebook.pages.count {
                showToast("사용 가능한 페이지가 없습니다")
                return
            }
            notebook.currentPageIndex = nextIndex
        }
        
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[index] = notebook
            currentNotebook = notebook
            saveNotebooks()
        }
    }
    
    func jumpToPage(_ pageIndex: Int) {
        guard var notebook = currentNotebook,
              pageIndex >= 0 && pageIndex < notebook.pages.count,
              !notebook.pages[pageIndex].isTorn else { return }
        
        notebook.moveToPage(index: pageIndex)
        
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[index] = notebook
            currentNotebook = notebook
            saveNotebooks()
        }
    }
    
    func tearCurrentPage() {
        guard var notebook = currentNotebook else { return }
        
        if notebook.tearCurrentPage() {
            // Find next available page
            if let nextIndex = notebook.getNextAvailablePageIndex() {
                notebook.currentPageIndex = nextIndex
            }
            
            if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
                notebooks[index] = notebook
                currentNotebook = notebook
                saveNotebooks()
                showToast("페이지를 찢었습니다")
            }
        }
    }
    
    // MARK: - UI Helpers
    
    func showToast(_ message: String) {
        toastMessage = message
        showingToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showingToast = false
        }
    }
    
    var totalPagesUsed: Int {
        notebooks.reduce(0) { $0 + $1.usedPagesCount }
    }
    
    var totalPagesTorn: Int {
        notebooks.reduce(0) { $0 + $1.tornPagesCount }
    }
    
    deinit {
        autoSaveTimer?.invalidate()
        saveWorkItem?.cancel()
    }
}
