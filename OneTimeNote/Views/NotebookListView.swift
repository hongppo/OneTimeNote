import SwiftUI

struct NotebookListView: View {
    @EnvironmentObject var notebookManager: NotebookManager
    @Environment(\.dismiss) var dismiss
    @State private var showingAddNotebook = false
    @State private var newNotebookName = ""
    @State private var notebookToDelete: Notebook?
    
    var body: some View {
        NavigationView {
            VStack {
                // Stats
                statsView
                
                // Notebook List
                List {
                    ForEach(notebookManager.notebooks) { notebook in
                        NotebookRow(notebook: notebook)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                notebookManager.selectNotebook(notebook)
                                dismiss()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if !notebook.isDefault {
                                    Button(role: .destructive) {
                                        notebookToDelete = notebook
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("노트북")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddNotebook = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddNotebook) {
            AddNotebookView(notebookName: $newNotebookName) {
                notebookManager.createNotebook(name: newNotebookName)
                newNotebookName = ""
            }
        }
        .alert("노트북 삭제", isPresented: .constant(notebookToDelete != nil)) {
            Button("취소", role: .cancel) {
                notebookToDelete = nil
            }
            Button("삭제", role: .destructive) {
                if let notebook = notebookToDelete {
                    notebookManager.deleteNotebook(notebook)
                    notebookToDelete = nil
                }
            }
        } message: {
            Text("\"\(notebookToDelete?.name ?? "")\" 노트북을 삭제하시겠습니까?")
        }
    }
    
    private var statsView: some View {
        HStack {
            StatCard(
                title: "노트북",
                value: "\(notebookManager.notebooks.count)",
                color: .blue
            )
            
            StatCard(
                title: "작성된 페이지",
                value: "\(notebookManager.totalPagesUsed)",
                color: .green
            )
            
            StatCard(
                title: "찢어진 페이지",
                value: "\(notebookManager.totalPagesTorn)",
                color: .red
            )
        }
        .padding()
    }
}

struct NotebookRow: View {
    let notebook: Notebook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(notebook.name)
                    .font(.headline)
                
                if notebook.isDefault {
                    Text("기본")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            
            HStack {
                Label("\(notebook.usedPagesCount)/50", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(notebook.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct AddNotebookView: View {
    @Binding var notebookName: String
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("노트북 이름", text: $notebookName)
                        .focused($isFocused)
                } header: {
                    Text("새 노트북 만들기")
                }
            }
            .navigationTitle("새 노트북")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        notebookName = ""
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("만들기") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(notebookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}
