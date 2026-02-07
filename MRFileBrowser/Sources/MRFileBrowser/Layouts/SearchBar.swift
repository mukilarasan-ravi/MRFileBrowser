//
//  SearchBar.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 30/11/25.
//

import SwiftUI

struct SearchBar: View {
    @State private var searchText = ""
    @Environment(\.themeConfiguration) private var theme

    var body: some View {
        HStack {
            TextField("Search files...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: { searchText = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.closeButtonColor)
            }
        }
        .padding(.horizontal)
    }
}
