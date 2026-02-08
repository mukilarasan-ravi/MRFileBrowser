//
//  SearchUtil.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 08/02/26.
//

import Foundation
import SwiftUI

// - Search Result Data Structure
struct SearchResult: Identifiable {
    let id = UUID()
    let url: URL
    let relativePath: String
    let lockedParents: [URL] // Array of locked parent folders from root to immediate parent
    let isInLockedFolder: Bool // Whether this file is inside any locked folder

    var displayPath: String {
        return relativePath.isEmpty ? url.lastPathComponent : relativePath + "/" + url.lastPathComponent
    }
}

// - Search Utility Class
class SearchUtil {

    static let shared = SearchUtil()
    private init() {}

    // - Helper Methods

    /// Checks if a given path is within the current navigation path (already unlocked)
    private func isPathWithinNavigationPath(_ path: URL, _ navigationPath: URL) -> Bool {
        // Resolve both paths to handle symlinks and relative paths
        let resolvedPath = path.resolvingSymlinksInPath().standardized
        let resolvedNavigationPath = navigationPath.resolvingSymlinksInPath().standardized

        // Check if the path is the same as navigation path or a parent of it
        return resolvedPath.path == resolvedNavigationPath.path || 
               resolvedNavigationPath.path.hasPrefix(resolvedPath.path + "/")
    }

    // - Search Methods

    /// Performs recursive search in the given directory
    /// - Parameters:
    ///   - directory: Root directory to search in
    ///   - query: Search query string
    ///   - currentNavigationPath: Current folder path user is already in (already unlocked)
    ///   - completion: Completion handler with search results
    func performRecursiveSearch(
        in directory: URL,
        query: String,
        currentNavigationPath: URL,
        completion: @escaping ([SearchResult]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let results = self.searchRecursively(
                in: directory,
                query: query,
                basePath: "",
                lockedParents: [],
                currentNavigationPath: currentNavigationPath
            )

            DispatchQueue.main.async {
                completion(results)
            }
        }
    }

    /// Recursively searches through directory structure
    /// - Parameters:
    ///   - directory: Current directory to search
    ///   - query: Search query string
    ///   - basePath: Current path from root
    ///   - lockedParents: Array of locked parent URLs
    ///   - currentNavigationPath: Current folder path user is already in (already unlocked)
    /// - Returns: Array of SearchResult objects
    private func searchRecursively(
        in directory: URL,
        query: String,
        basePath: String,
        lockedParents: [URL],
        currentNavigationPath: URL
    ) -> [SearchResult] {
        var results: [SearchResult] = []
        let fm = FileManager.default

        do {
            let contents = try fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents {
                // Skip trash folder in search
                if item.isTrashFolder {
                    continue
                }

                // Check if current item matches search
                if item.lastPathComponent.localizedCaseInsensitiveContains(query) {
                    let relativePath = basePath.isEmpty ? "" : basePath
                    var currentLockedParents = lockedParents

                    // Check if current directory is locked, but only if it's not already in our navigation path
                    if LockManager.shared.isFileLocked(directory.path) && 
                       !isPathWithinNavigationPath(directory, currentNavigationPath) && 
                       !lockedParents.contains(directory) {
                        currentLockedParents.append(directory)
                    }

                    results.append(SearchResult(
                        url: item,
                        relativePath: relativePath,
                        lockedParents: currentLockedParents,
                        isInLockedFolder: !currentLockedParents.isEmpty
                    ))
                }

                // Recursively search subdirectories
                if item.isDirectory {
                    var newLockedParents = lockedParents

                    // Check if this directory is locked, but only if it's not already in our navigation path
                    if LockManager.shared.isFileLocked(item.path) && 
                       !isPathWithinNavigationPath(item, currentNavigationPath) {
                        newLockedParents.append(item)
                    }

                    let newBasePath = basePath.isEmpty ? item.lastPathComponent : basePath + "/" + item.lastPathComponent
                    let subResults = searchRecursively(
                        in: item,
                        query: query,
                        basePath: newBasePath,
                        lockedParents: newLockedParents,
                        currentNavigationPath: currentNavigationPath
                    )
                    results.append(contentsOf: subResults)
                }
            }
        } catch {
            // If we can't read the directory (permissions, etc.), continue with empty results
            print("Error reading directory \(directory.path): \(error)")
        }

        return results
    }

    /// Gets search context (parent folder path) for display
    /// - Parameters:
    ///   - item: File URL to get context for
    ///   - searchResults: Array of current search results
    /// - Returns: Formatted parent path string or nil
    func getSearchContext(for item: URL, from searchResults: [SearchResult]) -> String? {
        guard let searchResult = searchResults.first(where: { $0.url == item }) else {
            return nil
        }

        let relativePath = searchResult.relativePath
        let pathComponents = relativePath.split(separator: "/")

        if pathComponents.isEmpty {
            return nil
        }

        return pathComponents.joined(separator: " / ")
    }

    /// Checks if a file is in a locked folder from search results
    /// - Parameters:
    ///   - item: File URL to check
    ///   - searchResults: Array of current search results
    /// - Returns: True if file is in locked folder
    func isFileInLockedFolder(for item: URL, from searchResults: [SearchResult]) -> Bool {
        guard let searchResult = searchResults.first(where: { $0.url == item }) else {
            return false
        }
        return searchResult.isInLockedFolder
    }

    /// Handles search result tap with locked parent folder management
    /// - Parameters:
    ///   - item: Selected file URL
    ///   - searchResults: Array of current search results
    ///   - menuCoordinator: Menu coordinator for UI actions
    ///   - onUnlocked: Completion handler when all parents are unlocked
    func handleSearchResultTap(
        _ item: URL,
        from searchResults: [SearchResult],
        menuCoordinator: MenuCoordinator,
        onUnlocked: @escaping (URL) -> Void
    ) {
        // Find the search result for this URL to get locked parents info
        guard let searchResult = searchResults.first(where: { $0.url == item }) else {
            // Fallback to normal tap handling
            onUnlocked(item)
            return
        }

        if !searchResult.lockedParents.isEmpty {
            // Show confirmation alert about locked parents and start unlock process
            let lockedCount = searchResult.lockedParents.count
            let message = "This item is inside \(lockedCount) locked folder\(lockedCount > 1 ? "s" : ""). You'll need to unlock each folder to access it."

            menuCoordinator.showSearchUnlockAlert(message: message) {
                // Start unlocking process from the first locked parent
                self.unlockParentFoldersSequentially(
                    for: searchResult,
                    currentIndex: 0,
                    menuCoordinator: menuCoordinator,
                    onComplete: { onUnlocked(item) }
                )
            }
        } else {
            // No locked parents, handle normally
            onUnlocked(item)
        }
    }

    /// Sequentially unlocks parent folders for search results
    /// - Parameters:
    ///   - searchResult: Search result containing locked parents
    ///   - currentIndex: Current parent folder index to unlock
    ///   - menuCoordinator: Menu coordinator for UI actions
    ///   - onComplete: Completion handler when all folders are unlocked
    private func unlockParentFoldersSequentially(
        for searchResult: SearchResult,
        currentIndex: Int,
        menuCoordinator: MenuCoordinator,
        onComplete: @escaping () -> Void
    ) {
        guard currentIndex < searchResult.lockedParents.count else {
            // All parents unlocked, execute completion
            onComplete()
            return
        }

        let lockedParent = searchResult.lockedParents[currentIndex]

        // Determine the lock type for this specific folder
        let lockManager = LockManager.shared

        if lockManager.hasCustomPIN(lockedParent.path) {
            // This folder uses PIN lock - show unlock view
            menuCoordinator.showUnlockView(for: lockedParent, pendingAction: {
                // Continue with next locked parent
                self.unlockParentFoldersSequentially(
                    for: searchResult,
                    currentIndex: currentIndex + 1,
                    menuCoordinator: menuCoordinator,
                    onComplete: onComplete
                )
            }, isPermanent: false)
        } else {
            // This folder uses biometric lock - use LockAuthenticator
            LockAuthenticator.performMenuActionWithLockCheck(
                for: lockedParent,
                menuCoordinator: menuCoordinator
            ) {
                // Biometric authentication successful, continue with next locked parent
                self.unlockParentFoldersSequentially(
                    for: searchResult,
                    currentIndex: currentIndex + 1,
                    menuCoordinator: menuCoordinator,
                    onComplete: onComplete
                )
            }
        }
    }
}