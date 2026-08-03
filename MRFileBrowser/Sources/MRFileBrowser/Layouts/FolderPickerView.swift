import SwiftUI
import UIKit

//Folder Picker Delegate Protocol
public protocol FolderPickerDelegate: AnyObject {
    func folderPicker(_ picker: FolderPickerView, selectItems urls: [URL])
    func folderPickerDidCancel(_ picker: FolderPickerView)
}

//Folder Picker Lock Display Mode
public enum LockDisplayMode {
    case dontShow
    case showAsNormal
    case showAsLocked
}

//Folder Picker Lock Selectability Mode
public enum LockSelectabilityMode {
    case selectable
    case nonSelectable
}

//Folder Picker Item Type
public enum ItemType {
    case folderOnly
    case folderAndFile
    case fileOnly
}

//Folder Picker Configuration
public struct FolderPickerConfiguration {
    public let title: String
    public let allowedRootPath: URL
    public let showCancelButton: Bool
    public let confirmButtonTitle: String
    public let lockDisplayMode: LockDisplayMode
    public let lockSelectabilityMode: LockSelectabilityMode
    public let lockExpandable: Bool
    public let itemType: ItemType
    public let defaultSelectedPaths: [URL]?
    public let allowMultipleSelection: Bool
    public let allowedExtensions: Set<String>?

    public init(
        title: String = "Choose Folder",
        allowedRootPath: URL,
        showCancelButton: Bool = true,
        confirmButtonTitle: String = "Select",
        lockDisplayMode: LockDisplayMode = .showAsLocked,
        lockSelectabilityMode: LockSelectabilityMode = .selectable,
        lockExpandable: Bool = false,
        itemType: ItemType = .folderOnly,
        defaultSelectedPaths: [URL]? = nil,
        allowMultipleSelection: Bool = false,
        allowedExtensions: Set<String>? = nil
    ) {
        self.title = title
        self.allowedRootPath = allowedRootPath
        self.showCancelButton = showCancelButton
        self.confirmButtonTitle = confirmButtonTitle
        self.lockDisplayMode = lockDisplayMode
        self.lockSelectabilityMode = lockSelectabilityMode
        // Force lockExpandable to false when lockSelectabilityMode is nonSelectable
        self.lockExpandable = lockSelectabilityMode == .nonSelectable ? false : lockExpandable
        self.itemType = itemType
        self.defaultSelectedPaths = defaultSelectedPaths
        self.allowMultipleSelection = allowMultipleSelection
        self.allowedExtensions = allowedExtensions
    }
}

//Folder Picker SwiftUI Main View
public struct FolderPickerView: View {

    public weak var delegate: FolderPickerDelegate?
    public let configuration: FolderPickerConfiguration

    // Keyed by `.path` rather than the `URL` itself - `URL` equality also factors in
    // internal flags like `hasDirectoryPath`, which can diverge between a URL built from
    // an external path string and one enumerated via FileManager, even when `.path` is
    // identical. Comparing plain paths matches how the rest of this file already resolves paths.
    @State private var selectedItems: Set<String> = []
    @State private var expandedFolders: Set<String> = []
    @State private var folderTree: [FolderNode] = []
    @State private var viewHeight: CGFloat = 400
    @Environment(\.themeConfiguration) private var theme

    //Init function
    public init(
        configuration: FolderPickerConfiguration,
        delegate: FolderPickerDelegate? = nil
    ) {
        self.configuration = configuration
        self.delegate = delegate
    }

    // View's Body
    public var body: some View {
        VStack(spacing: 0) {
            //Drag handle for resizing
            RoundedRectangle(cornerRadius: 2.5)
                .fill(theme.secondaryTextColor.opacity(0.6))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            HStack {
                if configuration.showCancelButton {
                    Button("Cancel") {
                        delegate?.folderPickerDidCancel(self)
                    }
                    .foregroundColor(theme.closeButtonColor)
                }

                Spacer()

                Text(configuration.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.primaryTextColor)

                Spacer()

                Button(configuration.confirmButtonTitle) {
                    if !selectedItems.isEmpty {
                        delegate?.folderPicker(self, selectItems: selectedItems.map { URL(fileURLWithPath: $0) })
                    }
                }
                .foregroundColor(hasSelection ? theme.primaryColor : theme.primaryTextColor.opacity(0.3))
                .font(.system(size: 17, weight: hasSelection ? .bold : .regular))
                .disabled(!hasSelection)
            }
            .padding()

            Divider()

            //Folder Tree List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(folderTree, id: \.id) { node in
                        folderTreeRow(node)
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxHeight: viewHeight - 120) //Account for header and drag handle
        }
        .frame(maxWidth: .infinity)
        .background(theme.backgroundColor)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newHeight = viewHeight - value.translation.height
                    let minHeight: CGFloat = 250
                    let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.9
                    viewHeight = max(minHeight, min(maxHeight, newHeight))
                }
                .onEnded { _ in
                    //Ensure minimum height is maintained after drag ends
                    let minHeight: CGFloat = 250
                    let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.9

                    if viewHeight < minHeight {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewHeight = minHeight
                        }
                    } else if viewHeight > maxHeight {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewHeight = maxHeight
                        }
                    }
                }
        )
        .onAppear {
            loadFolderTree()
            setDefaultSelection()
        }
    }

    // to check if any selection exists
    private var hasSelection: Bool {
        return !selectedItems.isEmpty
    }

    private func loadFolderTree() {
        folderTree = createFolderTree(at: configuration.allowedRootPath)
    }

    // Helper method to check if file matches allowed extensions
    private func isFileAllowed(_ url: URL) -> Bool {
        // If no extension filter is set, allow all files
        guard let allowedExtensions = configuration.allowedExtensions else {
            return true
        }

        let fileExtension = url.pathExtension.lowercased()

        // Handle files with no extension
        if fileExtension.isEmpty {
            return allowedExtensions.contains("filewithnoextension")
        }

        // Check if extension is in allowed list (with or without dot prefix)
        return allowedExtensions.contains(fileExtension) || allowedExtensions.contains(".\(fileExtension)")
    }

    private func createFolderTree(at rootURL: URL) -> [FolderNode] {
        guard let rootNode = createChildNode(for: rootURL, level: 0) else { return [] }
        return [rootNode]
    }

    private func createChildNode(for url: URL, level: Int) -> FolderNode? {
        let fileManager = FileManager.default
        do {
            // Rebuild each entry from `url` (the exact URL this node was constructed with)
            // rather than trusting contentsOfDirectory's own URLs directly: on iOS, `/var`
            // is a symlink to `/private/var`, and contentsOfDirectory returns the resolved
            // `/private/var/...` form while allowedRootPath/defaultSelectedPaths (built via
            // FileManager.urls(for:in:)) stay in the unresolved `/var/...` form. That mismatch
            // makes node.url fail to match selectedItems/expandedFolders even when both
            // represent the same file. Rebuilding keeps every node in `url`'s own representation.
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).map { url.appendingPathComponent($0.lastPathComponent) }

            let subfolders = contents.filter { $0.isDirectory }
                .filter { subfolder in
                    // Filter out locked folders if display mode is dontShow
                    if configuration.lockDisplayMode == .dontShow {
                        return !LockManager.shared.isFileLocked(subfolder.path)
                    }
                    return true
                }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

            // Include files if itemType allows it
            var allItems = subfolders
            if configuration.itemType == .folderAndFile {
                let files = contents.filter { !$0.isDirectory }
                    .filter { file in
                        // Filter out locked files if display mode is dontShow
                        if configuration.lockDisplayMode == .dontShow {
                            return !LockManager.shared.isFileLocked(file.path)
                        }
                        return true
                    }
                    .filter { file in
                        // Apply file extension filtering
                        return isFileAllowed(file)
                    }
                    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                allItems.append(contentsOf: files)
                allItems.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            } else if configuration.itemType == .fileOnly {
                // For fileOnly, show folders for navigation but also show files
                let files = contents.filter { !$0.isDirectory }
                    .filter { file in
                        // Filter out locked files if display mode is dontShow
                        if configuration.lockDisplayMode == .dontShow {
                            return !LockManager.shared.isFileLocked(file.path)
                        }
                        return true
                    }
                    .filter { file in
                        // Apply file extension filtering
                        return isFileAllowed(file)
                    }
                    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                allItems.append(contentsOf: files)
                allItems.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            }

            // Determine if expand button should be shown based on itemType
            let hasExpandableItems: Bool
            if configuration.itemType == .folderAndFile {
                // Show expand button if there are any items (folders or files)
                hasExpandableItems = !allItems.isEmpty
            } else if configuration.itemType == .fileOnly {
                // Show expand button if there are any items (folders or files)
                hasExpandableItems = !allItems.isEmpty
            } else {
                // Show expand button only if there are subfolders
                hasExpandableItems = !subfolders.isEmpty
            }

            return FolderNode(
                url: url,
                level: level,
                hasSubfolders: hasExpandableItems,
                subfolders: allItems
            )
        } catch {
            return FolderNode(url: url, level: level, hasSubfolders: false, subfolders: [])
        }
    }

    private func toggleFolder(_ url: URL) {
        if expandedFolders.contains(url.path) {
            expandedFolders.remove(url.path)
        } else {
            expandedFolders.insert(url.path)
        }
    }
    private func setDefaultSelection() {
        guard let defaultPaths = configuration.defaultSelectedPaths, !defaultPaths.isEmpty else { return }

        var validPaths: [URL] = []
        var pathsToExpand: Set<URL> = []

        for defaultPath in defaultPaths {
            if let matchingPath = findBestMatchingPath(for: defaultPath) {
                validPaths.append(matchingPath)
                pathsToExpand.insert(matchingPath)
            }
        }

        // Apply selections based on mode
        if configuration.allowMultipleSelection {
            // Add all valid paths for multiple selection
            for path in validPaths {
                selectedItems.insert(path.path)
            }
        } else {
            // Use the first valid path for single selection
            if let firstPath = validPaths.first {
                selectedItems.insert(firstPath.path)
            }
        }

        // Expand paths to make selections visible
        for path in pathsToExpand {
            expandPathToFolder(path)
        }
    }
    private func findBestMatchingPath(for targetPath: URL) -> URL? {
        // First try to find exact match using simple file existence check
        if FileManager.default.fileExists(atPath: targetPath.path) &&
           targetPath.path.hasPrefix(configuration.allowedRootPath.path) {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: targetPath.path, isDirectory: &isDirectory)

            // If itemType is folderOnly and target is a file, select parent folder instead
            if configuration.itemType == .folderOnly && !isDirectory.boolValue {
                return targetPath.deletingLastPathComponent()
            }

            // If itemType is fileOnly and target is a folder, reject it completely
            if configuration.itemType == .fileOnly && isDirectory.boolValue {
                return nil
            }
            // For files, check if they match the allowed extensions
            if !isDirectory.boolValue {
                if !isFileAllowed(targetPath) {
                    // File doesn't match extension filter, try parent folder if folderAndFile mode
                    if configuration.itemType == .folderAndFile {
                        return targetPath.deletingLastPathComponent()
                    } else {
                        return nil
                    }
                }
            }
            return targetPath
        }

        // If exact match not found, only try parent path fallback for appropriate item types
        if configuration.itemType == .fileOnly {
            // In fileOnly mode, don't fallback to parent folders if target file doesn't exist
            return nil
        }

        // For other modes, find the longest matching parent path
        return findLongestMatchingParent(for: targetPath)
    }
    private func findNodeByPath(_ targetPath: URL, in nodes: [FolderNode]) -> FolderNode? {
        for node in nodes {
            if node.url.path == targetPath.path {
                return node
            }
            // Recursively search in subfolders - need to convert URLs to FolderNodes
            for subfolderURL in node.subfolders {
                if let subfolderNode = createChildNode(for: subfolderURL, level: node.level + 1) {
                    if let found = findNodeByPath(targetPath, in: [subfolderNode]) {
                        return found
                    }
                }
            }
        }
        return nil
    }
    private func findLongestMatchingParent(for targetPath: URL) -> URL? {
        var currentPath = targetPath
        let rootPath = configuration.allowedRootPath
        // Walk backward from the target path until we find an existing folder
        while currentPath.path != rootPath.path && currentPath.path != "/" {
            // Try the parent directory
            currentPath = currentPath.deletingLastPathComponent()
            // Check if this parent path exists and is within our allowed root
            if FileManager.default.fileExists(atPath: currentPath.path) &&
               currentPath.path.hasPrefix(rootPath.path) {
                return currentPath
            }
        }
        // If nothing found, return the root path as fallback
        return rootPath
    }
    private func getAllPaths(from nodes: [FolderNode]) -> [URL] {
        var paths: [URL] = []
        for node in nodes {
            paths.append(node.url)
            // Add subfolder URLs directly since they're already URLs
            paths.append(contentsOf: node.subfolders)
        }
        return paths
    }
    private func expandPathToFolder(_ targetPath: URL) {
        // First, always expand the root folder if it contains subfolders
        expandedFolders.insert(configuration.allowedRootPath.path)
        var currentPath = configuration.allowedRootPath
        let targetComponents = targetPath.pathComponents
        let rootComponents = currentPath.pathComponents
        // Skip root components and iterate through the remaining path
        let pathToExpand = Array(targetComponents.dropFirst(rootComponents.count))
        for component in pathToExpand {
            currentPath = currentPath.appendingPathComponent(component)
            // Expand this folder if it exists and is not the final target
            if currentPath.path != targetPath.path && FileManager.default.fileExists(atPath: currentPath.path) {
                expandedFolders.insert(currentPath.path)
            }
        }
    }
    private func folderExists(_ path: URL) -> Bool {
        return findNodeByPath(path, in: folderTree) != nil
    }

    //Folder Tree Row
    private func folderTreeRow(_ node: FolderNode) -> some View {
        let isSelected = selectedItems.contains(node.url.path)
        let isExpanded = expandedFolders.contains(node.url.path)

        return VStack(alignment: .leading, spacing: 0) {
            // Main item button (folder or file)
            Button {
                let isLocked = LockManager.shared.isFileLocked(node.url.path)
                let isDirectory = node.url.isDirectory

                // If it's a folder and fileOnly mode, toggle expansion instead of selection
                if configuration.itemType == .fileOnly && isDirectory {
                    if expandedFolders.contains(node.url.path) {
                        expandedFolders.remove(node.url.path)
                    } else {
                        expandedFolders.insert(node.url.path)
                    }
                } else {
                    // Handle selection - check lock selectability mode
                    let shouldSelect: Bool
                    switch configuration.lockSelectabilityMode {
                    case .selectable:
                        shouldSelect = true
                    case .nonSelectable:
                        shouldSelect = !isLocked
                    }

                    if shouldSelect {
                        if configuration.allowMultipleSelection {
                            // Toggle selection for multiple selection mode
                            if selectedItems.contains(node.url.path) {
                                selectedItems.remove(node.url.path)
                            } else {
                                selectedItems.insert(node.url.path)
                            }
                        } else {
                            // Single selection mode - clear previous and select new
                            selectedItems.removeAll()
                            selectedItems.insert(node.url.path)
                        }
                    }
                }
            } label: {
                let isLocked = LockManager.shared.isFileLocked(node.url.path)
                // Determine lock icon display based on display mode
                let shouldShowLockIcon = switch configuration.lockDisplayMode {
                case .dontShow, .showAsNormal:
                    false
                case .showAsLocked:
                    isLocked
                }
                // Determine opacity based on selectability mode and itemType
                let isDirectory = node.url.isDirectory

                let (folderOpacity, textOpacity) = switch configuration.lockSelectabilityMode {
                case .selectable:
                    (1.0, 1.0)
                case .nonSelectable:
                    if isLocked {
                        (0.5, 0.5)
                    } else {
                        (1.0, 1.0)
                    }
                }
                HStack {
                    // Indent for level with max constraint to prevent overflow
                    if node.level > 0 {
                        let maxIndent = min(CGFloat(node.level) * 20, UIScreen.main.bounds.width * 0.3)
                        Spacer()
                            .frame(width: maxIndent)
                    }

                    // Chevron area - always reserve space for consistent alignment
                    if node.url.isDirectory && node.hasSubfolders {
                        let canExpand = !isLocked || configuration.lockExpandable
                        if canExpand {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    toggleFolder(node.url)
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(theme.primaryColor)
                                    .frame(width: 12, height: 12)
                                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 16, height: 16)
                        } else {
                            // Show disabled chevron for non-expandable locked folders
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                                .frame(width: 12, height: 12)
                                .frame(width: 16, height: 16)
                        }
                    } else {
                        // Empty chevron space for files and folders without subfolders
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 16, height: 16)
                    }

                    // Item icon (folder or file)
                    if node.url.isDirectory {
                        Image(systemName: "folder.fill")
                            .foregroundColor(theme.folderColor.opacity(folderOpacity))
                    } else {
                        Image(systemName: "doc.fill")
                            .foregroundColor(theme.fileColor.opacity(folderOpacity))
                    }

                    // Item name (folder or file)
                    Text(node.url.displayName)
                        .lineLimit(1)
                        .foregroundColor(theme.primaryTextColor.opacity(textOpacity))

                    Spacer()

                    // Lock indicator for locked items
                    if shouldShowLockIcon {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.lockColor)
                    }

                    // Selection indicator
                    if isSelected {
                        if configuration.allowMultipleSelection {
                            Image(systemName: "checkmark.square.fill")
                                .foregroundColor(theme.primaryColor)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.primaryColor)
                        }
                    } else if configuration.allowMultipleSelection {
                        // Only show empty checkbox if not fileOnly mode or if it's a file
                        let isDirectory = node.url.isDirectory
                        let shouldShowEmptyCheckbox = !(configuration.itemType == .fileOnly && isDirectory)

                        if shouldShowEmptyCheckbox {
                            Image(systemName: "square")
                                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? theme.primaryColor.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Expanded subfolders with smooth animation
            if isExpanded && node.hasSubfolders {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(node.subfolders, id: \.self) { subfolderURL in
                        if let childNode = createChildNode(for: subfolderURL, level: node.level + 1) {
                            AnyView(folderTreeRow(childNode))
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }
}

//FolderPickerView
public class FolderPickerViewController: UIViewController {

    public weak var delegate: FolderPickerDelegate?
    private let configuration: FolderPickerConfiguration
    private var hostingController: UIHostingController<FolderPickerView>?

    //Init
    public init(configuration: FolderPickerConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let folderPicker = FolderPickerView(configuration: configuration, delegate: self)
        hostingController = UIHostingController(rootView: folderPicker)

        guard let hostingController = hostingController else { return }

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        //Position at bottom of screen
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: 500)
        ])

        //Add tap gesture to dismiss when tapping background
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func backgroundTapped() {
        delegate?.folderPickerDidCancel(FolderPickerView(configuration: configuration))
    }
}

//FolderPickerDelegate Implementation
extension FolderPickerViewController: FolderPickerDelegate {
    public func folderPicker(_ picker: FolderPickerView, selectItems urls: [URL]) {
        delegate?.folderPicker(picker, selectItems: urls)
    }

    public func folderPickerDidCancel(_ picker: FolderPickerView) {
        delegate?.folderPickerDidCancel(picker)
    }
}

//UIGestureRecognizerDelegate
extension FolderPickerViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only handle taps on the background (not on the picker itself)
        guard let hostingView = hostingController?.view else { return true }
        let point = touch.location(in: view)
        return !hostingView.frame.contains(point)
    }
}
