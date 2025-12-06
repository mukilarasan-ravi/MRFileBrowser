//
//  BottomBar.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 30/11/25.
//

import SwiftUI

struct BottomBar: View {
    var body: some View {
        HStack {
            Button(action: { }) {
                Image(systemName: "folder.badge.plus")
                Text("New Folder")
            }
            Spacer()
            Button(action: { }) {
                Image(systemName: "trash")
                Text("Delete")
            }
            Spacer()
            Button(action: { }) {
                Image(systemName: "square.and.arrow.up")
                Text("Share")
            }
        }
        .padding(.horizontal)
        .foregroundColor(.blue)
    }
}
