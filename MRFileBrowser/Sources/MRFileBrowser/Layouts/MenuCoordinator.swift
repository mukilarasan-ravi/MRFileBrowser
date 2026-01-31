//
//  MenuCoordinator.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 11/01/26.
//

import SwiftUI
import Combine

enum SortOption: CaseIterable {
    case name, dateModified, size
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .dateModified: return "Date"
        case .size: return "Size"
        }
    }
    
    var icon: String {
        switch self {
        case .name: return "character"
        case .dateModified: return "clock"
        case .size: return "doc.badge.ellipsis"
        }
    }
}

enum SortOrder {
    case ascending, descending
    
    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
    
    var icon: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

final class MenuCoordinator: ObservableObject {

    @Published var isBottomSheetVisible: Bool = false
    @Published var selectedFile: URL? = nil

    @Published var showRenameView: Bool = false
    @Published var shouldShowFileExtensionsAlert: Bool = false
    @Published var shouldShowErrorMessage: Bool = false
    @Published var showRenameErrorMessage : String = ""
    @Published var newFileName: String! = ""

    @Published var showMoveView: Bool = false
    @Published var selectedDestinationFolder: URL? = nil
    @Published var availableFolders: [URL] = []
    @Published var currentMoveSourcePath: URL? = nil
    @Published var currentNavigationPath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @Published var navigationHistory: [URL] = []
    @Published var expandedFolders: Set<URL> = []
    @Published var folderTree: [FolderNode] = []

    @Published var showFileInfo: Bool = false
    @Published var fileInfo: FileItem? = nil
    // Restore-related state
    @Published var showRestoreLocationPicker: Bool = false
    @Published var restoreSourceFile: URL? = nil
    @Published var selectedRestoreDestination: URL? = nil
    // Lock-related state
    @Published var showLockSetup: Bool = false
    @Published var showUnlock: Bool = false
    @Published var pendingLockFile: URL? = nil
    @Published var isPermanentUnlock: Bool = false // Add this property

    // New Folder Properties
    @Published var showNewFolderView: Bool = false
    @Published var newFolderName: String = ""

    // Sort Properties
    @Published var showSortView: Bool = false
    @Published var sortBy: SortOption = .name
    @Published var sortOrder: SortOrder = .ascending

    // Pending action to execute after unlock
    private var pendingAction: (() -> Void)? = nil

    func showBottomSheet(for file: URL) {
        selectedFile = file
        showSortView = false // Ensure sort view is hidden when showing file operations
        withAnimation(.easeOut) {
            isBottomSheetVisible = true
        }
    }

    func hideBottomSheet() {
        withAnimation(.easeOut) {
            isBottomSheetVisible = false
        }
    }
    func resetVar(){
        withAnimation(.easeOut) {
            isBottomSheetVisible = false
            showMoveView = false
            showRenameView = false
            showFileInfo = false
            showLockSetup = false
            showUnlock = false
            showRestoreLocationPicker = false
            showNewFolderView = false
            showSortView = false
        }

        selectedFile = nil
        pendingLockFile = nil
        shouldShowFileExtensionsAlert = false
        shouldShowErrorMessage = false
        showRenameErrorMessage = ""
        newFileName = ""
        newFolderName = ""

        selectedDestinationFolder = nil
        availableFolders = []
        currentMoveSourcePath = nil
        currentNavigationPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        navigationHistory = []
        expandedFolders = []
        folderTree = []
        fileInfo = nil
        // Reset restore state
        restoreSourceFile = nil
        selectedRestoreDestination = nil
    }

    func prepareMove(for file: URL, availableFolders: [URL]) {
        currentMoveSourcePath = file
        selectedDestinationFolder = nil

        // Set initial navigation to parent of current file or the file's directory
        let parentURL = file.deletingLastPathComponent()
        currentNavigationPath = parentURL
        navigationHistory = []

        // Start with the root folder expanded to show immediate options
        expandedFolders = [parentURL]

        // Build initial folder tree with current folder as root
        buildFolderTree()
        showMoveView = true
    }

    func buildFolderTree() {
        folderTree = []

        // Use the current navigation path (where the move was initiated) as the root
        if let rootNode = createFolderNode(for: currentNavigationPath, level: 0) {
            folderTree.append(rootNode)
        }
    }

    private func createFolderNode(for url: URL, level: Int) -> FolderNode? {
        // Skip if this is the source file being moved
        guard url != currentMoveSourcePath else { return nil }

        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            let subfolders = contents.filter { $0.isDirectory && $0 != currentMoveSourcePath }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

            return FolderNode(
                url: url,
                level: level,
                hasSubfolders: !subfolders.isEmpty,
                subfolders: subfolders
            )
        } catch {
            return FolderNode(url: url, level: level, hasSubfolders: false, subfolders: [])
        }
    }

    func toggleFolder(_ folder: URL) {
        if expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        } else {
            expandedFolders.insert(folder)
        }
        buildFolderTree() // Rebuild tree to reflect changes
    }
    // Lock functionality methods
    func showLockSetupView(for file: URL) {
        pendingLockFile = file
        hideBottomSheet()
        showLockSetup = true
    }
    func showUnlockView(for file: URL, pendingAction: (() -> Void)? = nil, isPermanent: Bool = false) {
        pendingLockFile = file
        self.pendingAction = pendingAction
        self.isPermanentUnlock = isPermanent
        hideBottomSheet()
        showUnlock = true
    }
    func hideLockViews() {
        showLockSetup = false
        showUnlock = false
        pendingLockFile = nil
        pendingAction = nil
        isPermanentUnlock = false
    }
    func executePendingAction() {
        if let action = pendingAction {
            action()
            pendingAction = nil
        }
    }
    var hasPendingAction: Bool {
        return pendingAction != nil
    }
    //Restore Methods
    func showRestoreLocationPicker(for file: URL, initialRootURL: URL) {
        restoreSourceFile = file
        selectedRestoreDestination = nil
        // Set initial navigation to root folder
        currentNavigationPath = initialRootURL
        navigationHistory = []
        expandedFolders = [initialRootURL]
        // Build folder tree starting from root
        buildFolderTree()
        showRestoreLocationPicker = true
    }
}
