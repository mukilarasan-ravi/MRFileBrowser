import SwiftUI
import UIKit
import QuickLook
import Foundation
import Combine

// UserDefaults keys for persistent folder paths
private extension UserDefaults {
    static let lastMoveFolderPathKey = "MRFileBrowser.LastMoveFolderPath"
    static let lastRestoreFolderPathKey = "MRFileBrowser.LastRestoreFolderPath"

    var lastMoveFolderPath: String? {
        get { string(forKey: Self.lastMoveFolderPathKey) }
        set { set(newValue, forKey: Self.lastMoveFolderPathKey) }
    }

    var lastRestoreFolderPath: String? {
        get { string(forKey: Self.lastRestoreFolderPathKey) }
        set { set(newValue, forKey: Self.lastRestoreFolderPathKey) }
    }
}

private class MoveFolderPickerDelegate: FolderPickerDelegate {
    private let onFolderSelected: (URL) -> Void
    private let onCancel: () -> Void

    init(onFolderSelected: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.onFolderSelected = onFolderSelected
        self.onCancel = onCancel
    }

    func folderPicker(_ picker: FolderPickerView, selectItems urls: [URL]) {
        if let firstUrl = urls.first {
            // Save the selected path to UserDefaults for next time
            UserDefaults.standard.lastMoveFolderPath = firstUrl.path
            onFolderSelected(firstUrl)
        }
    }

    func folderPickerDidCancel(_ picker: FolderPickerView) {
        onCancel()
    }
}

private class RestoreFolderPickerDelegate: FolderPickerDelegate {
    private let onFolderSelected: (URL) -> Void
    private let onCancel: () -> Void

    init(onFolderSelected: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.onFolderSelected = onFolderSelected
        self.onCancel = onCancel
    }

    func folderPicker(_ picker: FolderPickerView, selectItems urls: [URL]) {
        if let firstUrl = urls.first {
            // Save the selected path to UserDefaults for next time
            UserDefaults.standard.lastRestoreFolderPath = firstUrl.path
            onFolderSelected(firstUrl)
        }
    }

    func folderPickerDidCancel(_ picker: FolderPickerView) {
        onCancel()
    }
}

struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

// Shared runtime state for a FileBrowserLayout navigation stack. The root
// retains an instance via @State; pushed children inherit the same instance
// through Environment, so mutations at any level (toggle list/grid, change
// column count, future flags) apply across every folder in the stack.
//
// Add new shared view-state here rather than creating parallel environment
// keys — callers read/write via `layoutState.<field>`.
final class LayoutState: ObservableObject {
    @Published var isGridView: Bool
    @Published var columnsCount: Int

    init(isGridView: Bool, columnsCount: Int) {
        self.isGridView = isGridView
        self.columnsCount = columnsCount
    }
}

private struct LayoutStateKey: EnvironmentKey {
    static let defaultValue: LayoutState? = nil
}

extension EnvironmentValues {
    var layoutState: LayoutState? {
        get { self[LayoutStateKey.self] }
        set { self[LayoutStateKey.self] = newValue }
    }
}

//File Browser Main UI
public struct FileBrowserLayout: View {

    public let folderURL: URL
    let isRoot: Bool
    private let initialRootURL: URL //Store the initial folder
    private let searchUtil = SearchUtil.shared

    @Binding var titleName: String

    private let viewConfiguration: ViewConfiguration

    // Shared state routing:
    //  - At the root, `localLayoutState` is the source of truth. We use @State
    //    (not @StateObject, for iOS 13 compatibility) — @State retains the
    //    reference across rebuilds; @Published observation is re-established
    //    via `.onReceive(...)` + `layoutStateTick` in body.
    //  - Pushed children receive the parent's instance via
    //    `.environment(\.layoutState, ...)` and read it through
    //    `inheritedLayoutState`.
    @State private var localLayoutState: LayoutState
    @State private var layoutStateTick: Int = 0
    @Environment(\.layoutState) private var inheritedLayoutState: LayoutState?

    private var layoutState: LayoutState {
        inheritedLayoutState ?? localLayoutState
    }

    private var isGridView: Bool {
        get { layoutState.isGridView }
        nonmutating set { layoutState.isGridView = newValue }
    }

    private var columnsCount: Int {
        get { layoutState.columnsCount }
        nonmutating set { layoutState.columnsCount = newValue }
    }

    private var isGridViewBinding: Binding<Bool> {
        Binding(get: { layoutState.isGridView }, set: { layoutState.isGridView = $0 })
    }

    private var columnsCountBinding: Binding<Int> {
        Binding(get: { layoutState.columnsCount }, set: { layoutState.columnsCount = $0 })
    }

    @State private var items: [URL] = []
    @State private var showSearchBar = false
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var refreshKey = UUID() // For forcing view updates when sorting changes

    @State private var selectedFolder: URL? = nil
    @State private var previewItem: PreviewItem? = nil // For full-screen preview
    @State private var showServerStatus = false
    @State private var showCustomServerView = false
    @State private var showServerStopConfirmation = false
    @State private var serverStopAlertText = ""

    @ObservedObject private var menuCoordinator = MenuCoordinator()
    @ObservedObject private var serverManager: FileServerManager

    // Server configuration
    private let serverConfiguration: ServerConfiguration

    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.themeConfiguration) private var theme

    // MARK: - Init
    public init(
        folderURL: URL,
        titleName: Binding<String>,
        isRoot: Bool = true,
        initialRootURL: URL? = nil,
        serverConfiguration: ServerConfiguration = .default,
        viewConfiguration: ViewConfiguration = .default
    ) {
        self.folderURL = folderURL
        self.isRoot = isRoot
        self.initialRootURL = initialRootURL ?? folderURL // Use provided root or current folder as root
        _titleName = titleName
        self.serverConfiguration = serverConfiguration
        self.viewConfiguration = viewConfiguration
        self.serverManager = FileServerManager(serverConfiguration: serverConfiguration)

        // Seed local shared state from configuration. Only read when this
        // instance is the root; pushed children inherit via environment and
        // never touch their own local instance.
        let initialIsGrid: Bool
        switch viewConfiguration.viewMode {
        case .listView:
            initialIsGrid = false
        case .gridView:
            initialIsGrid = true
        case .both:
            initialIsGrid = viewConfiguration.startsInGridView
        }

        self._localLayoutState = State(initialValue: LayoutState(
            isGridView: initialIsGrid,
            columnsCount: viewConfiguration.gridConfiguration.columnsCount
        ))
    }

    // MARK: - Body
    public var body: some View {
        // Reading `layoutStateTick` here makes SwiftUI rebuild body whenever
        // the tick is bumped by `.onReceive(layoutState.objectWillChange)`.
        // Without this, @State reference-type mutations wouldn't redraw us.
        let _ = layoutStateTick

        return Group {
            if #available(iOS 14.0, *) {
                FileBrowserContent()
                    .toast()
                    .onAppear(perform: loadItems)
                    .onChange(of: columnsCount) { newValue in
                        // Ensure columnsCount stays within configured bounds
                        let clampedValue = viewConfiguration.gridConfiguration.clampColumnCount(newValue)
                        if clampedValue != newValue {
                            columnsCount = clampedValue
                        }
                    }
                    .onChange(of: isGridView) { newValue in
                        // Ensure view mode respects configuration
                        switch viewConfiguration.viewMode {
                        case .listView:
                            if newValue { isGridView = false }
                        case .gridView:
                            if !newValue { isGridView = true }
                        case .both:
                            // Allow any value for .both mode
                            break
                        }
                    }
                    .navigationBarBackButtonHidden(true)
                    .sheet(isPresented: $menuCoordinator.showShareSheet) {
                        ShareSheet(items: menuCoordinator.shareItems)
                    }

            } else {
                FileBrowserContent()
                    .toast()
                    .onAppear(perform: loadItems)
                    .navigationBarBackButtonHidden(true)
                    .sheet(isPresented: $menuCoordinator.showShareSheet) {
                        ShareSheet(items: menuCoordinator.shareItems)
                    }
            }
        }
        .onReceive(layoutState.objectWillChange) { _ in
            layoutStateTick &+= 1
        }
    }

    // Content View (using environment theme)
    @ViewBuilder
    private func FileBrowserContent() -> some View {
        ZStack {
            // Background color to ensure no white gaps
            theme.backgroundColor
                .edgesIgnoringSafeArea(.all)

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
                    isGridView: isGridViewBinding,
                    columnsCount: columnsCountBinding,
                    showsSearch: !folderURL.isTrashFolder, // disable search in trash folder
                    viewConfiguration: viewConfiguration,
                    onBack: goBack
                )

                // Search Bar (disabled in trash folder)
                if showSearchBar && !folderURL.isTrashFolder {
                    searchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Content
                Group {
                    let currentItems = filteredItems()

                    if isSearching {
                        VStack {
                            Spacer()
                            if #available(iOS 14.0, *) {
                                ProgressView("Searching...")
                                    .foregroundColor(theme.primaryTextColor)
                            } else {
                                HStack {
                                    Text("Searching...")
                                        .foregroundColor(theme.primaryTextColor)
                                    Spacer()
                                }
                            }
                            Spacer()
                        }
                    } else if items.isEmpty || currentItems.isEmpty {
                        VStack {
                            Spacer()
                            // Inline empty state icon logic
                            Image(systemName: {
                                if !searchText.isEmpty {
                                    return "magnifyingglass"
                                } else {
                                    return "folder"
                                }
                            }())
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(theme.folderColor)

                            // Inline empty state message logic
                            Text({
                                if !searchText.isEmpty {
                                    return "No results found"
                                } else {
                                    return "Folder is Empty"
                                }
                            }())
                                .foregroundColor(theme.secondaryTextColor)
                                .font(.system(size: 20, weight: .regular))

                            Spacer()
                        }

                    } else if isGridView, #available(iOS 14.0, *) {
                        ScrollView {
                            fileGridView_iOS14Plus()
                        }
                        .background(theme.backgroundColor) // To match background color
                        .simultaneousGesture(gridMagnificationGesture())
                    } else {
                        ScrollView {
                            fileListView
                        }
                        .background(theme.backgroundColor) // To match background color
                    }
                }
                .background(theme.backgroundColor) // Fill the gap with theme background
                .animation(.default, value: isGridView)
                // Force view updates when sort options change
                .id(refreshKey)

                // Bottom Bar (hidden in trash folder)
                if !folderURL.isTrashFolder {
                    BottomBar(
                        onTrashTapped: navigateToTrashFolder,
                        onNewFolderTapped: showNewFolderDialog,
                        onSortTapped: showSortDialog,
                        onServerTapped: toggleServerView,
                        serverManager: serverManager,
                        serverConfiguration: serverConfiguration
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(theme.backgroundColor)
                }
            }

            // MARK: - Full-Screen QuickLook Preview
            if let previewItem = previewItem {
                FullScreenQuickLookPreview(
                    url: previewItem.url,
                    viewConfiguration: viewConfiguration,
                    onClose:{
                        self.previewItem = nil
                        // Don't reset search results when closing preview
                    }, title: previewItem.url.displayName
                )
            }

            // MARK: - Bottom Sheet Menu
            if menuCoordinator.isBottomSheetVisible {
                bottomSheetOverlay
                    .zIndex(100)
            }

            //Server Status Overlay
            if showServerStatus {
                serverStatusOverlay
                    .zIndex(99)
            }

            //Custom Server View Overlay
            if showCustomServerView {
                customServerViewOverlay
                    .zIndex(99)
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

            if menuCoordinator.showNewFolderView {
                AlertPrompt(title: "Create New Folder", placeHolder: "Folder Name", okButtonText: "Create", name: $menuCoordinator.newFolderName, isPresented: $menuCoordinator.showNewFolderView) {
                    performCreateFolder()
                } onCancel: {
                    menuCoordinator.resetVar()
                }
            }

            if menuCoordinator.showMoveView {
                moveViewOverlay
                    .zIndex(200)
                    .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
            }

            if menuCoordinator.showFileInfo {
                fileInfoViewOverlay
                    .zIndex(300)
                    .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
            }

            if menuCoordinator.showLockSetup {
                lockSetupOverlay
                    .zIndex(400)
                    .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
            }

            if menuCoordinator.showUnlock {
                unlockOverlay
                    .zIndex(500)
                    .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
            }

            if menuCoordinator.showRestoreLocationPicker {
                restoreLocationPickerOverlay
                    .zIndex(600)
                    .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
            }

            // Server Stop Confirmation
            if showServerStopConfirmation {
                AlertPrompt(
                    title: "Server is running. Do you want to stop the server and close the app?",
                    okButtonText: "Stop & Close",
                    cancelButtonText: "Cancel",
                    name: $serverStopAlertText,
                    isPresented: $showServerStopConfirmation
                ) {
                    // Stop server and close
                    serverManager.stopServer()
                    presentationMode.wrappedValue.dismiss()
                } onCancel: {
                    // Just dismiss the alert, stay in app
                }
            }

            // Search Unlock Confirmation
            if menuCoordinator.showSearchUnlockConfirmation {
                AlertPrompt(
                    title: menuCoordinator.searchUnlockTitle,
                    okButtonText: "Unlock",
                    cancelButtonText: "Cancel",
                    disableCancelButton: false,
                    name: $serverStopAlertText,
                    isPresented: $menuCoordinator.showSearchUnlockConfirmation,
                    onOK: {
                        menuCoordinator.executeSearchUnlockAction()
                    },
                    onCancel: {
                        menuCoordinator.showSearchUnlockConfirmation = false
                    }
                )
            }

            // Toast notifications are now handled by the static Toast utility via the .toast() modifier
        }
        .toast()
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
        } catch FileUtils.FileError.failedToRename(let oldPath, let newPath, underlyingError: let underlyingError) {
            menuCoordinator.showRenameErrorMessage = "Error while renaming \(oldName) to \(newName)"
            menuCoordinator.shouldShowErrorMessage = true
            print("Failed to rename:", oldPath, "to", newPath, underlyingError.localizedDescription)
        } catch {
            print("Unexpected error:", error)
        }
    }

    //Move Functions
    private func performMove() {
        guard let sourceFile = menuCoordinator.currentMoveSourcePath,
              let destinationFolder = menuCoordinator.selectedDestinationFolder else {
            return
        }

        //Ignoring move operaion when source and destination folders are same
        let sourceParent = sourceFile.deletingLastPathComponent()
        if sourceParent == destinationFolder {
            menuCoordinator.showRenameErrorMessage = "Item is already in this folder"
            menuCoordinator.shouldShowErrorMessage = true
            menuCoordinator.showMoveView = false // Close the move picker
            return
        }

        do {
            try FileUtils.move(
                fileName: sourceFile.lastPathComponent,
                from: sourceParent,
                to: destinationFolder
            )

            menuCoordinator.resetVar()
            loadItems() // Refresh the current view
        } catch FileUtils.FileError.sourceNotFound(_) {
            menuCoordinator.showRenameErrorMessage = "Source file does not exist"
            menuCoordinator.shouldShowErrorMessage = true
            menuCoordinator.showMoveView = false // Close the move picker
        } catch FileUtils.FileError.destinationAlreadyExists(_) {
            menuCoordinator.showRenameErrorMessage = "A file with this name already exists in the destination folder"
            menuCoordinator.shouldShowErrorMessage = true
            menuCoordinator.showMoveView = false // Close the move picker
        } catch {
            menuCoordinator.showRenameErrorMessage = "Failed to move: \(error.localizedDescription)"
            menuCoordinator.shouldShowErrorMessage = true
            menuCoordinator.showMoveView = false // Close the move picker
        }
    }

    //Get Info Functions
    private func performGetInfo() {
        guard let selectedFile = menuCoordinator.selectedFile else { return }

        if let fileInfo = FileUtils.getFileInfo(for: selectedFile) {
            menuCoordinator.fileInfo = fileInfo
            menuCoordinator.showFileInfo = true
        } else {
            menuCoordinator.showRenameErrorMessage = "Unable to get file information"
            menuCoordinator.shouldShowErrorMessage = true
        }
    }

    //Trash Functions
    private func performMoveToTrash() {
        guard let selectedFile = menuCoordinator.selectedFile else { return }

        do {
            let originalFileURL = selectedFile
            let fileName = selectedFile.lastPathComponent

            // Move to trash and get the actual trash location
            let trashedFileURL = try FileUtils.moveToTrash(fileURL: selectedFile, in: folderURL)

            // Show undo toast using the static Toast utility
            Toast.showInfo(
                "Moved \(fileName) to Trash",
                buttonTitle: "UNDO"
            ) {
                // Hide the toast first
                Toast.hide()

                // Perform undo action
                do {
                    let originalDirectory = originalFileURL.deletingLastPathComponent()
                    try FileUtils.restoreFromTrash(fileURL: trashedFileURL, to: originalDirectory)
                    loadItems() // Refresh the view to show the restored item
                } catch {
                    menuCoordinator.showRenameErrorMessage = "Failed to undo: \(error.localizedDescription)"
                    menuCoordinator.shouldShowErrorMessage = true
                }
            }

            menuCoordinator.resetVar()
            loadItems() // Refresh the current view to remove the deleted item

        } catch FileUtils.FileError.sourceNotFound(_) {
            menuCoordinator.showRenameErrorMessage = "File does not exist"
            menuCoordinator.shouldShowErrorMessage = true
        } catch {
            menuCoordinator.showRenameErrorMessage = "Failed to move to trash: \(error.localizedDescription)"
            menuCoordinator.shouldShowErrorMessage = true
        }
    }

    private func performRestoreFromTrash() {
        guard let selectedFile = menuCoordinator.selectedFile else { return }
        //It will prompt the file picker to select the destination folder
        menuCoordinator.showRestoreLocationPicker(for: selectedFile, initialRootURL: initialRootURL)
    }

    // performUndo method removed - undo functionality is now handled inline with the toast button action

    private func performRestoreToLocation() {
        guard let sourceFile = menuCoordinator.restoreSourceFile,
              let destinationFolder = menuCoordinator.selectedRestoreDestination else {
            return
        }

        do {
            try FileUtils.restoreFromTrash(fileURL: sourceFile, to: destinationFolder)

            menuCoordinator.resetVar()
            loadItems() // Refresh the current view to remove the restored item
        } catch {
            menuCoordinator.showRenameErrorMessage = "Failed to restore to selected location: \(error.localizedDescription)"
            menuCoordinator.shouldShowErrorMessage = true
            menuCoordinator.showRestoreLocationPicker = false
        }
    }

    private func performPermanentDelete() {
        guard let selectedFile = menuCoordinator.selectedFile else { return }

        do {
            try FileManager.default.removeItem(at: selectedFile)

            menuCoordinator.resetVar()
            loadItems() // Refresh the current view to remove the deleted item
        } catch {
            menuCoordinator.showRenameErrorMessage = "Failed to permanently delete: \(error.localizedDescription)"
            menuCoordinator.shouldShowErrorMessage = true
        }
    }
    private func clearSearchText() {
        searchText = ""
        searchResults = []
        isSearching = false
    }
    private func closeSearch() {
        searchText = ""
        searchResults = []
        isSearching = false
        showSearchBar = false
    }
    // MARK: - Destination View
    @ViewBuilder
    private func destinationView() -> some View {
        if let folder = selectedFolder {
            FileBrowserLayout(
                folderURL: folder,
                titleName: .constant(folder.displayName),
                isRoot: false,
                initialRootURL: initialRootURL,
                serverConfiguration: serverConfiguration,
                viewConfiguration: viewConfiguration
            )
            .environment(\.layoutState, layoutState)
        }
    }

    private func goBack() {
        // Check if this is the root view and server is running
        if isRoot && serverManager.isServerRunning {
            showServerStopConfirmation = true
        } else {
            // Normal back navigation
            presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            TextField("Search files...", text: $searchText)
                .padding(10)
                .background(theme.secondaryBackgroundColor)
                .cornerRadius(8)
                .modifier(SearchTextChangeModifier(searchText: searchText, searchUtil: searchUtil, folderURL: folderURL) { results, isSearching in
                    self.searchResults = results
                    self.isSearching = isSearching
                })
            // Clear search text button
            Button(action: {
                clearSearchText()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.secondaryTextColor)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
            // Stop/Close search button
            Button(action: {
                closeSearch()
            }) {
                Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                    .foregroundColor(theme.secondaryTextColor)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 8)
        .background(theme.backgroundColor)
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
                        onTap: { selectedItem in
                            if isSearchMode() {
                                searchUtil.handleSearchResultTap(selectedItem, from: searchResults, menuCoordinator: menuCoordinator) { item in
                                    self.handleItemTap(item)
                                }
                            } else {
                                handleItemTap(selectedItem)
                            }
                        },
                        searchContext: isSearchMode() ? searchUtil.getSearchContext(for: url, from: searchResults) : nil,
                        isInLockedFolder: isSearchMode() ? searchUtil.isFileInLockedFolder(for: url, from: searchResults) : false,
                        viewConfiguration: viewConfiguration
                    )
                    .frame(width: itemWidth, height: itemWidth)
                }
            }
            .id("grid-\(menuCoordinator.sortBy)-\(menuCoordinator.sortOrder)")
            .padding(.horizontal, spacing)
            .padding(.top, 10)
        } else {
            fileListView
        }
    }

    // MARK: - List View (Updated to handle search and regular modes)
    private var fileListView: some View {
        VStack(spacing: 0) {
            ForEach(filteredItems(), id: \.self) { url in
                FileRowView(
                    url: url,
                    layout: .list(thumbnailSize: 44),
                    menuCoordinator: menuCoordinator,
                    onTap: { selectedItem in
                        if isSearchMode() {
                            searchUtil.handleSearchResultTap(selectedItem, from: searchResults, menuCoordinator: menuCoordinator) { item in
                                self.handleItemTap(item)
                            }
                        } else {
                            handleItemTap(selectedItem)
                        }
                    },
                    searchContext: isSearchMode() ? searchUtil.getSearchContext(for: url, from: searchResults) : nil,
                    isInLockedFolder: isSearchMode() ? searchUtil.isFileInLockedFolder(for: url, from: searchResults) : false,
                    viewConfiguration: viewConfiguration
                )
            }
        }
        .id("list-\(menuCoordinator.sortBy)-\(menuCoordinator.sortOrder)")
        .padding(.top, 10)
    }

    //Navigation Handler
    private func handleItemTap(_ url: URL) {
        LockAuthenticator.performTapWithLockCheck(
            for: url,
            menuCoordinator: menuCoordinator
        ) {
            self.proceedWithItemTap(url)
        }
    }

    //Lock Check Helper for Menu Actions
    private func performActionWithLockCheck(_ action: @escaping () -> Void) {
        guard let selectedFile = menuCoordinator.selectedFile else { return }

        LockAuthenticator.performMenuActionWithLockCheck(
            for: selectedFile,
            menuCoordinator: menuCoordinator,
            action: action
        )
    }

    private func proceedWithItemTap(_ url: URL) {
        if url.isDirectory {
            selectedFolder = url
        } else {
            previewItem = PreviewItem(url: url) // trigger full-screen preview
        }
    }

    private func navigateToTrashFolder() {
        let trashFolder = FileUtils.getTrashFolder()
        selectedFolder = trashFolder
    }

    private func showNewFolderDialog() {
        menuCoordinator.showNewFolderView = true
    }

    private func showSortDialog() {
        menuCoordinator.selectedFile = nil // Ensure file operations are hidden when showing sort
        menuCoordinator.showSortView = true
        menuCoordinator.isBottomSheetVisible = true
    }
    private func updateSortOption(_ option: SortOption) {
        if menuCoordinator.sortBy == option {
            menuCoordinator.sortOrder = menuCoordinator.sortOrder == .ascending ? .descending : .ascending
        } else {
            menuCoordinator.sortBy = option
        }
        refreshKey = UUID()
    }

    //Server Functions
    private func toggleServerView() {
        switch serverConfiguration.serverButtonMode {
        case .show:
            showServerStatus.toggle()
        case .showCustomView:
            showCustomServerView.toggle()
        case .hidden:
            break // Should not be called since button is hidden
        }
    }

    private func startServer() {
        serverManager.startServer(rootDirectory: initialRootURL)
    }

    private func stopServer() {
        serverManager.stopServer()
    }

    private func performCreateFolder() {
        do {
            let folderName = menuCoordinator.newFolderName // Store folder name before reset
            try FileUtils.createFolder(named: folderName, in: folderURL)
            menuCoordinator.resetVar()
            loadItems() // Refresh to show the new folder
            // Show success toast with the stored folder name
            Toast.showSuccess("Created folder '\(folderName)'")
        } catch FileUtils.FileError.destinationAlreadyExists(_) {
            menuCoordinator.showRenameErrorMessage = "A folder named '\(menuCoordinator.newFolderName)' already exists"
            menuCoordinator.shouldShowErrorMessage = true
        } catch {
            menuCoordinator.showRenameErrorMessage = "Failed to create folder: \(error.localizedDescription)"
            menuCoordinator.shouldShowErrorMessage = true
        }
    }

    // MARK: - Grid Zoom Gesture
    private func gridMagnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onEnded { scale in
                if scale > 1.05 {
                    columnsCount = max(viewConfiguration.gridConfiguration.minColumnsCount, columnsCount - 1)
                }
                else if scale < 0.95 {
                    columnsCount = min(viewConfiguration.gridConfiguration.maxColumnsCount, columnsCount + 1)
                }
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

    private func isSearchMode() -> Bool {
        return !searchText.isEmpty
    }


    private func filteredItems() -> [URL] {
        if !searchText.isEmpty {
            // Return search results
            return searchResults.map { $0.url }
        } else {
            // Return current folder items
            let filtered = searchText.isEmpty ? items : items.filter {
                $0.lastPathComponent.localizedCaseInsensitiveContains(searchText)
            }
            return sortItems(filtered)
        }
    }
    private func sortItems(_ items: [URL]) -> [URL] {
        return items.sorted { (url1, url2) in
            // Always put directories first
            let isDir1 = url1.isDirectory
            let isDir2 = url2.isDirectory
            if isDir1 != isDir2 {
                return isDir1
            }
            // Sort by the selected criteria
            let result: Bool
            switch menuCoordinator.sortBy {
            case .name:
                result = url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
            case .dateModified:
                result = FileUtils.getModificationDate(for: url1) < FileUtils.getModificationDate(for: url2)
            case .size:
                result = FileUtils.getFileSize(for: url1) < FileUtils.getFileSize(for: url2)
            }
            return menuCoordinator.sortOrder == .ascending ? result : !result
        }
    }
    // MARK: - Bottom Sheet Overlay
    private var bottomSheetOverlay: some View {
        ZStack {
            // Dim background
            theme.overlayBackgroundColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    menuCoordinator.hideBottomSheet()
                }

            // Bottom sheet
            VStack {
                Spacer()

                if menuCoordinator.showSortView {
                    // Sort options in bottom sheet
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Sort Files")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(theme.primaryTextColor)

                            Spacer()

                            Button(action: {
                                menuCoordinator.hideBottomSheet()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.closeButtonColor)
                                    .frame(width: 30, height: 30)
                                    .background(theme.secondaryBackgroundColor)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        Divider()

                        // Sort options
                        VStack(spacing: 8) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                UIHelpers.sortActionButton(for: option, menuCoordinator: menuCoordinator, theme: theme) {
                                    updateSortOption(option)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .background(theme.backgroundColor)
                    .cornerRadius(16)
                } else if let selectedFile = menuCoordinator.selectedFile {
                    VStack(spacing: 0) {
                        // File info header with cancel button
                        HStack(spacing: 12) {
                            // File icon and name on the left
                            HStack(spacing: 12) {
                                Image(systemName: selectedFile.isDirectory ? "folder.fill" : "doc.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(selectedFile.isDirectory ? theme.folderColor : theme.fileColor)

                                Text(selectedFile.displayName)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(theme.primaryTextColor)
                            }
                            Spacer()
                            // Cancel button on the right
                            Button {
                                menuCoordinator.hideBottomSheet()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.closeButtonColor)
                                    .frame(width: 30, height: 30)
                                    .background(theme.secondaryBackgroundColor)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        .padding(.horizontal, 20)

                        Divider()

                        // For trash folder, show only Restore and Delete Permanently options
                        if folderURL.isTrashFolder {
                            actionButton("Restore", icon: "arrow.uturn.backward") {
                                menuCoordinator.hideBottomSheet()
                                performRestoreFromTrash()
                            }
                            actionButton("Delete Permanently", icon: "trash.fill", isDestructive: true) {
                                menuCoordinator.hideBottomSheet()
                                performPermanentDelete()
                            }
                        } else {
                            // Regular folder actions
                            actionButton("Rename", icon: "pencil") {
                                menuCoordinator.hideBottomSheet()
                                performActionWithLockCheck {
                                    menuCoordinator.showRenameView = true
                                    menuCoordinator.newFileName = selectedFile.lastPathComponent
                                }
                            }

                            actionButton("Move", icon: "folder") {
                                menuCoordinator.hideBottomSheet()
                                performActionWithLockCheck {
                                    if let selectedFile = menuCoordinator.selectedFile {
                                        menuCoordinator.currentMoveSourcePath = selectedFile
                                        menuCoordinator.showMoveView = true
                                    }
                                }
                            }

                            actionButton("Get Info", icon: "info.circle") {
                                menuCoordinator.hideBottomSheet()
                                performActionWithLockCheck {
                                    performGetInfo()
                                }
                            }

                            // Lock/Unlock actions
                            if LockManager.shared.isFileLocked(selectedFile.path) {
                                actionButton("Unlock", icon: "lock.open") {
                                    menuCoordinator.hideBottomSheet()
                                    // For permanent unlock, we bypass lock check and directly handle unlock logic
                                    if !LockManager.shared.hasCustomPIN(selectedFile.path) {
                                        LockManager.shared.authenticateWithBiometrics { success in
                                            if success {
                                                LockManager.shared.permanentlyRemoveLock(from: selectedFile.path)
                                                loadItems()
                                            } else {
                                                menuCoordinator.showUnlockView(for: selectedFile, isPermanent: true)
                                            }
                                        }
                                    } else {
                                        menuCoordinator.showUnlockView(for: selectedFile, isPermanent: true)
                                    }
                                }
                            } else {
                                actionButton("Lock", icon: "lock") {
                                    menuCoordinator.showLockSetupView(for: selectedFile)
                                }
                            }

                            if !selectedFile.isDirectory {
                                actionButton("Share", icon: "square.and.arrow.up") {
                                    menuCoordinator.hideBottomSheet()
                                    performActionWithLockCheck {
                                        menuCoordinator.shareItems = [selectedFile]
                                        menuCoordinator.showShareSheet = true
                                    }
                                }
                            }

                            actionButton("Move to Trash", icon: "trash", isDestructive: true) {
                                menuCoordinator.hideBottomSheet()
                                performActionWithLockCheck{
                                    self.performMoveToTrash()
                                }
                            }
                        }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 20)
                    }
                    .background(theme.backgroundColor)
                    .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }

    @ViewBuilder
    private func actionButton(_ title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isDestructive ? theme.errorColor : theme.bottomOverlayIconColor)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(isDestructive ? theme.errorColor : theme.bottomOverlayTextColor)

                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    //Move View Overlay
    private var moveViewOverlay: some View {
        ZStack {
            theme.overlayBackgroundColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    menuCoordinator.resetVar()
                }

            VStack {
                Spacer()

                MovePickerWrapper(
                    initialRootURL: initialRootURL,
                    menuCoordinator: menuCoordinator,
                    onMove: performMove
                )
                .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }

    //Server Status Overlay
    private var serverStatusOverlay: some View {
        ZStack {
            // Dim background
            theme.overlayBackgroundColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showServerStatus = false
                }

            // Server status sheet
            VStack {
                Spacer()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("File Server")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.primaryTextColor)

                        Spacer()

                        Button(action: {
                            showServerStatus = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.closeButtonColor)
                                .frame(width: 30, height: 30)
                                .background(theme.secondaryBackgroundColor)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)

                    Divider()

                    // Server Status
                    VStack(spacing: 16) {
                        ServerStatusView(serverManager: serverManager)

                        // Server Controls
                        HStack(spacing: 16) {
                            Button(action: {
                                if serverManager.isServerRunning {
                                    serverManager.stopServer()
                                } else {
                                    serverManager.startServer(rootDirectory: initialRootURL)
                                }
                            }) {
                                HStack {
                                    Image(systemName: serverManager.isServerRunning ? "stop.fill" : "play.fill")
                                        .foregroundColor(theme.textOnPrimaryColor)
                                    Text(serverManager.isServerRunning ? "Stop Server" : "Start Server")
                                        .foregroundColor(theme.textOnPrimaryColor)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(serverManager.isServerRunning ? theme.errorColor : theme.primaryColor)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Bottom safe area
                    Rectangle()
                        .fill(theme.backgroundColor)
                        .frame(height: 20)
                }
                .background(theme.backgroundColor)
                .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    //Custom Server View Overlay
    private var customServerViewOverlay: some View {
        ZStack {
            // Dim background
            theme.overlayBackgroundColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showCustomServerView = false
                }

            // Custom server view
            if case .showCustomView(let customViewProvider) = serverConfiguration.serverButtonMode {
                VStack {
                    Spacer()

                    customViewProvider {
                        // Dismiss callback - this allows the custom view to close the overlay
                        showCustomServerView = false
                    }
                    .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - File Info View Overlay
    private var fileInfoViewOverlay: some View {
        ZStack {
            theme.overlayBackgroundColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    menuCoordinator.resetVar()
                }

            VStack {
                Spacer()

                if let fileInfo = menuCoordinator.fileInfo {
                    VStack(spacing: 0) {
                        // Header with close button
                        HStack {
                            Text(fileInfo.isDirectory ? "Folder Information" : "File Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.primaryTextColor)

                            Spacer()

                            Button {
                                menuCoordinator.resetVar()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.closeButtonColor)
                                    .frame(width: 30, height: 30)
                                    .background(theme.secondaryBackgroundColor)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        .padding(.horizontal, 20)

                        Divider()

                        // File info content
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // File name and icon
                                HStack(spacing: 12) {
                                    Image(systemName: fileInfo.isDirectory ? "folder.fill" : "doc.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(fileInfo.isDirectory ? theme.folderColor : theme.fileColor)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(fileInfo.name)
                                            .font(.system(size: 40))
                                            .fontWeight(.medium)
                                            .foregroundColor(theme.primaryTextColor)

                                        Text(fileInfo.fileType)
                                            .font(.caption)
                                            .foregroundColor(theme.bottomOverlayTextColor)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                                Divider()
                                    .padding(.horizontal, 20)

                                // File details
                                VStack(alignment: .leading, spacing: 12) {
                                    if !fileInfo.isDirectory {
                                        fileInfoRow("Size", value: fileInfo.formattedSize)
                                    } else {
                                        // For directories, show item count
                                        let itemCount = getDirectoryItemCount(for: fileInfo.path)
                                        fileInfoRow("Items", value: "\(itemCount) items")
                                    }

                                    fileInfoRow("Created", value: fileInfo.formattedCreationDate)
                                    fileInfoRow("Modified", value: fileInfo.formattedModificationDate)

                                    // Path (scrollable for long paths)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Path")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(theme.primaryTextColor)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            Text(getRelativePath(for: fileInfo.path))
                                                .font(.caption)
                                                .foregroundColor(theme.bottomOverlayTextColor)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 30)
                            }
                        }
                        .frame(maxHeight: 400)
                    }
                    .background(theme.backgroundColor)
                    .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }

    // Helper for file info rows
    private func fileInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryTextColor)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundColor(theme.bottomOverlayTextColor)

            Spacer()
        }
    }

    // Helper to get directory item count
    private func getDirectoryItemCount(for path: String) -> Int {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        do {
            let items = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            return items.count
        } catch {
            return 0
        }
    }

    // Helper to get relative path from root( initialRootURL path )
    private func getRelativePath(for absolutePath: String) -> String {
        let rootPath = initialRootURL.path
        let filePath = absolutePath

        // If the file path starts with root path, return the relative portion
        if filePath.hasPrefix(rootPath) {
            let relativePath = String(filePath.dropFirst(rootPath.count))
            // Remove leading slash if present and return, or return root indicator if empty
            let cleanPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
            return cleanPath.isEmpty ? "/" : "/\(cleanPath)"
        }

        // Fallback to absolute path if not under root
        return absolutePath
    }

    private var lockSetupOverlay: some View {
        ZStack {
            theme.overlayBackgroundColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    menuCoordinator.hideLockViews()
                }

            if let file = menuCoordinator.pendingLockFile {
                LockSetupView(
                    filePath: file.path,
                    fileName: file.lastPathComponent,
                    isDirectory: file.isDirectory,
                    isPresented: $menuCoordinator.showLockSetup
                ) {
                    menuCoordinator.hideLockViews()
                }
            }
        }
    }
    private var unlockOverlay: some View {
        ZStack {
            // Semi-transparent background
            theme.overlayBackgroundColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    menuCoordinator.hideLockViews()
                }

            if let file = menuCoordinator.pendingLockFile {
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height

                // Centered popup container
                VStack {
                    Spacer()

                    UnlockView(
                        filePath: file.path,
                        fileName: file.lastPathComponent,
                        isPresented: $menuCoordinator.showUnlock,
                        onUnlock: {
                            // Check if there's a pending action before clearing state
                            let hadPendingAction = menuCoordinator.hasPendingAction
                            let isPermanent = menuCoordinator.isPermanentUnlock

                            // Execute any pending action first (from menu actions)
                            menuCoordinator.executePendingAction()
                            menuCoordinator.hideLockViews()

                            // Refresh items if it was a permanent unlock to update lock icons
                            if isPermanent {
                                loadItems()
                            }

                            // If no pending action and not a permanent unlock, proceed with file navigation
                            if !hadPendingAction && !isPermanent {
                                proceedWithItemTap(file)
                            }
                        },
                        isPermanentUnlock: menuCoordinator.isPermanentUnlock
                    )
                    .frame(maxWidth: screenWidth * 0.75, maxHeight: screenHeight * 0.7)
                    .background(theme.backgroundColor)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                    .transition(.scale.combined(with: .opacity))

                    Spacer()
                }
                .padding(20)
            }
        }
    }

    //Restore Location Picker
    private var restoreLocationPickerOverlay: some View {
        ZStack {
            theme.overlayBackgroundColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    menuCoordinator.resetVar()
                }

            VStack {
                Spacer()

                RestoreLocationPickerWrapper(
                    initialRootURL: initialRootURL,
                    menuCoordinator: menuCoordinator,
                    onRestore: performRestoreToLocation
                )
                .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }

    // The hardcoded undoToastView has been replaced by the reusable Toast utility system
// MARK: - To show Share option
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Full Screen QuickLook Preview
struct FullScreenQuickLookPreview: UIViewControllerRepresentable {

    let url: URL
    let viewConfiguration: ViewConfiguration
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
                viewConfiguration: viewConfiguration,
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

//Move Picker Wrapper to handle delegate
private struct MovePickerWrapper: View {
    let initialRootURL: URL
    @ObservedObject var menuCoordinator: MenuCoordinator
    let onMove: () -> Void

    @State private var delegate: MoveFolderPickerDelegate?

    var body: some View {
        FolderPickerView(
            configuration: FolderPickerConfiguration(
                title: "Move to Folder",
                allowedRootPath: initialRootURL,
                showCancelButton: true,
                confirmButtonTitle: "Move",
                lockExpandable: true,
                defaultSelectedPaths: getLastMoveFolderPath()
            ),
            delegate: delegate
        )
        .onAppear {
            if delegate == nil {
                delegate = MoveFolderPickerDelegate(
                    onFolderSelected: { url in
                        menuCoordinator.selectedDestinationFolder = url
                        onMove()
                    },
                    onCancel: {
                        menuCoordinator.resetVar()
                    }
                )
            }
        }
    }
    private func getLastMoveFolderPath() -> [URL]? {
        guard let pathString = UserDefaults.standard.lastMoveFolderPath else { return nil }
        let url = URL(fileURLWithPath: pathString)
        // Only return if the path still exists and is within the allowed root
        if FileManager.default.fileExists(atPath: pathString) &&
           pathString.hasPrefix(initialRootURL.path) {
            return [url]
        }
        return nil
    }
}

//Restore Location Picker Wrapper to handle delegate
private struct RestoreLocationPickerWrapper: View {
    let initialRootURL: URL
    @ObservedObject var menuCoordinator: MenuCoordinator
    let onRestore: () -> Void

    @State private var delegate: RestoreFolderPickerDelegate?

    var body: some View {
        FolderPickerView(
            configuration: FolderPickerConfiguration(
                title: "Choose Restore Location",
                allowedRootPath: initialRootURL,
                showCancelButton: true,
                confirmButtonTitle: "Restore",
                lockExpandable: true,
                defaultSelectedPaths: getLastRestoreFolderPath()
            ),
            delegate: delegate
        )
        .onAppear {
            if delegate == nil {
                delegate = RestoreFolderPickerDelegate(
                    onFolderSelected: { url in
                        menuCoordinator.selectedRestoreDestination = url
                        onRestore()
                    },
                    onCancel: {
                        menuCoordinator.resetVar()
                    }
                )
            }
        }
    }
    private func getLastRestoreFolderPath() -> [URL]? {
        guard let pathString = UserDefaults.standard.lastRestoreFolderPath else { return nil }
        let url = URL(fileURLWithPath: pathString)
        // Only return if the path still exists and is within the allowed root
        if FileManager.default.fileExists(atPath: pathString) &&
           pathString.hasPrefix(initialRootURL.path) {
            return [url]
        }
        return nil
    }
}
}
