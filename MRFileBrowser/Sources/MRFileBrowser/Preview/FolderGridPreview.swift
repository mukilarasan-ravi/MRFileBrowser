//
//  FolderGridPreview.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 06/12/25.
//

import SwiftUI

struct FolderGridPreview: View {
    let url: URL
    let size: CGFloat   // total square size for the folder preview

    private var children: [URL] {
        let fm = FileManager.default
        return (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }

    var body: some View {
        if children.isEmpty {
            EmptyView() // no preview if folder is empty
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    FileRowItemView(url: children[safe: 0]!, size: size / 2)
                    if children.count > 1 {
                        FileRowItemView(url: children[safe: 1]!, size: size / 2)
                    } else {
                        Spacer().frame(width: size / 2, height: size / 2)
                    }
                }
                HStack(spacing: 2) {
                    if children.count > 2 {
                        FileRowItemView(url: children[safe: 2]!, size: size / 2)
                    } else {
                        Spacer().frame(width: size / 2, height: size / 2)
                    }

                    if children.count > 3 {
                        FileRowItemView(url: children[safe: 3]!, size: size / 2)
                    } else {
                        Spacer().frame(width: size / 2, height: size / 2)
                    }
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// Safe array index helper to prevent out-of-bounds crash
fileprivate extension Array {
    subscript(safe index: Int) -> Element? {
        (indices.contains(index)) ? self[index] : nil
    }
}
