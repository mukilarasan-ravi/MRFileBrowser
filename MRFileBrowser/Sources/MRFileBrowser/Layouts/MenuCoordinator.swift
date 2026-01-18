//
//  MenuCoordinator.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 11/01/26.
//

import SwiftUI
import Combine

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

    func showBottomSheet(for file: URL) {
        selectedFile = file
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
        }

        selectedFile = nil
        shouldShowFileExtensionsAlert = false
        shouldShowErrorMessage = false
        showRenameErrorMessage = ""
        newFileName = ""

        selectedDestinationFolder = nil
        availableFolders = []
        currentMoveSourcePath = nil
        currentNavigationPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        navigationHistory = []
        expandedFolders = []
        folderTree = []
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
}
