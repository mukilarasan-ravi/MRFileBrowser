//
//  FileUtils.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 12/01/26.
//

import Foundation

class FileUtils {

    enum FileError: Error, LocalizedError {
        case sourceNotFound(String)
        case destinationAlreadyExists(String)
        case failedToRename(String, String, underlyingError: Error)

        var errorDescription: String? {
            switch self {
            case .sourceNotFound(let path):
                return "Source file or folder '\(path)' does not exist."
            case .destinationAlreadyExists(let path):
                return "Destination file or folder '\(path)' already exists."
            case .failedToRename(let oldPath, let newPath, let error):
                return "Failed to rename '\(oldPath)' to '\(newPath)': \(error.localizedDescription)"
            }
        }
    }

    static let fileManager = FileManager.default

    //Create a File
    @discardableResult
    static func createFile(named fileName: String, in folderURL: URL, contents: Data? = nil) -> Bool {
        let fileURL = folderURL.appendingPathComponent(fileName)
        return fileManager.createFile(atPath: fileURL.path, contents: contents, attributes: nil)
    }

    //Write to File
    static func write(to fileName: String, in folderURL: URL, content: String) throws {
        let fileURL = folderURL.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    //Read from File
    static func read(from fileName: String, in folderURL: URL) throws -> String {
        let fileURL = folderURL.appendingPathComponent(fileName)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    //Check if File Exists
    static func exists(fileName: String, in folderURL: URL) -> Bool {
        let fileURL = folderURL.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    //Delete File
    static func delete(fileName: String, in folderURL: URL) throws {
        let fileURL = folderURL.appendingPathComponent(fileName)
        guard exists(fileName: fileName, in: folderURL) else {
            throw FileError.sourceNotFound(fileName)
        }
        try fileManager.removeItem(at: fileURL)
        print("Deleted '\(fileName)' from '\(folderURL.path)'")
    }

    //Move File between folders
    static func move(fileName: String, from sourceFolder: URL, to destinationFolder: URL) throws {
        let sourceURL = sourceFolder.appendingPathComponent(fileName)
        let destinationURL = destinationFolder.appendingPathComponent(fileName)

        //Check if source exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw FileError.sourceNotFound(fileName)
        }

        //Check if destination already has a file with the same name
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw FileError.destinationAlreadyExists(fileName)
        }

        //Move the file
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        print("File '\(fileName)' moved from '\(sourceFolder.path)' to '\(destinationFolder.path)'")
    }

    //List Files in Directory
    static func listFiles(in folderURL: URL) throws -> [String] {
        return try fileManager.contentsOfDirectory(atPath: folderURL.path)
    }

    //Rename File or Folder within a folder
    static func rename(oldName: String, newName: String, in folderURL: URL) throws {
        let oldURL = folderURL.appendingPathComponent(oldName)
        let newURL = folderURL.appendingPathComponent(newName)

        //Check if source exists
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: oldURL.path, isDirectory: &isDir) else {
            throw FileError.sourceNotFound(oldName)
        }

        //Check if destination already exists
        if fileManager.fileExists(atPath: newURL.path) {
            throw FileError.destinationAlreadyExists(newName)
        }

        //Rename (move) the file or folder
        do {
            try fileManager.moveItem(at: oldURL, to: newURL)
            let type = isDir.boolValue ? "Folder" : "File"
            print("\(type) renamed from '\(oldName)' to '\(newName)' in '\(folderURL.path)'")
        } catch {
            throw FileError.failedToRename(oldName, newName, underlyingError: error)
        }
    }

    //Helper to get common directories
    static func documentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func cachesDirectory() -> URL {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    static func temporaryDirectory() -> URL {
        return fileManager.temporaryDirectory
    }

    //Get detailed file information
    static func getFileInfo(for url: URL) -> FileInfo? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let resourceValues = try url.resourceValues(forKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .creationDateKey,
                .contentModificationDateKey,
                .contentAccessDateKey,
                .typeIdentifierKey
            ])

            return FileInfo(
                name: url.lastPathComponent,
                path: url.path,
                isDirectory: resourceValues.isDirectory ?? false,
                size: resourceValues.fileSize ?? 0,
                creationDate: resourceValues.creationDate,
                modificationDate: resourceValues.contentModificationDate,
                lastAccessDate: resourceValues.contentAccessDate,
                fileType: url.hasDirectoryPath ? "Folder" : url.pathExtension.mediaType
            )
        } catch {
            return nil
        }
    }

    //Get file type description


}

//File information structure
struct FileInfo {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int
    let creationDate: Date?
    let modificationDate: Date?
    let lastAccessDate: Date?
    let fileType: String

    var formattedSize: String {
        if isDirectory {
            return "--"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var formattedCreationDate: String {
        guard let date = creationDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedModificationDate: String {
        guard let date = modificationDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
