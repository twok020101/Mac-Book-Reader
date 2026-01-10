import SwiftUI

public struct BookCard: View {
    let book: Book
    
    public init(book: Book) {
        self.book = book
    }
    
    public var body: some View {
        VStack {
            if let data = book.coverImageData, let nsImage = NSImage(data: data) {
                 Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .overlay(Text(book.title).foregroundStyle(.white).padding())
            }
        }
        .frame(height: 200)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
        .padding(4)
    }
}
