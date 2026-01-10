import SwiftUI
import EPUBKit

public struct ChapterListSidePanel: View {
    @ObservedObject var viewModel: ReaderViewModel
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text("Table of Contents")
                .font(.headline)
                .padding()
            
            if let tocRoot = viewModel.epubDocument?.tableOfContents, let items = tocRoot.subTable {
                List {
                    ForEach(items, id: \.id) { item in
                        TOCItemView(item: item, viewModel: viewModel, isTopLevel: true)
                    }
                }
            } else {
                ContentUnavailableView("No Table of Contents", systemImage: "list.bullet")
            }
        }
        .frame(minWidth: 200, maxWidth: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct TOCItemView: View {
    let item: EPUBTableOfContents
    @ObservedObject var viewModel: ReaderViewModel
    let isTopLevel: Bool
    
    var body: some View {
        if let children = item.subTable, !children.isEmpty {
            DisclosureGroup(
                content: {
                    ForEach(children, id: \.id) { child in
                        TOCItemView(item: child, viewModel: viewModel, isTopLevel: false)
                    }
                },
                label: {
                    chapterButton
                }
            )
        } else {
            chapterButton
        }
    }
    
    var chapterButton: some View {
        Button(action: {
            let result = viewModel.spineIndex(for: item)
            if let index = result.index {
                withAnimation {
                    viewModel.jumpToChapter(index: index, fragment: result.fragment)
                }
            }
        }) {
            HStack(spacing: 4) {
                if isTopLevel, let index = viewModel.spineIndex(for: item).index {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(item.label)
                    .foregroundStyle(viewModel.isCurrentChapter(item) ? Color.accentColor : Color.primary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}


