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
    let onServerTapped: () -> Void
    @ObservedObject var serverManager: FileServerManager
    let serverConfiguration: ServerConfiguration

    @State private var isBlinking: Bool = false

    var body: some View {
        HStack {
            // Conditionally show server button based on configuration
            switch serverConfiguration.serverButtonMode {
            case .hidden:
                EmptyView()
            case .show, .showCustomView:
                Button(action: onServerTapped) {
                    Image(systemName: "laptopcomputer")
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            Image(systemName: serverManager.isServerRunning ? "wifi" : "wifi.slash")
                                .scaleEffect(0.60)
                                .offset(y: -0.15)
                                .foregroundColor(Color.blue.opacity(0.7))
                        )
                        .opacity(serverManager.isServerRunning ? (isBlinking ? 0.3 : 1.0) : 1.0)
                        .animation(
                            serverManager.isServerRunning ?
                            Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                            nil,
                            value: isBlinking
                        )
                        .onAppear {
                            if serverManager.isServerRunning {
                                startBlinking()
                            }
                        }
                        .onReceive(serverManager.$isServerRunning) { isRunning in
                            if isRunning {
                                startBlinking()
                            } else {
                                stopBlinking()
                            }
                        }
                }
                Spacer()
            }

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

    private func startBlinking() {
        withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isBlinking = true
        }
    }

    private func stopBlinking() {
        withAnimation(.default) {
            isBlinking = false
        }
    }
}
