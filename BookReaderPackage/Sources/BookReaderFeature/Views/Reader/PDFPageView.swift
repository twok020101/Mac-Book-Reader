import SwiftUI
import PDFKit

public struct PDFPageView: View {
    let book: Book
    @State private var pdfDocument: PDFDocument?
    
    public init(book: Book) {
        self.book = book
    }
    
    public var body: some View {
        PDFKitRepresentedView(document: pdfDocument)
            .onAppear {
                 loadPDF()
            }
    }
    
    private func loadPDF() {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docsURL.appendingPathComponent(book.filePath)
        self.pdfDocument = PDFService.shared.document(from: url)
    }
}

struct PDFKitRepresentedView: NSViewRepresentable {
    let document: PDFDocument?
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document != document {
            pdfView.document = document
        }
    }
}
