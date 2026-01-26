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

    //Create a Folder
    static func createFolder(named folderName: String, in parentURL: URL) throws {
        let folderURL = parentURL.appendingPathComponent(folderName)

        // Check if folder already exists
        if fileManager.fileExists(atPath: folderURL.path) {
            throw FileError.destinationAlreadyExists(folderURL.path)
        }

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false, attributes: nil)
            print("Folder '\(folderName)' created in '\(parentURL.path)'")
        } catch {
            throw FileError.failedToRename("", folderName, underlyingError: error)
        }
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
        // Remove lock information if the file was locked
        LockManager.shared.permanentlyRemoveLock(from: fileURL.path)
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
        // Transfer lock information if the file was locked
        LockManager.shared.transferLock(from: sourceURL.path, to: destinationURL.path)
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

            // Transfer lock information if the file was locked
            LockManager.shared.transferLock(from: oldURL.path, to: newURL.path)

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
    //Trash Folder Management
    private static let trashFolderName = ".MRFileBrowser_Trash"
    private static let trashMarkerFileName = ".trash_marker"
    /// Gets or creates the trash folder in the specified directory
    static func getTrashFolder() -> URL {
        var trashURL = documentsDirectory().appendingPathComponent(trashFolderName)
        // Create trash folder if it doesn't exist
        if !fileManager.fileExists(atPath: trashURL.path) {
            do {
                try fileManager.createDirectory(at: trashURL, withIntermediateDirectories: true, attributes: nil)
                // Make the folder hidden
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = true
                try trashURL.setResourceValues(resourceValues)
                // Create marker file to identify this as a trash folder
                var markerURL = trashURL.appendingPathComponent(trashMarkerFileName)
                let markerContent = "MRFileBrowser Trash Folder - Do not modify"
                try markerContent.write(to: markerURL, atomically: true, encoding: .utf8)
                // Hide marker file too
                try markerURL.setResourceValues(resourceValues)
                print("Created trash folder at: \(trashURL.path)")
            } catch {
                print("Failed to create trash folder: \(error)")
            }
        }
        return trashURL
    }
    /// Checks if a URL is a trash folder by looking for the marker file
    static func isTrashFolder(_ url: URL) -> Bool {
        // Check if this is the trash folder itself
        if url.lastPathComponent == trashFolderName {
            let markerURL = url.appendingPathComponent(trashMarkerFileName)
            return fileManager.fileExists(atPath: markerURL.path)
        }
        // Check if this is inside a trash folder
        var currentURL = url
        while currentURL.path != "/" && currentURL.path != currentURL.deletingLastPathComponent().path {
            if currentURL.lastPathComponent == trashFolderName {
                let markerURL = currentURL.appendingPathComponent(trashMarkerFileName)
                return fileManager.fileExists(atPath: markerURL.path)
            }
            currentURL = currentURL.deletingLastPathComponent()
        }
        return false
    }
    /// Recursively collects all locked files in a directory and maps them to their new trash locations
    private static func collectLockedFilesInDirectory(at originalPath: String, movingTo trashPath: String) -> [(String, String)] {
        var lockedFilesToTransfer: [(String, String)] = []
        guard let enumerator = fileManager.enumerator(atPath: originalPath) else {
            return lockedFilesToTransfer
        }
        // Check if the directory itself is locked
        if LockManager.shared.isFileLocked(originalPath) {
            lockedFilesToTransfer.append((originalPath, trashPath))
        }
        while let relativePath = enumerator.nextObject() as? String {
            let fullOriginalPath = (originalPath as NSString).appendingPathComponent(relativePath)
            let fullNewPath = (trashPath as NSString).appendingPathComponent(relativePath)
            if LockManager.shared.isFileLocked(fullOriginalPath) {
                lockedFilesToTransfer.append((fullOriginalPath, fullNewPath))
            }
        }
        return lockedFilesToTransfer
    }

    /// Moves a file or folder to trash instead of permanently deleting
    /// Returns the URL of the file/folder in trash
    @discardableResult
    static func moveToTrash(fileURL: URL, in baseDirectory: URL) throws -> URL {
        let trashFolder = getTrashFolder()
        let fileName = fileURL.lastPathComponent
        let destinationURL = trashFolder.appendingPathComponent(fileName)
        // If file with same name exists in trash, add timestamp
        var finalDestinationURL = destinationURL
        if fileManager.fileExists(atPath: destinationURL.path) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())
            let nameWithoutExtension = (fileName as NSString).deletingPathExtension
            let fileExtension = (fileName as NSString).pathExtension
            let newName = fileExtension.isEmpty ? "\(nameWithoutExtension)_\(timestamp)" : "\(nameWithoutExtension)_\(timestamp).\(fileExtension)"
            finalDestinationURL = trashFolder.appendingPathComponent(newName)
        }
        // Before moving, collect all locked files within the folder if it's a directory
        let originalPath = fileURL.path
        var lockedFilesToTransfer: [(String, String)] = []
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: originalPath, isDirectory: &isDirectory) && isDirectory.boolValue {
            lockedFilesToTransfer = collectLockedFilesInDirectory(at: originalPath, movingTo: finalDestinationURL.path)
        } else {
            // Single file - check if it's locked
            if LockManager.shared.isFileLocked(originalPath) {
                lockedFilesToTransfer.append((originalPath, finalDestinationURL.path))
            }
        }
        // Move the file/folder
        try fileManager.moveItem(at: fileURL, to: finalDestinationURL)
        // Transfer all collected locks
        for (oldPath, newPath) in lockedFilesToTransfer {
            LockManager.shared.transferLock(from: oldPath, to: newPath)
        }
        print("Moved '\(fileName)' to trash: \(finalDestinationURL.path)")
        return finalDestinationURL
    }
    /// Restores a file from trash to a specified location
    static func restoreFromTrash(fileURL: URL, to destinationDirectory: URL) throws {
        guard isTrashFolder(fileURL.deletingLastPathComponent()) else {
            throw FileError.sourceNotFound("File is not in trash folder")
        }
        // Ensure destination directory exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileError.sourceNotFound("Destination directory does not exist: \(destinationDirectory.path)")
        }
        let trashFileName = fileURL.lastPathComponent
        // Try to extract original filename by removing timestamp suffix
        // Pattern: filename_YYYYMMDD_HHMMSS.ext or filename_YYYYMMDD_HHMMSS (no extension)
        let originalFileName: String
        let nameWithoutExtension = (trashFileName as NSString).deletingPathExtension
        let fileExtension = (trashFileName as NSString).pathExtension
        // Check if the filename has a timestamp pattern at the end
        let timestampPattern = "_\\d{8}_\\d{6}$"
        if let regex = try? NSRegularExpression(pattern: timestampPattern, options: []) {
            let range = NSRange(location: 0, length: nameWithoutExtension.count)
            if regex.firstMatch(in: nameWithoutExtension, options: [], range: range) != nil {
                // Remove the timestamp suffix to get original name
                let originalBaseName = regex.stringByReplacingMatches(in: nameWithoutExtension, options: [], range: range, withTemplate: "")
                originalFileName = fileExtension.isEmpty ? originalBaseName : "\(originalBaseName).\(fileExtension)"
                print("Extracted original filename '\(originalFileName)' from trash filename '\(trashFileName)'")
            } else {
                // No timestamp pattern found, use the current name
                originalFileName = trashFileName
                print("No timestamp pattern found, using current filename '\(originalFileName)'")
            }
        } else {
            // Regex failed, fallback to current name
            originalFileName = trashFileName
            print("Regex creation failed, using current filename '\(originalFileName)'")
        }
        var destinationURL = destinationDirectory.appendingPathComponent(originalFileName)
        // Handle name conflicts at destination using timestamp
        if fileManager.fileExists(atPath: destinationURL.path) {
            let nameWithoutExtension = (originalFileName as NSString).deletingPathExtension
            let fileExtension = (originalFileName as NSString).pathExtension
            // Create timestamp-based name: filename_YYYYMMDD_HHMMSS
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let newName = fileExtension.isEmpty ? "\(nameWithoutExtension)_\(timestamp)" : "\(nameWithoutExtension)_\(timestamp).\(fileExtension)"
            destinationURL = destinationDirectory.appendingPathComponent(newName)
            print("Name conflict detected, renaming to: \(newName)")
        }
        // Before moving, collect all locked files that need lock transfer
        var lockedFilesToTransfer: [(String, String)] = []
        let originalPath = fileURL.path
        let finalDestinationPath = destinationURL.path
        var isDirectoryCheck: ObjCBool = false
        if fileManager.fileExists(atPath: originalPath, isDirectory: &isDirectoryCheck) && isDirectoryCheck.boolValue {
            lockedFilesToTransfer = collectLockedFilesInDirectory(at: originalPath, movingTo: finalDestinationPath)
        } else {
            // Single file - check if it's locked
            if LockManager.shared.isFileLocked(originalPath) {
                lockedFilesToTransfer.append((originalPath, finalDestinationPath))
            }
        }
        // Move the file/folder
        try fileManager.moveItem(at: fileURL, to: destinationURL)
        // Transfer all collected locks
        for (oldPath, newPath) in lockedFilesToTransfer {
            LockManager.shared.transferLock(from: oldPath, to: newPath)
        }
        print("Restored '\(originalFileName)' from trash to: \(destinationURL.path)")
    }
    /// Permanently deletes all items in the trash folder
    static func emptyTrash(in baseDirectory: URL) throws {
        let trashFolder = getTrashFolder()
        let contents = try fileManager.contentsOfDirectory(atPath: trashFolder.path)
        for item in contents {
            // Skip the marker file
            if item != trashMarkerFileName {
                let itemURL = trashFolder.appendingPathComponent(item)
                try fileManager.removeItem(at: itemURL)
                print("Permanently deleted: \(item)")
            }
        }
    }
    /// Lists all items in the trash folder
    static func listTrashContents(in baseDirectory: URL) throws -> [URL] {
        let trashFolder = getTrashFolder()
        let contents = try fileManager.contentsOfDirectory(atPath: trashFolder.path)
        return contents.compactMap { item in
            // Skip the marker file
            guard item != trashMarkerFileName else { return nil }
            return trashFolder.appendingPathComponent(item)
        }
    }

    //File Metadata Utilities

    //Gets the modification date for a file or directory
    static func getModificationDate(for url: URL) -> Date {
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
    }

    //Gets the file size for a file or directory
    static func getFileSize(for url: URL) -> Int64 {
        if url.isDirectory {
            // For directories, try to get the actual size, fallback to 0
            return (try? url.resourceValues(forKeys: [.totalFileSizeKey]))?.totalFileSize.map(Int64.init) ?? 0
        } else {
            // For files, get the file size
            return (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
        }
    }

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
