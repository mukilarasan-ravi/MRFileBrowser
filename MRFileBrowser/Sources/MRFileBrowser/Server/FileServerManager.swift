//
//  FileServerManager.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 26/01/26.
//

import Foundation
import SwiftUI
import Combine
import UIKit

class FileServerManager: ObservableObject {
    @Published var server: HTTPServer?
    @Published var isServerRunning = false
    @Published var serverURL = ""
    @Published var connectedClients = 0

    private var currentRootDirectory: URL?
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let serverConfiguration: ServerConfiguration
    private let showHiddenFiles: Bool

    init(serverConfiguration: ServerConfiguration = ServerConfiguration(), showHiddenFiles: Bool = false) {
        self.serverConfiguration = serverConfiguration
        self.showHiddenFiles = showHiddenFiles
        setupBackgroundHandling()
    }

    func startServer(rootDirectory: URL, port: UInt16 = 8080) {
        stopServer() // Stop any existing server

        currentRootDirectory = rootDirectory
        server = HTTPServer(port: port, rootDirectory: rootDirectory, serverConfiguration: serverConfiguration, showHiddenFiles: showHiddenFiles)

        server?.start()

        // Update state on main thread
        DispatchQueue.main.async {
            self.updateFromServer()
        }
    }

    func stopServer() {
        server?.stop()
        server = nil

        DispatchQueue.main.async {
            self.isServerRunning = false
            self.serverURL = ""
            self.connectedClients = 0
        }
    }

    func toggleServer(rootDirectory: URL) {
        if isServerRunning {
            stopServer()
        } else {
            startServer(rootDirectory: rootDirectory)
        }
    }

    private func updateFromServer() {
        guard let server = server else {
            DispatchQueue.main.async {
                self.isServerRunning = false
                self.serverURL = ""
                self.connectedClients = 0
            }
            return
        }

        // Validate server internal state
        let stateValid = server.validateState()
        if !stateValid {
            print("Server state inconsistency detected")
        }

        DispatchQueue.main.async {
            self.isServerRunning = server.isRunning
            self.serverURL = server.serverURL
            self.connectedClients = server.connectedClients
            print("Server state updated: running=\\(self.isServerRunning), url=\\(self.serverURL)")
        }
    }

    private func setupBackgroundHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
    }

    private func handleAppDidEnterBackground() {
        guard isServerRunning else { return }

        switch serverConfiguration.backgroundMode {
        case .stopOnBackground:
            print("App entering background - stopping server (configuration: stopOnBackground)")
            stopServer()

        case .continueInBackground:
            print("App entering background - requesting background time for server (configuration: continueInBackground)")
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "FileServerBackground") { [weak self] in
                self?.endBackgroundTask()
            }
        }
    }

    private func handleAppWillEnterForeground() {
        print("App entering foreground - checking server state")

        // End background task
        endBackgroundTask()

        // Only verify and recover if we continue in background
        if serverConfiguration.backgroundMode == .continueInBackground {
            // Verify server state and recover if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.verifyAndRecoverServerState()
            }
        } else {
            print("Background mode is stopOnBackground - no recovery needed")
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func verifyAndRecoverServerState() {
        guard let server = server, let rootDirectory = currentRootDirectory else {
            print("No server to verify")
            return
        }

        print("Verifying server state - UI shows running: \(isServerRunning), server reports: \(server.isRunning)")

        // If UI thinks server is running but server is actually stopped
        if isServerRunning && !server.isRunning {
            print("Server state mismatch detected - restarting server")
            restartServer()
        }
        // If server is running but UI doesn't reflect it
        else if !isServerRunning && server.isRunning {
            print("UI state mismatch detected - updating UI")
            updateFromServer()
        }
        // Force refresh server state
        else {
            print("Force refreshing server state")
            updateFromServer()
        }
    }

    private func restartServer() {
        guard let rootDirectory = currentRootDirectory else { return }

        print("Restarting server after background recovery")
        stopServer()

        // Small delay to ensure cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.startServer(rootDirectory: rootDirectory)
        }
    }

    deinit {
        endBackgroundTask()
        NotificationCenter.default.removeObserver(self)
    }
}