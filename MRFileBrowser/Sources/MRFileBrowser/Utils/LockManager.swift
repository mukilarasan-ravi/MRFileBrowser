//
//  LockManager.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 18/01/26.
//

import Foundation
import LocalAuthentication
import SwiftUI
import Combine

//Lock Manager
class LockManager: ObservableObject {
    static let shared = LockManager()
    @Published var lockedFiles: Set<String> = []
    @Published var showAuthPrompt = false
    @Published var pendingUnlockFile: String?
    @Published var pendingAction: (() -> Void)?
    private let keychain = KeychainHelper()
    private let lockedFilesKey = "MRFileBrowser.LockedFiles"
    // Get the current Documents directory
    private var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    // Convert absolute path to relative path (relative to Documents directory)
    private func absoluteToRelative(_ absolutePath: String) -> String {
        let documentsPath = documentsDirectory.path
        let normalizedAbsolutePath = normalizePath(absolutePath)
        let normalizedDocumentsPath = normalizePath(documentsPath)
        if normalizedAbsolutePath.hasPrefix(normalizedDocumentsPath) {
            let relativePath = String(normalizedAbsolutePath.dropFirst(normalizedDocumentsPath.count + 1)) // +1 to remove leading slash
            return relativePath
        }
        return normalizedAbsolutePath // Return normalized path if not in Documents
    }
    // Convert relative path to absolute path (relative to current Documents directory)
    private func relativeToAbsolute(_ relativePath: String) -> String {
        return documentsDirectory.appendingPathComponent(relativePath).path
    }
    init() {
        loadLockedFiles()
    }
    //Lock Management
    func lockFile(at path: String, with method: LockMethod) {
        let normalizedPath = normalizePath(path)
        switch method {
        case .biometric:
            // For biometric, we don't store a PIN, just mark as locked
            addToLockedFiles(normalizedPath)
        case .customPIN(let pin):
            // Store the PIN in keychain
            keychain.store(pin, forKey: pinKeyForFile(normalizedPath))
            addToLockedFiles(normalizedPath)
        }
    }
    func unlockFile(at path: String, completion: @escaping (Bool) -> Void) {
        guard isFileLocked(path) else {
            completion(true)
            return
        }
        // Check if file has custom PIN
        if let _ = keychain.retrieve(forKey: pinKeyForFile(path)) {
            // File has custom PIN, show PIN entry
            pendingUnlockFile = path
            pendingAction = { [weak self] in
                completion(true)
                // Don't remove from locked files - just grant temporary access
            }
            showAuthPrompt = true
        } else {
            // File uses biometric authentication
            authenticateWithBiometrics { success in
                // Don't remove from locked files - just grant temporary access
                completion(success)
            }
        }
    }
    func isFileLocked(_ path: String) -> Bool {
        let normalizedPath = normalizePath(path)
        let normalizedLockedFiles = lockedFiles.map { normalizePath($0) }
        let isLocked = normalizedLockedFiles.contains(normalizedPath)
        return isLocked
    }
    // Normalize path by removing /private prefix if present
    private func normalizePath(_ path: String) -> String {
        if path.hasPrefix("/private") {
            return String(path.dropFirst(8)) // Remove "/private"
        }
        return path
    }
    func hasCustomPIN(_ path: String) -> Bool {
        let normalizedPath = normalizePath(path)
        return keychain.retrieve(forKey: pinKeyForFile(normalizedPath)) != nil
    }
    //Permanent Lock Removal
    func permanentlyRemoveLock(from path: String) {
        let normalizedPath = normalizePath(path)
        removeFromLockedFiles(normalizedPath)
    }
    //Lock Transfer Methods
    func transferLock(from oldPath: String, to newPath: String) {
        let normalizedOldPath = normalizePath(oldPath)
        let normalizedNewPath = normalizePath(newPath)
        guard isFileLocked(normalizedOldPath) else { return }
        // Check if the old file has a custom PIN
        let oldPinKey = pinKeyForFile(normalizedOldPath)
        let newPinKey = pinKeyForFile(normalizedNewPath)
        if let pin = keychain.retrieve(forKey: oldPinKey) {
            // Transfer the PIN to the new path
            keychain.store(pin, forKey: newPinKey)
            keychain.delete(forKey: oldPinKey)
        }
        // Remove from old path and add to new path
        DispatchQueue.main.async {
            self.lockedFiles.remove(normalizedOldPath)
            self.lockedFiles.insert(normalizedNewPath)
            self.saveLockedFiles()
        }
    }
    //Authentication
    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock this file to access its contents"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // Fallback to device passcode
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let reason = "Unlock this file to access its contents"
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                    DispatchQueue.main.async {
                        completion(success)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    func validatePIN(_ pin: String, for path: String) -> Bool {
        let normalizedPath = normalizePath(path)
        guard let storedPIN = keychain.retrieve(forKey: pinKeyForFile(normalizedPath)) else {
            return false
        }
        return pin == storedPIN
    }
    //Private Methods
    private func addToLockedFiles(_ path: String) {
        DispatchQueue.main.async {
            self.lockedFiles.insert(path)
            self.saveLockedFiles()
        }
    }
    private func removeFromLockedFiles(_ path: String) {
        DispatchQueue.main.async {
            self.lockedFiles.remove(path)
            self.keychain.delete(forKey: self.pinKeyForFile(path)) // Clean up PIN if exists
            self.saveLockedFiles()
        }
    }
    private func pinKeyForFile(_ path: String) -> String {
        let relativePath = absoluteToRelative(path)
        return "PIN_\(relativePath.replacingOccurrences(of: "/", with: "_"))"
    }
    private func saveLockedFiles() {
        let relativePaths = lockedFiles.map { absoluteToRelative($0) }
        UserDefaults.standard.set(relativePaths, forKey: lockedFilesKey)
        UserDefaults.standard.synchronize() // Force save to disk
    }
    private func loadLockedFiles() {
        if let storedPaths = UserDefaults.standard.array(forKey: lockedFilesKey) as? [String] {
            // Check if the stored paths are already relative paths or need migration
            var relativePaths: [String] = []
            for path in storedPaths {
                // Check if it's already a relative path (doesn't start with / and doesn't contain full simulator paths)
                if !path.hasPrefix("/") && !path.contains("/Library/Developer/CoreSimulator/") {
                    // This is already a relative path
                    relativePaths.append(path)
                } else if path.contains("/Documents/") {
                    // This is an old absolute path, extract the relative part after /Documents/
                    if let documentsRange = path.range(of: "/Documents/") {
                        let afterDocuments = String(path[documentsRange.upperBound...])
                        relativePaths.append(afterDocuments)
                    }
                }
            }
            // Remove duplicates
            relativePaths = Array(Set(relativePaths))
            if relativePaths.isEmpty {
                UserDefaults.standard.removeObject(forKey: lockedFilesKey)
                UserDefaults.standard.synchronize()
                return
            }
            // Convert relative paths to absolute paths for current session
            let absolutePaths = relativePaths.map { relativeToAbsolute($0) }
            DispatchQueue.main.async {
                self.lockedFiles = Set(absolutePaths)
            }
            // Save the cleaned up relative paths back to UserDefaults
            UserDefaults.standard.set(relativePaths, forKey: lockedFilesKey)
            UserDefaults.standard.synchronize()
        } else {
        }
    }
}

//Lock Method Enum
enum LockMethod {
    case biometric
    case customPIN(String)
}

//Keychain Helper
class KeychainHelper {
    func store(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    func retrieve(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
