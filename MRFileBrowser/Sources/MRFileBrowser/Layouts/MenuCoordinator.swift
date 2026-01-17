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

    @Published var showRenameView: Bool = false
    @Published var shouldShowFileExtensionsAlert: Bool = false
    @Published var shouldShowErrorMessage: Bool = false
    @Published var showRenameErrorMessage : String = ""
    @Published var newFileName: String! = ""

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
        isBottomSheetVisible = false
        selectedFile = nil

        showRenameView = false
        shouldShowFileExtensionsAlert = false
        shouldShowErrorMessage = false
        showRenameErrorMessage = ""
        newFileName = ""
    }
}
