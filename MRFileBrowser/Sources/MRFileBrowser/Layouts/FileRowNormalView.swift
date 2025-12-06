//
//  FileRowNormalView.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 30/11/25.
//

import SwiftUI

struct FileRowNormalView: View {
    let url: URL

    var body: some View {
        HStack {
            Image(systemName: url.isDirectory ? "folder" : "doc.text")
                .frame(width: 28)
            Text(url.lastPathComponent)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.secondarySystemBackground)))
    }
}
