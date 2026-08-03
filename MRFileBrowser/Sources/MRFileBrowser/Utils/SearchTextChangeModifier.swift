//
//  SearchTextChangeModifier.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 25/12/25.
//

import SwiftUI
import Combine

// MARK: - iOS 13 Compatible Search Text Change Modifier
struct SearchTextChangeModifier: ViewModifier {
    let searchText: String
    let searchUtil: SearchUtil
    let folderURL: URL
    var showHiddenFiles: Bool = false
    let onUpdate: ([SearchResult], Bool) -> Void

    @State private var lastSearchText = ""

    func body(content: Content) -> some View {
        if #available(iOS 14.0, *) {
            content
                .onChange(of: searchText) { newValue in
                    handleSearchTextChange(newValue)
                }
        } else {
            content
                .onReceive([searchText].publisher.first()) { newValue in
                    if newValue != lastSearchText {
                        lastSearchText = newValue
                        handleSearchTextChange(newValue)
                    }
                }
        }
    }

    private func handleSearchTextChange(_ newValue: String) {
        if newValue.isEmpty {
            onUpdate([], false)
        } else {
            onUpdate([], true) // Set searching state
            searchUtil.performRecursiveSearch(in: folderURL, query: newValue, currentNavigationPath: folderURL, showHiddenFiles: showHiddenFiles) { results in
                onUpdate(results, false)
            }
        }
    }
}