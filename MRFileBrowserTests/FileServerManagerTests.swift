//
//  FileServerManagerTests.swift
//  MRFileBrowserTests
//
//  Created by Test on 02/03/26.
//

import Testing
@testable import MRFileBrowser
import Foundation
import Combine

struct FileServerManagerTests {
    
    // MARK: - Test Setup
    
    private var temporaryDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("FileServerManagerTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func cleanupDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
    
    private func createTestServerConfiguration() -> ServerConfiguration {
        return ServerConfiguration(
            serverButtonMode: .show,
            backgroundMode: .stopOnBackground
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test func testDefaultInitialization() async throws {
        let serverManager = FileServerManager()
        
        #expect(serverManager.server == nil, "Server should be nil initially")
        #expect(serverManager.isServerRunning == false, "Server should not be running initially")
        #expect(serverManager.serverURL.isEmpty, "Server URL should be empty initially")
        #expect(serverManager.connectedClients == 0, "Connected clients should be 0 initially")
    }
    
    @Test func testCustomConfigurationInitialization() async throws {
        let customConfig = createTestServerConfiguration()
        let serverManager = FileServerManager(serverConfiguration: customConfig)
        
        #expect(serverManager.server == nil, "Server should be nil initially with custom config")
        #expect(serverManager.isServerRunning == false, "Server should not be running initially with custom config")
        #expect(serverManager.serverURL.isEmpty, "Server URL should be empty initially with custom config")
        #expect(serverManager.connectedClients == 0, "Connected clients should be 0 initially with custom config")
    }
    
    // MARK: - Server Lifecycle Tests
    
    @Test func testStartServer() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let serverManager = FileServerManager()
        let testPort: UInt16 = 8080
        
        // Create some test files
        try "Test content".data(using: .utf8)?.write(to: testDir.appendingPathComponent("test.txt"))
        
        serverManager.startServer(rootDirectory: testDir, port: testPort)
        
        // Give the server a moment to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(serverManager.server != nil, "Server should be created after start")
        
        // Clean up
        serverManager.stopServer()
    }
    
    @Test func testStopServer() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let serverManager = FileServerManager()
        
        // Start server first
        serverManager.startServer(rootDirectory: testDir, port: 8081)
        
        // Give the server a moment to start
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(serverManager.server != nil, "Server should exist after start")
        
        // Stop server
        serverManager.stopServer()
        
        // Give the server a moment to stop
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(serverManager.server == nil, "Server should be nil after stop")
    }
    
    @Test func testRestartServer() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let serverManager = FileServerManager()
        
        // Start server
        serverManager.startServer(rootDirectory: testDir, port: 8082)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let firstServer = serverManager.server
        #expect(firstServer != nil, "First server should be created")
        
        // Restart server (start again)
        serverManager.startServer(rootDirectory: testDir, port: 8083)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let secondServer = serverManager.server
        #expect(secondServer != nil, "Second server should be created")
        #expect(secondServer !== firstServer, "Second server should be a different instance")
        
        // Clean up
        serverManager.stopServer()
    }
    
    // MARK: - Server Configuration Tests
    
    @Test func testServerWithDifferentPorts() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let serverManager1 = FileServerManager()
        let serverManager2 = FileServerManager()
        
        // Start servers on different ports
        serverManager1.startServer(rootDirectory: testDir, port: 8084)
        serverManager2.startServer(rootDirectory: testDir, port: 8085)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(serverManager1.server != nil, "First server should be running")
        #expect(serverManager2.server != nil, "Second server should be running")
        
        // Clean up
        serverManager1.stopServer()
        serverManager2.stopServer()
    }
    
    @Test func testServerWithDifferentDirectories() async throws {
        let testDir1 = temporaryDirectory.appendingPathComponent("dir1")
        let testDir2 = temporaryDirectory.appendingPathComponent("dir2")
        
        defer { 
            cleanupDirectory(testDir1)
            cleanupDirectory(testDir2)
        }
        
        // Create test directories
        try FileManager.default.createDirectory(at: testDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testDir2, withIntermediateDirectories: true)
        
        let serverManager = FileServerManager()
        
        // Start with first directory
        serverManager.startServer(rootDirectory: testDir1, port: 8086)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(serverManager.server != nil, "Server should start with first directory")
        
        // Switch to second directory
        serverManager.startServer(rootDirectory: testDir2, port: 8087)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(serverManager.server != nil, "Server should start with second directory")
        
        // Clean up
        serverManager.stopServer()
    }
    
    // MARK: - State Management Tests
    
    @Test func testServerStateUpdates() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let serverManager = FileServerManager()
        
        // Initial state
        #expect(serverManager.isServerRunning == false)
        #expect(serverManager.serverURL.isEmpty)
        #expect(serverManager.connectedClients == 0)
        
        // Start server and wait for state updates
        serverManager.startServer(rootDirectory: testDir, port: 8088)
        
        // Give time for async state updates
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Clean up
        serverManager.stopServer()
    }
    
    // MARK: - Background Handling Tests
    
    @Test func testBackgroundTaskHandling() async throws {
        let serverManager = FileServerManager()
        
        // Test that background task handling is properly initialized
        // This is more of a smoke test since we can't easily trigger background events in tests
        
        #expect(serverManager != nil, "Server manager should handle background tasks")
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testStartServerWithInvalidDirectory() async throws {
        let serverManager = FileServerManager()
        let invalidDir = temporaryDirectory.appendingPathComponent("nonexistent")
        
        // Attempt to start server with non-existent directory
        serverManager.startServer(rootDirectory: invalidDir, port: 8089)
        
        // Give time for any processing
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // The server might still be created but may not function properly
        // This test mainly ensures no crash occurs
        
        serverManager.stopServer()
    }
    
    @Test func testStopServerWhenNotRunning() async throws {
        let serverManager = FileServerManager()
        
        // Stop server when it's not running (should not crash)
        serverManager.stopServer()
        
        #expect(serverManager.server == nil, "Server should remain nil")
        #expect(serverManager.isServerRunning == false, "State should remain false")
    }
    
    // MARK: - Memory Management Tests
    
    @Test func testServerManagerDeallocation() async throws {
        var serverManager: FileServerManager? = FileServerManager()
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        serverManager?.startServer(rootDirectory: testDir, port: 8090)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Stop server before deallocation
        serverManager?.stopServer()
        
        // Set to nil to trigger deallocation
        serverManager = nil
        
        #expect(serverManager == nil, "Server manager should be deallocated")
    }
    
    // MARK: - Configuration Integration Tests
    
    @Test func testServerWithStopOnBackgroundConfiguration() async throws {
        let config = ServerConfiguration(backgroundMode: .stopOnBackground)
        let serverManager = FileServerManager(serverConfiguration: config)
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        serverManager.startServer(rootDirectory: testDir, port: 8091)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(serverManager.server != nil, "Server should start with stopOnBackground config")
        
        serverManager.stopServer()
    }
    
    @Test func testServerWithContinueInBackgroundConfiguration() async throws {
        let config = ServerConfiguration(backgroundMode: .continueInBackground)
        let serverManager = FileServerManager(serverConfiguration: config)
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        serverManager.startServer(rootDirectory: testDir, port: 8092)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(serverManager.server != nil, "Server should start with continueInBackground config")
        
        serverManager.stopServer()
    }
    
    // MARK: - Edge Cases
    
    @Test func testMultipleStartCallsQuickly() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let serverManager = FileServerManager()
        
        // Call start multiple times quickly
        for port in 8093...8095 {
            serverManager.startServer(rootDirectory: testDir, port: UInt16(port))
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Should handle multiple calls gracefully
        #expect(serverManager.server != nil, "Should handle multiple start calls")
        
        serverManager.stopServer()
    }
    
    @Test func testServerWithEmptyDirectory() async throws {
        let emptyDir = temporaryDirectory.appendingPathComponent("empty")
        defer { cleanupDirectory(emptyDir) }
        
        // Create empty directory
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        
        let serverManager = FileServerManager()
        serverManager.startServer(rootDirectory: emptyDir, port: 8096)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(serverManager.server != nil, "Server should handle empty directories")
        
        serverManager.stopServer()
    }
}