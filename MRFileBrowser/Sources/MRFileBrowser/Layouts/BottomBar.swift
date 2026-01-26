//
//  BottomBar.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 30/11/25.
//

import SwiftUI

struct BottomBar: View {
    let onTrashTapped: () -> Void
    let onNewFolderTapped: () -> Void
    let onSortTapped: () -> Void
    var body: some View {
        HStack {
            Button(action: { }) {
                Image(systemName: "laptopcomputer")
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        Image(systemName: "wifi")
                            .scaleEffect(0.60)
                            .offset(y: -0.15 )
                    )
            }
            Spacer()

            Button(action: onTrashTapped) {
                Image(systemName: "trash")
            }

            Spacer()

            Button(action: onSortTapped) {
                Image(systemName: "arrow.up.arrow.down")
            }

            Spacer()

            Button(action: onNewFolderTapped) {
                Image(systemName: "folder.badge.plus")
            }
        }
        .font(.system(size: 30))
        .padding(.horizontal)
        .foregroundColor(.blue)
    }
}
