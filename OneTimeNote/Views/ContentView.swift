import SwiftUI

struct ContentView: View {
    @StateObject private var notebookManager = NotebookManager()
    @State private var showingNotebookList = false
    
    var body: some View {
        ZStack {
            if notebookManager.isLoading {
                ProgressView("로딩 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
            } else {
                PageView()
                    .environmentObject(notebookManager)
            }
            
            // Toast
            if notebookManager.showingToast {
                VStack {
                    Spacer()
                    Text(notebookManager.toastMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: notebookManager.showingToast)
            }
        }
        .sheet(isPresented: $showingNotebookList) {
            NotebookListView()
                .environmentObject(notebookManager)
        }
    }
}
