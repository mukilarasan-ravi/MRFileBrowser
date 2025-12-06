import SwiftUI

public struct FileBrowserLayout: View {
    public let folderURL: URL
    let onClose: () -> Void

    @State private var items: [URL] = []
    @State private var showSearchBar = false
    @State private var searchText = ""
    @State private var isGridView = true
    @State private var columnsCount: Int = 2

    @Binding var titleName: String

    public init(folderURL: URL, titleName: Binding<String>, onClose: @escaping () -> Void) {
        self.folderURL = folderURL
        _titleName = titleName
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {

            // MARK: - Top Bar
            TopBar(
                showSearchBar: $showSearchBar,
                titleName: $titleName,
                isGridView: $isGridView,
                columnsCount: $columnsCount,
                onClose: onClose
            )

            // MARK: - Search Bar
            if showSearchBar {
                searchBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // MARK: - File List / Grid
            Group {
                // Only attempt grid code on iOS 14+. Otherwise fallback to list.
                if isGridView,#available(iOS 14.0, *) {
                        // Grid on iOS 14+
                        ScrollView {
                            fileGridView_iOS14Plus()
                        }
                        // attach gesture to scroll view so ScrollView doesn't swallow it
                        .simultaneousGesture(gridMagnificationGesture())
                } else {
                    ScrollView { fileListView }
                }
            }
            .animation(.default, value: isGridView)

            // MARK: - Bottom Bar
            BottomBar()
        }
        .onAppear(perform: loadItems)
    }

    // MARK: - SEARCH BAR
    var searchBar: some View {
        TextField("Search files...", text: $searchText)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .padding(.horizontal, 8)
    }

    // MARK: - GRID (iOS 14+ only)
    @ViewBuilder
    private func fileGridView_iOS14Plus() -> some View {
        if #available(iOS 14.0, *) {
            // Calculate item width based on screen width and spacing
            let screenWidth = UIScreen.main.bounds.width
            let spacing: CGFloat = 10
            let totalSpacing = spacing * CGFloat(columnsCount + 1)
            let itemWidth = max(0, (screenWidth - totalSpacing) / CGFloat(columnsCount))

            let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: columnsCount)

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(filteredItems(), id: \.self) { url in
                    FileRowGridView(url: url, width: itemWidth)
                        .frame(width: itemWidth, height: itemWidth) // square cell
                }
            }
            .padding(.horizontal, spacing)
            .padding(.top, 10)
        } else {
            fileListView
        }
    }

    // MARK: - LIST VIEW
    var fileListView: some View {
        VStack(spacing: 0) {
            fileListing
        }
        .padding(.top, 10)
    }

    // MARK: - FILE LISTING
    var fileListing: some View {
        ForEach(filteredItems(), id: \.self) { url in
            FileRowNormalView(url: url)
        }
    }

    // MARK: - Magnification Gesture (grid)
    private func gridMagnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onEnded { scale in
                if scale > 1.05 {
                    columnsCount = max(2, columnsCount - 1)
                } else if scale < 0.95 {
                    columnsCount = min(4, columnsCount + 1)
                }
            }
    }

    // MARK: - HELPERS
    private func loadItems() {
        let fm = FileManager.default
        items = (try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    private func filteredItems() -> [URL] {
        if searchText.isEmpty { return items }
        return items.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
    }
}
