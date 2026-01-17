import SwiftUI
import QuickLook
import Foundation

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

    @ObservedObject private var menuCoordinator = MenuCoordinator()

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
                BottomBar().padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
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

            // MARK: - Bottom Sheet Menu
            if menuCoordinator.isBottomSheetVisible {
                bottomSheetOverlay
                    .zIndex(100)
            }
            //
            if( menuCoordinator.shouldShowFileExtensionsAlert ){
                let currentFileURL = menuCoordinator.selectedFile!
                let parentURL = currentFileURL.deletingLastPathComponent()
                    let fileExt = menuCoordinator.newFileName.fileExtension.lowercased()

                    let title = "Are you sure you want to change the extension from \".\(currentFileURL.pathExtension)\" to \".\(fileExt)\"?"

                    AlertPrompt(title: title, okButtonText: "Keep .\(currentFileURL.pathExtension)", cancelButtonText: "Use .\(fileExt)",name: $menuCoordinator.newFileName,isPresented: $menuCoordinator.shouldShowFileExtensionsAlert){
                        let oldExtension = currentFileURL.pathExtension
                        let baseName = (menuCoordinator.newFileName as! NSString).deletingPathExtension
                        menuCoordinator.newFileName = "\(baseName).\(oldExtension)"
                        print("new file name is \(menuCoordinator.newFileName)")
                        doRename(oldName: currentFileURL.lastPathComponent, newName: menuCoordinator.newFileName, in: parentURL)
                    } onCancel: {//We need to rename file name alone and keep the extension as it is
                        doRename(oldName: currentFileURL.lastPathComponent, newName: menuCoordinator.newFileName, in: parentURL)
                    }
            }
            if( menuCoordinator.shouldShowErrorMessage ){
                AlertPrompt(title: menuCoordinator.showRenameErrorMessage, okButtonText: "Ok", disableCancelButton:true, name: $menuCoordinator.newFileName, isPresented: $menuCoordinator.shouldShowErrorMessage){
                    menuCoordinator.resetVar()
                } onCancel: {//FIXME: when disableCancelButton is true, there is no need to pass it, need to support the code accordingly
                    menuCoordinator.resetVar()
                }
            }
            if( menuCoordinator.showRenameView ){
                AlertPrompt(title: "Enter the new name", placeHolder: "New File Name", okButtonText: "Rename", name: $menuCoordinator.newFileName, isPresented: $menuCoordinator.showRenameView){
                    print("User entered:", $menuCoordinator.newFileName)

                    let currentFileURL = menuCoordinator.selectedFile!
                    let parentURL = currentFileURL.deletingLastPathComponent()
                    if(currentFileURL.lastPathComponent == menuCoordinator.newFileName){//When there is no changes in file, both will be same
                        return
                    }
                    var isDiff = false
                    if(!currentFileURL.isDirectory){
                        let fileExt = menuCoordinator.newFileName.fileExtension.lowercased()
                        isDiff = fileExt != currentFileURL.pathExtension
                        menuCoordinator.shouldShowFileExtensionsAlert = isDiff
                    }
                    if(!isDiff){//When there is no changes in file extension. for folder it is false by default
                        doRename(oldName: currentFileURL.lastPathComponent, newName: menuCoordinator.newFileName, in: parentURL)
                    }
                } onCancel: {
                    print("cancel :: User entered:", $menuCoordinator.selectedFile)
                    menuCoordinator.resetVar()
                }
            }
        }
        .onAppear(perform: loadItems)
        .navigationBarBackButtonHidden(true)
    }
    private func doRename(oldName: String, newName: String, in folderURL: URL){
        do {
            try FileUtils.rename(
                oldName: oldName,
                newName: newName,
                in: folderURL
            )
            menuCoordinator.resetVar()
            loadItems()
        } catch FileUtils.FileError.sourceNotFound(let path) {
            menuCoordinator.showRenameErrorMessage = "\(oldName) does not exist."
            menuCoordinator.shouldShowErrorMessage = true
            print("Source not found:", path)
        } catch FileUtils.FileError.destinationAlreadyExists(let path) {
            menuCoordinator.showRenameErrorMessage = "\(newName) already exist in the folder"
            menuCoordinator.shouldShowErrorMessage = true
            print("Destination exists:", path)
        } catch FileUtils.FileError.failedToRename(let oldPath, let newPath, let underlyingError) {
            menuCoordinator.showRenameErrorMessage = "Error while renaming \(oldName) to \(newName)"
            menuCoordinator.shouldShowErrorMessage = true
            print("Failed from \(oldPath) to \(newPath): \(underlyingError)")
        } catch {
            print("Unexpected error:", error)
        }
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
//        debugPrint(folderURL.deletingLastPathComponent())
//        selectedFolder = folderURL.deletingLastPathComponent();
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
                    FileRowView(
                        url: url,
                        layout: .grid(width: itemWidth),
                        menuCoordinator: menuCoordinator,
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
                FileRowView(
                    url: url,
                    layout: .list(thumbnailSize: 44),
                    menuCoordinator: menuCoordinator,
                    onTap: handleItemTap
                )
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

    // MARK: - Bottom Sheet Overlay
    private var bottomSheetOverlay: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    menuCoordinator.hideBottomSheet()
                }

            // Bottom sheet
            VStack {
                Spacer()

                if let selectedFile = menuCoordinator.selectedFile {
                    VStack(spacing: 0) {
                        // File info header with cancel button
                        HStack(spacing: 12) {
                            // File icon and name on the left
                            HStack(spacing: 12) {
                                Image(systemName: selectedFile.isDirectory ? "folder.fill" : "doc.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)

                                Text(selectedFile.lastPathComponent)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            // Cancel button on the right
                            Button {
                                menuCoordinator.hideBottomSheet()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, height: 30)
                                    .background(Color(UIColor.tertiarySystemFill))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        .padding(.horizontal, 20)

                        Divider()

                        // Actions
                        actionButton("Rename", icon: "pencil") {
                            menuCoordinator.hideBottomSheet()
                            menuCoordinator.showRenameView = true
                            menuCoordinator.newFileName = selectedFile.lastPathComponent
                            print("Rename \(selectedFile.lastPathComponent)")
                        }

                        actionButton("Move", icon: "folder") {
                            menuCoordinator.hideBottomSheet()
                            print("Move \(selectedFile.lastPathComponent)")
                        }

                        actionButton("Zip", icon: "doc.zipper") {
                            menuCoordinator.hideBottomSheet()
                            print("Zip \(selectedFile.lastPathComponent)")
                        }

                        actionButton("Lock", icon: "lock") {
                            menuCoordinator.hideBottomSheet()
                            print("Lock \(selectedFile.lastPathComponent)")
                        }

                        if !selectedFile.isDirectory {
                            actionButton("Share", icon: "square.and.arrow.up") {
                                menuCoordinator.hideBottomSheet()
                                print("Share \(selectedFile.lastPathComponent)")
                            }
                        }

                        actionButton("Move to Trash", icon: "trash", isDestructive: true) {
                            menuCoordinator.hideBottomSheet()
                            print("Trash \(selectedFile.lastPathComponent)")
                        }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 20)
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
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
