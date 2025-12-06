//
//  SearchBar.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 30/11/25.
//

import SwiftUI

struct SearchBar: View {
    @State private var searchText = ""

    var body: some View {
        HStack {
            TextField("Search files...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: { searchText = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
    }
}
