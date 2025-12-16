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
    let isRoot: Bool

    @Binding var titleName: String
    @Binding var isGridView: Bool
    @Binding var columnsCount: Int

    // MARK: - State
    @State private var items: [URL] = []
    @State private var showSearchBar = false
    @State private var searchText = ""

    @State private var selectedFolder: URL? = nil
    @State private var previewItem: PreviewItem? = nil // For full-screen preview

    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Init
    public init(
        folderURL: URL,
        titleName: Binding<String>,
        isGridView: Binding<Bool>,
        columnsCount: Binding<Int>,
        isRoot: Bool = true
    ) {
        self.folderURL = folderURL
        self.isRoot = isRoot
        _titleName = titleName
        _isGridView = isGridView
        _columnsCount = columnsCount
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
                    isRoot: isRoot,
                    showSearchBar: $showSearchBar,
                    titleName: $titleName,
                    isGridView: $isGridView,
                    columnsCount: $columnsCount,
                    onBack: goBack,
                )

                // Search Bar
                if showSearchBar {
                    searchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Content
                Group {
                    let currentItems = filteredItems()

                    if items.isEmpty || currentItems.isEmpty {
                        Spacer()
                            Image(systemName: "folder") // SF Symbol for folder
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50) // Adjust size as needed
                                .foregroundColor(Color.blue.opacity(0.7))

                            Text("Folder is Empty")
                                .foregroundColor(Color.blue.opacity(0.7))
                                .font(.system(size: 20, weight: .regular))

                            Spacer()

                    } else if isGridView, #available(iOS 14.0, *) {
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
                FullScreenQuickLookPreview(
                    url: previewItem.url,
                    onClose:{
                        self.previewItem = nil
                    }, title: previewItem.url.lastPathComponent
                )
            }

        }
        .onAppear(perform: loadItems)
        .navigationBarBackButtonHidden(true)
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
                isRoot: false
            )
        }
    }

    private func goBack() {
        presentationMode.wrappedValue.dismiss()
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
    let title: String

    func makeUIViewController(context: Context) -> UIViewController {

        let container = UIViewController()
        container.view.backgroundColor = .black

        // -----------------------------
        // QLPreviewController
        // -----------------------------
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.view.translatesAutoresizingMaskIntoConstraints = false

        container.addChild(preview)
        container.view.addSubview(preview.view)
        preview.didMove(toParent: container)

        // -----------------------------
        // SwiftUI TopBar
        // -----------------------------
        let topBar = UIHostingController(
            rootView: TopBar(
                isRoot: true,
                showSearchBar: .constant(false),
                titleName: .constant(title),
                isGridView: .constant(false),
                columnsCount: .constant(2),
                showsSearch: false,
                showsGridToggle: false,
                onBack: {
                    context.coordinator.close()
                }
            )
        )


        topBar.view.backgroundColor = .clear
        topBar.view.translatesAutoresizingMaskIntoConstraints = false

        container.addChild(topBar)
        container.view.addSubview(topBar.view)
        topBar.didMove(toParent: container)

        // -----------------------------
        // Layout
        // -----------------------------
        NSLayoutConstraint.activate([

            // TopBar
            topBar.view.topAnchor.constraint(equalTo: container.view.safeAreaLayoutGuide.topAnchor),
            topBar.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            topBar.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            topBar.view.heightAnchor.constraint(equalToConstant: 56),

            // Preview below TopBar
            preview.view.topAnchor.constraint(equalTo: topBar.view.bottomAnchor),
            preview.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            preview.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            preview.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
        ])

        return container
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, onClose: onClose)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, QLPreviewControllerDataSource {

        let url: URL
        let onClose: () -> Void

        init(url: URL, onClose: @escaping () -> Void) {
            self.url = url
            self.onClose = onClose
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }

        @objc func close() {
            onClose()
        }
    }
}
