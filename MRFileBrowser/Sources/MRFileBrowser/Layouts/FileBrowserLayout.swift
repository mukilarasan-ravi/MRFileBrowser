import SwiftUI
import QuickLook

// MARK: - Identifiable Wrapper for URL
struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Main File Browser
public struct FileBrowserLayout: View {

    // MARK: - Inputs
    public let folderURL: URL
    let onClose: () -> Void

    @Binding var titleName: String
    @Binding var isGridView: Bool
    @Binding var columnsCount: Int

    // MARK: - State
    @State private var items: [URL] = []
    @State private var showSearchBar = false
    @State private var searchText = ""

    @State private var selectedFolder: URL? = nil
    @State private var previewItem: PreviewItem? = nil // For full-screen preview

    // MARK: - Init
    public init(
        folderURL: URL,
        titleName: Binding<String>,
        isGridView: Binding<Bool>,
        columnsCount: Binding<Int>,
        onClose: @escaping () -> Void
    ) {
        self.folderURL = folderURL
        _titleName = titleName
        _isGridView = isGridView
        _columnsCount = columnsCount
        self.onClose = onClose
    }

    // MARK: - Body
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {

                // Hidden Navigation
                NavigationLink(
                    destination: destinationView(),
                    isActive: Binding(
                        get: { selectedFolder != nil },
                        set: { if !$0 { selectedFolder = nil } }
                    )
                ) {
                    EmptyView()
                }

                // Top Bar
                TopBar(
                    showSearchBar: $showSearchBar,
                    titleName: $titleName,
                    isGridView: $isGridView,
                    columnsCount: $columnsCount,
                    onClose: onClose
                )

                // Search Bar
                if showSearchBar {
                    searchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Content
                Group {
                    if isGridView, #available(iOS 14.0, *) {
                        ScrollView {
                            fileGridView_iOS14Plus()
                        }
                        .simultaneousGesture(gridMagnificationGesture())
                    } else {
                        ScrollView {
                            fileListView
                        }
                    }
                }
                .animation(.default, value: isGridView)

                // Bottom Bar
                BottomBar()
            }

            // MARK: - Full-Screen QuickLook Preview
            if let previewItem = previewItem {
                FullScreenQuickLookPreview(url: previewItem.url) {
                    self.previewItem = nil // Close action
                }
            }
        }
        .onAppear(perform: loadItems)
    }

    // MARK: - Destination View
    @ViewBuilder
    private func destinationView() -> some View {
        if let folder = selectedFolder {
            FileBrowserLayout(
                folderURL: folder,
                titleName: .constant(folder.lastPathComponent),
                isGridView: $isGridView,
                columnsCount: $columnsCount,
                onClose: onClose
            )
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        TextField("Search files...", text: $searchText)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .padding(.horizontal, 8)
    }

    // MARK: - Grid View (iOS 14+)
    @ViewBuilder
    private func fileGridView_iOS14Plus() -> some View {
        if #available(iOS 14.0, *) {
            let screenWidth = UIScreen.main.bounds.width
            let spacing: CGFloat = 10
            let totalSpacing = spacing * CGFloat(columnsCount + 1)
            let itemWidth = max(0, (screenWidth - totalSpacing) / CGFloat(columnsCount))

            let columns = Array(
                repeating: GridItem(.fixed(itemWidth), spacing: spacing),
                count: columnsCount
            )

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(filteredItems(), id: \.self) { url in
                    FileRowGridView(
                        url: url,
                        width: itemWidth,
                        onTap: handleItemTap
                    )
                    .frame(width: itemWidth, height: itemWidth)
                }
            }
            .padding(.horizontal, spacing)
            .padding(.top, 10)
        } else {
            fileListView
        }
    }

    // MARK: - List View
    private var fileListView: some View {
        VStack(spacing: 0) {
            ForEach(filteredItems(), id: \.self) { url in
                FileRowNormalView(url: url, onTap: handleItemTap)
                    .contentShape(Rectangle())
                    .onTapGesture { handleItemTap(url) }
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Navigation Handler
    private func handleItemTap(_ url: URL) {
        if url.isDirectory {
            selectedFolder = url
        } else {
            previewItem = PreviewItem(url: url) // trigger full-screen preview
        }
    }

    // MARK: - Grid Zoom Gesture
    private func gridMagnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onEnded { scale in
                if scale > 1.05 { columnsCount = max(2, columnsCount - 1) }
                else if scale < 0.95 { columnsCount = min(4, columnsCount + 1) }
            }
    }

    // MARK: - Helpers
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
        return items.filter {
            $0.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Full Screen QuickLook Preview
struct FullScreenQuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .black

        // Embed QLPreviewController
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.view.frame = controller.view.bounds
        preview.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.addChild(preview)
        controller.view.addSubview(preview.view)
        preview.didMove(toParent: controller)

        // Add close button
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "xmark")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .bold))
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(context.coordinator, action: #selector(Coordinator.close), for: .touchUpInside)
        controller.view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -20),
            button.widthAnchor.constraint(equalToConstant: 80),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url, onClose: onClose) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        let onClose: () -> Void
        init(url: URL, onClose: @escaping () -> Void) { self.url = url; self.onClose = onClose }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }

        @objc func close() {
            onClose()
        }
    }
}
