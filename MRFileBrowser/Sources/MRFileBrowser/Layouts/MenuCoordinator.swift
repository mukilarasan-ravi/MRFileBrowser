//
//  MenuCoordinator.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 11/01/26.
//

import SwiftUI
final class MenuCoordinator: ObservableObject {

    @Published var isBottomSheetVisible: Bool = false
    @Published var selectedFile: URL? = nil

    func showBottomSheet(for file: URL) {
        selectedFile = file
        withAnimation(.easeOut) {
            isBottomSheetVisible = true
        }
    }

    func hideBottomSheet() {
        withAnimation(.easeOut) {
            isBottomSheetVisible = false
            selectedFile = nil
        }
    }
}
