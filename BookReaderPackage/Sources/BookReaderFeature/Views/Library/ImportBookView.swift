import SwiftUI

public struct ImportBookView: View {
    @Binding var isPresented: Bool
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack {
            Text("Import Books")
                .font(.headline)
            
            Button("Select Files") {
                showFileImporter = true
            }
            .padding()
            
            Button("Done") {
                isPresented = false
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.epub, .pdf], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                onImport(urls)
                isPresented = false
            case .failure(let error):
                print("Import failed: \(error)")
            }
        }
    }
    
    @State private var showFileImporter = false
    var onImport: ([URL]) -> Void = { _ in }
    
    public init(isPresented: Binding<Bool>, onImport: @escaping ([URL]) -> Void = { _ in }) {
        self._isPresented = isPresented
        self.onImport = onImport
    }
}
