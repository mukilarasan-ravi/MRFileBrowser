//
//  FileUtilsTests.swift
//  MRFileBrowserTests
//
//  Created by Test on 02/03/26.
//

import Testing
@testable import MRFileBrowser
import Foundation

struct FileUtilsTests {
    
    // MARK: - Test Setup
    
    private var temporaryDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("FileUtilsTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func cleanupDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
    
    // MARK: - File Creation Tests
    
    @Test func testCreateFile() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let fileName = "test.txt"
        let result = FileUtils.createFile(named: fileName, in: testDir)
        
        #expect(result == true)
        
        let fileURL = testDir.appendingPathComponent(fileName)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    @Test func testCreateFileWithContents() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let fileName = "test_with_content.txt"
        let testContent = "Hello, World!".data(using: .utf8)
        let result = FileUtils.createFile(named: fileName, in: testDir, contents: testContent)
        
        #expect(result == true)
        
        let fileURL = testDir.appendingPathComponent(fileName)
        let readContent = try Data(contentsOf: fileURL)
        #expect(readContent == testContent)
    }
    
    @Test func testCreateFileInNonExistentDirectory() async throws {
        let nonExistentDir = temporaryDirectory.appendingPathComponent("nonexistent")
        
        let fileName = "test.txt"
        let result = FileUtils.createFile(named: fileName, in: nonExistentDir)
        
        #expect(result == false)
    }
    
    // MARK: - Folder Creation Tests
    
    @Test func testCreateFolder() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let folderName = "TestFolder"
        
        try FileUtils.createFolder(named: folderName, in: testDir)
        
        let folderURL = testDir.appendingPathComponent(folderName)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory)
        
        #expect(exists)
        #expect(isDirectory.boolValue)
    }
    
    @Test func testCreateFolderThatAlreadyExists() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let folderName = "ExistingFolder"
        let folderURL = testDir.appendingPathComponent(folderName)
        
        // Create folder first time
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        
        // Try to create again - should throw error
        var threwError = false
        do {
            try FileUtils.createFolder(named: folderName, in: testDir)
        } catch FileUtils.FileError.destinationAlreadyExists {
            threwError = true
        }
        
        #expect(threwError)
    }
    
    // MARK: - Rename Tests
    
    @Test func testRenameFile() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let originalName = "original.txt"
        let newName = "renamed.txt"
        
        // Create original file
        FileUtils.createFile(named: originalName, in: testDir)
        let originalURL = testDir.appendingPathComponent(originalName)
        let newURL = testDir.appendingPathComponent(newName)
        
        try FileUtils.rename(oldName: originalName, newName: newName, in: testDir)
        
        #expect(!FileManager.default.fileExists(atPath: originalURL.path))
        #expect(FileManager.default.fileExists(atPath: newURL.path))
    }
    
    @Test func testRenameNonExistentFile() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let nonExistentName = "nonexistent.txt"
        
        var threwError = false
        do {
            try FileUtils.rename(oldName: nonExistentName, newName: "new_name.txt", in: testDir)
        } catch FileUtils.FileError.sourceNotFound {
            threwError = true
        }
        
        #expect(threwError)
    }
    
    // MARK: - Delete Tests
    
    @Test func testDeleteFile() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let fileName = "to_delete.txt"
        let fileURL = testDir.appendingPathComponent(fileName)
        
        // Create file
        FileUtils.createFile(named: fileName, in: testDir)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Delete file
        try FileUtils.delete(fileName: fileName, in: testDir)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    @Test func testDeleteNonExistentFile() async throws {
        let testDir = temporaryDirectory
        defer { cleanupDirectory(testDir) }
        
        let nonExistentFileName = "nonexistent.txt"
        
        var threwError = false
        do {
            try FileUtils.delete(fileName: nonExistentFileName, in: testDir)
        } catch {
            threwError = true
        }
        
        #expect(threwError)
    }
    
    // MARK: - FileError Tests
    
    @Test func testFileErrorDescriptions() async throws {
        let sourceNotFoundError = FileUtils.FileError.sourceNotFound("/path/to/source")
        #expect(sourceNotFoundError.errorDescription?.contains("Source file or folder") == true)
        
        let destinationExistsError = FileUtils.FileError.destinationAlreadyExists("/path/to/dest")
        #expect(destinationExistsError.errorDescription?.contains("already exists") == true)
        
        let renameError = FileUtils.FileError.failedToRename("old", "new", underlyingError: NSError(domain: "test", code: 0))
        #expect(renameError.errorDescription?.contains("Failed to rename") == true)
    }
}