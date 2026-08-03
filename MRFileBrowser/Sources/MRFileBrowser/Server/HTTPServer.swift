//
//  HTTPServer.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 26/01/26.
//

import Foundation
import Network
import UIKit
import Combine

class HTTPServer: ObservableObject {
    private var listener: NWListener?
    @Published var isRunning = false
    @Published var serverURL: String = ""
    @Published var connectedClients: Int = 0

    private let preferredPort: UInt16
    private var actualPort: UInt16
    private var rootDirectory: URL
    private var connections: [NWConnection] = []
    private let serverConfiguration: ServerConfiguration
    private let showHiddenFiles: Bool

    init(port: UInt16 = 8080, rootDirectory: URL, serverConfiguration: ServerConfiguration = ServerConfiguration(), showHiddenFiles: Bool = false) {
        self.preferredPort = port
        self.actualPort = port
        self.rootDirectory = rootDirectory
        self.serverConfiguration = serverConfiguration
        self.showHiddenFiles = showHiddenFiles
    }

    private func checkDirectoryPermissions() -> Bool {
        let path = rootDirectory.path
        print("Checking directory permissions for: \(path)")

        // Check if directory exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("Directory does not exist: \(path)")
            return false
        }

        // Check if it's actually a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue else {
            print("Path is not a directory: \(path)")
            return false
        }

        // Check if readable
        guard FileManager.default.isReadableFile(atPath: path) else {
            print("Directory is not readable: \(path)")
            print("   This might be due to app sandbox restrictions or missing permissions")
            return false
        }

        // Try to read directory contents
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            print("Directory accessible with \(contents.count) items")
            return true
        } catch {
            print("Failed to read directory contents: \(error)")
            return false
        }
    }

    private func findAvailablePort(startingFrom port: UInt16) -> UInt16? {
        let maxAttempts = 100
        var currentPort = port

        for _ in 0..<maxAttempts {
            if isPortAvailableSimple(currentPort) {
                return currentPort
            }
            currentPort += 1
            // Wrap around if we exceed port range
            if currentPort > 65535 {
                currentPort = 8000
            }
        }
        return nil
    }

    // Simpler port availability check using socket binding
    private func isPortAvailableSimple(_ port: UInt16) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return false }

        defer { close(socketFD) }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return bindResult == 0
    }

    private func isPortAvailable(_ port: UInt16) -> Bool {
        do {
            let parameters = NWParameters.tcp
            let testListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            var isAvailable = false
            var completed = false
            let semaphore = DispatchSemaphore(value: 0)

            testListener.stateUpdateHandler = { state in
                guard !completed else { return }

                switch state {
                case .ready:
                    completed = true
                    isAvailable = true
                    testListener.cancel()
                    semaphore.signal()
                case .failed(_):
                    completed = true
                    isAvailable = false
                    testListener.cancel()
                    semaphore.signal()
                case .cancelled:
                    if !completed {
                        completed = true
                        semaphore.signal()
                    }
                default:
                    break
                }
            }

            testListener.start(queue: .global(qos: .background))

            // Wait for up to 0.5 seconds for the test (reduced timeout for faster checking)
            let result = semaphore.wait(timeout: .now() + 0.5)

            if result == .timedOut {
                completed = true
                testListener.cancel()
                // Give a moment for cancel to complete
                _ = semaphore.wait(timeout: .now() + 0.1)
                return false
            }

            return isAvailable
        } catch {
            return false
        }
    }

    func start() {
        guard !isRunning else { 
            print("Server already running on port \(actualPort)")
            return 
        }

        print("Starting HTTP server...")
        print("Root directory: \(rootDirectory.path)")

        // Check directory permissions first
        guard checkDirectoryPermissions() else {
            print("Server startup failed due to directory access issues")
            DispatchQueue.main.async {
                self.isRunning = false
                self.serverURL = ""
            }
            return
        }

        // Find an available port
        guard let availablePort = findAvailablePort(startingFrom: preferredPort) else {
            print("No available ports found after checking 100 ports starting from \(preferredPort)")
            DispatchQueue.main.async {
                self.isRunning = false
                self.serverURL = ""
            }
            return
        }

        actualPort = availablePort

        if actualPort != preferredPort {
            print("Preferred port \(preferredPort) unavailable, using port \(actualPort)")
        } else {
            print("Using preferred port \(actualPort)")
        }

        startServerOnPort(actualPort)

    }

    private func startServerOnPort(_ port: UInt16) {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            // Set up state update handler to monitor listener state
            listener?.stateUpdateHandler = { [weak self] newState in
                print("Listener state changed to: \(newState)")
                switch newState {
                case .ready:
                    DispatchQueue.main.async {
                        self?.isRunning = true
                        self?.updateServerURL()
                        print("HTTP Server is ready on \(self?.serverURL ?? "unknown")")
                    }
                case .failed(let error):
                    print("Listener failed: \(error)")
                    DispatchQueue.main.async {
                        self?.isRunning = false
                        self?.serverURL = ""
                    }
                case .cancelled:
                    print("Listener was cancelled")
                    DispatchQueue.main.async {
                        self?.isRunning = false
                        self?.serverURL = ""
                    }
                default:
                    print("Listener state: \(newState)")
                }
            }

            listener?.start(queue: .global(qos: .userInitiated))

            print("HTTP Server startup initiated on port \(port)...")

        } catch {
            print("Failed to start server on port \(port): \(error)")
            if let nwError = error as? NWError {
                print("Network error details: \(nwError.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.isRunning = false
                self.serverURL = ""
            }
        }
    }

    func stop() {
        guard isRunning else { 
            print("Server already stopped")
            return 
        }

        print("Stopping HTTP server...")

        listener?.cancel()

        // Close all active connections
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()

        DispatchQueue.main.async {
            self.isRunning = false
            self.serverURL = ""
            self.connectedClients = 0
            print("HTTP server stopped successfully")
        }

        listener = nil
    }

    func validateState() -> Bool {
        let listenerActive = listener != nil
        print("Server state validation: isRunning=\(isRunning), listener=\(listenerActive ? "active" : "inactive"), URL=\(serverURL)")
        return isRunning == listenerActive
    }

    private func handleConnection(_ connection: NWConnection) {
        print("New connection established from: \(connection.endpoint)")
        connections.append(connection)

        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleHTTPRequest(data: data, connection: connection)
            }

            if isComplete || error != nil {
                self?.connections.removeAll { $0 === connection }
                DispatchQueue.main.async {
                    self?.connectedClients = self?.connections.count ?? 0
                }
            }
        }

        DispatchQueue.main.async {
            self.connectedClients = self.connections.count
        }
    }

    private func handleHTTPRequest(data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else { return }

        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }

        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2 else { return }

        let method = components[0]
        let path = components[1]

        switch method {
        case "GET":
            handleGETRequest(path: path, connection: connection)
        default:
            sendResponse(connection: connection, statusCode: 405, body: "Method Not Allowed")
        }
    }

    private func handleGETRequest(path: String, connection: NWConnection) {
        let decodedPath = path.removingPercentEncoding ?? path
        let requestedPath = decodedPath == "/" ? "" : String(decodedPath.dropFirst())

        let fileURL = rootDirectory.appendingPathComponent(requestedPath)

        // Security check - ensure the requested file is within root directory
        guard fileURL.path.hasPrefix(rootDirectory.path) else {
            sendResponse(connection: connection, statusCode: 403, body: "Forbidden")
            return
        }

        // Check if path exists and determine if it's a directory
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)

        guard fileExists else {
            sendResponse(connection: connection, statusCode: 404, body: "File Not Found")
            return
        }

        if isDirectory.boolValue {
            sendDirectoryListing(directoryURL: fileURL, connection: connection)
        } else {
            sendFile(fileURL: fileURL, connection: connection)
        }
    }

    private func sendFile(fileURL: URL, connection: NWConnection) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            sendResponse(connection: connection, statusCode: 404, body: "File Not Found")
            return
        }

        // Check if file should be accessible based on HTML provider configuration
        let isDirectlyLocked = LockManager.shared.isFileLocked(fileURL.path)
        let hasParentLocked = FileUtils.isAnyParentLocked(fileURL.path, rootDirectory: rootDirectory.path)

        // Create a FileItem to check accessibility
        let fileItem = FileItem(
            name: fileURL.lastPathComponent,
            path: fileURL.path.replacingOccurrences(of: rootDirectory.path + "/", with: ""),
            isDirectory: false,
            size: nil,
            modificationDate: nil,
            fileExtension: fileURL.pathExtension,
            isLocked: isDirectlyLocked,
            isParentLocked: hasParentLocked
        )

        // Check if HTML provider allows access to this file
        if !serverConfiguration.htmlProvider.shouldShowItem(fileItem) {
            let reason: LockReason = fileItem.isLocked ? .locked : .parentLocked
            let accessDeniedHTML = serverConfiguration.htmlProvider.generateAccessDeniedHTML(for: fileItem, reason: reason)
            sendResponse(connection: connection, statusCode: 403, body: accessDeniedHTML, contentType: "text/html")
            return
        }

        do {
            let fileData = try Data(contentsOf: fileURL)
            let mimeType = getMimeType(for: fileURL.pathExtension)

            var response = "HTTP/1.1 200 OK\r\n"
            response += "Content-Type: \(mimeType)\r\n"
            response += "Content-Length: \(fileData.count)\r\n"
            response += "\r\n"

            let headerData = response.data(using: .utf8)!
            let fullResponse = headerData + fileData

            connection.send(content: fullResponse, completion: .contentProcessed { _ in
                connection.cancel()
            })

        } catch {
            sendResponse(connection: connection, statusCode: 500, body: "Internal Server Error")
        }
    }



    private func sendDirectoryListing(directoryURL: URL, connection: NWConnection) {
        // Check if directory itself should be accessible
        let isDirectlyLocked = LockManager.shared.isFileLocked(directoryURL.path)
        let hasParentLocked = FileUtils.isAnyParentLocked(directoryURL.path, rootDirectory: rootDirectory.path)

        let directoryItem = FileItem(
            name: directoryURL.lastPathComponent,
            path: directoryURL.path.replacingOccurrences(of: rootDirectory.path + "/", with: ""),
            isDirectory: true,
            size: nil,
            modificationDate: nil,
            fileExtension: "",
            isLocked: isDirectlyLocked,
            isParentLocked: hasParentLocked
        )

        if !serverConfiguration.htmlProvider.shouldShowItem(directoryItem) {
            let reason: LockReason = directoryItem.isLocked ? .locked : .parentLocked
            let accessDeniedHTML = serverConfiguration.htmlProvider.generateAccessDeniedHTML(for: directoryItem, reason: reason)
            sendResponse(connection: connection, statusCode: 403, body: accessDeniedHTML, contentType: "text/html")
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: showHiddenFiles ? [] : [.skipsHiddenFiles])

            let relativePath = directoryURL.path.replacingOccurrences(of: rootDirectory.path, with: "")
            let title = relativePath.isEmpty ? "Root Directory" : relativePath

            // Sort contents: directories first, then files
            let sortedContents = contents.sorted { url1, url2 in
                let isDir1 = url1.hasDirectoryPath
                let isDir2 = url2.hasDirectoryPath

                if isDir1 != isDir2 {
                    return isDir1
                }
                return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
            }

            // Convert to FileItem objects
            let fileItems = sortedContents.compactMap { url -> FileItem? in
                let isDirectory = url.hasDirectoryPath
                let name = url.lastPathComponent
                let itemPath = url.path.replacingOccurrences(of: rootDirectory.path + "/", with: "")

                var size: Int64? = nil
                var modificationDate: Date? = nil

                if !isDirectory {
                    size = getFileSize(url: url)
                }

                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    modificationDate = attributes[.modificationDate] as? Date
                } catch {
                    // Ignore error, keep modificationDate as nil
                }

                // Check if file/folder is locked directly and if any parent is locked
                let isDirectlyLocked = LockManager.shared.isFileLocked(url.path)
                let hasParentLocked = FileUtils.isAnyParentLocked(url.path, rootDirectory: rootDirectory.path)

                return FileItem(
                    name: name,
                    path: itemPath,
                    isDirectory: isDirectory,
                    size: size,
                    modificationDate: modificationDate,
                    fileExtension: url.pathExtension,
                    isLocked: isDirectlyLocked,
                    isParentLocked: hasParentLocked
                )
            }

            // Create directory listing
            let parentPath = relativePath.isEmpty ? nil : (relativePath as NSString).deletingLastPathComponent
            let directoryListing = DirectoryListing(
                title: title,
                relativePath: relativePath,
                isRoot: relativePath.isEmpty,
                parentPath: parentPath,
                items: fileItems
            )

            // Generate HTML using the provider
            let html = serverConfiguration.htmlProvider.generateDirectoryListingHTML(for: directoryListing)

            sendResponse(connection: connection, statusCode: 200, body: html, contentType: "text/html")

        } catch {
            sendResponse(connection: connection, statusCode: 500, body: "Failed to read directory")
        }
    }

    private func getFileSize(url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: String, contentType: String = "text/plain") {
        let bodyData = body.data(using: .utf8)!

        var response = "HTTP/1.1 \(statusCode) \(getStatusText(statusCode))\r\n"
        response += "Content-Type: \(contentType)\r\n"
        response += "Content-Length: \(bodyData.count)\r\n"
        response += "\r\n"

        let headerData = response.data(using: .utf8)!
        let fullResponse = headerData + bodyData

        connection.send(content: fullResponse, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func updateServerURL() {
        if let localIP = getLocalIPAddress() {
            serverURL = "http://\(localIP):\(actualPort)"
        }
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    if let name = interface?.ifa_name {
                        let interfaceName = String(cString: name)
                        if interfaceName == "en0" || interfaceName == "en1" {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                            address = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }

    private func getMimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "mp4": return "video/mp4"
        case "mp3": return "audio/mpeg"
        case "pdf": return "application/pdf"
        case "zip": return "application/zip"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }

    private func getStatusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}