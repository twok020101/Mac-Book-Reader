import SwiftUI

public struct ReaderToolbar: View {
    @ObservedObject var viewModel: ReaderViewModel
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack {
            Button(action: { withAnimation { viewModel.previousPage() } }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if (viewModel.epubDocument?.spine.items.count) != nil {
                VStack(spacing: 2) {
                    // Page info
                    Text("Page \(viewModel.currentSubPage + 1) of \(viewModel.totalSubPages)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    
                    // Chapter info
                    if let title = viewModel.currentChapterTitle {
                        // If logic for title returns pure title, prepend Chapter number
                        Text("Chapter \(viewModel.currentPage + 1): \(title)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Chapter \(viewModel.currentPage + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: { withAnimation { viewModel.nextPage() } }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 20)
        .frame(maxWidth: 400)
    }
}
