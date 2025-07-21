import SwiftUI

struct PageView: View {
    @EnvironmentObject var notebookManager: NotebookManager
    @State private var currentText: String = ""
    @State private var showingTearConfirm = false
    @State private var showingNotebookList = false
    @FocusState private var isTextFieldFocused: Bool
    
    var currentPage: Page? {
        notebookManager.currentNotebook?.currentPage
    }
    
    var characterCount: Int {
        currentText.count
    }
    
    var characterCountColor: Color {
        if characterCount >= 500 { return .red }
        if characterCount >= 450 { return .orange }
        return .secondary
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Editor
                if let page = currentPage {
                    if page.isTorn {
                        tornPageView
                    } else {
                        editorView(page: page)
                    }
                } else {
                    Spacer()
                }
                
                // Page Indicator
                pageIndicator
                
                // Navigation
                navigationButtons
            }
            .navigationBarHidden(true)
            .onAppear {
                loadCurrentPage()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                // Notebook selector
                Menu {
                    ForEach(notebookManager.notebooks) { notebook in
                        Button(action: {
                            notebookManager.selectNotebook(notebook)
                            loadCurrentPage()
                        }) {
                            Label(notebook.name, systemImage: notebook.id == notebookManager.currentNotebook?.id ? "checkmark" : "")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        showingNotebookList = true
                    }) {
                        Label("노트북 관리", systemImage: "folder")
                    }
                } label: {
                    HStack {
                        Text(notebookManager.currentNotebook?.name ?? "노트북")
                            .font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Character count
                Text("\(characterCount) / 500")
                    .font(.footnote)
                    .foregroundColor(characterCountColor)
            }
            .padding()
            
            // Page info bar
            HStack {
                Text("페이지 \(currentPage?.pageNumber ?? 1) / 50")
                    .font(.subheadline)
                
                Spacer()
                
                if let page = currentPage {
                    HStack(spacing: 5) {
                        Image(systemName: page.state.icon)
                        Text(page.state.title)
                    }
                    .font(.footnote)
                    .foregroundColor(page.state.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(page.state.color.opacity(0.1))
                    .cornerRadius(15)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private func editorView(page: Page) -> some View {
        VStack {
            if page.canEdit {
                TextEditor(text: $currentText)
                    .padding(4)
                    .focused($isTextFieldFocused)
                    .onChange(of: currentText) { newValue in
                        if newValue.count <= Page.maxCharacters {
                            notebookManager.updateCurrentPageContent(newValue)
                        } else {
                            currentText = String(newValue.prefix(Page.maxCharacters))
                        }
                    }
            } else {
                ScrollView {
                    Text(page.content)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(UIColor.tertiarySystemBackground))
                
                Text("이 페이지는 작성이 완료되어 수정할 수 없습니다")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
            }
        }
        .padding()
    }
    
    private var tornPageView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.slash")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("이 페이지는 찢어졌습니다")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.tertiarySystemBackground))
    }
    
    private var pageIndicator: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let notebook = notebookManager.currentNotebook {
                    ForEach(notebook.pages.indices, id: \.self) { index in
                        Circle()
                            .fill(pageIndicatorColor(for: notebook.pages[index], isCurrent: index == notebook.currentPageIndex))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == notebook.currentPageIndex ? 1.2 : 1.0)
                            .onTapGesture {
                                if !notebook.pages[index].isTorn {
                                    notebookManager.jumpToPage(index)
                                    loadCurrentPage()
                                }
                            }
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private func pageIndicatorColor(for page: Page, isCurrent: Bool) -> Color {
        if isCurrent { return .blue }
        if page.isTorn { return .red }
        if page.content.count > 0 { return .green }
        return Color(UIColor.systemGray4)
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 20) {
            Button(action: {
                notebookManager.navigateToPage(-1)
                loadCurrentPage()
            }) {
                Label("이전", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(notebookManager.currentNotebook?.currentPageIndex == 0)
            
            Button(action: {
                showingTearConfirm = true
            }) {
                Label("찢기", systemImage: "scissors")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(currentPage?.isTorn ?? true || currentPage?.content.isEmpty ?? true)
            
            Button(action: {
                notebookManager.navigateToPage(1)
                loadCurrentPage()
            }) {
                Label("다음", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(notebookManager.currentNotebook?.currentPageIndex == 49)
        }
        .padding()
        .confirmationDialog("페이지를 찢으시겠습니까?", isPresented: $showingTearConfirm, titleVisibility: .visible) {
            Button("찢기", role: .destructive) {
                notebookManager.tearCurrentPage()
                loadCurrentPage()
            }
        } message: {
            Text("찢어진 페이지는 복구할 수 없습니다. 작성한 내용이 영구적으로 삭제됩니다.")
        }
        .sheet(isPresented: $showingNotebookList) {
            NotebookListView()
                .environmentObject(notebookManager)
        }
    }
    
    private func loadCurrentPage() {
        currentText = currentPage?.content ?? ""
    }
}
