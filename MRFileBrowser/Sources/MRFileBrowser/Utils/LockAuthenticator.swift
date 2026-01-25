//
//  LockAuthenticator.swift
//  MRFileBrowser
//
//  Created on 25/01/26.
//

import Foundation

class LockAuthenticator {
    static func performActionWithLockCheck(
        for url: URL,
        menuCoordinator: MenuCoordinator,
        onSuccess: @escaping () -> Void,
        pendingAction: (() -> Void)? = nil
    ) {
        // Check if file/folder is locked before allowing action
        if LockManager.shared.isFileLocked(url.path) {
            if !LockManager.shared.hasCustomPIN(url.path) {
                // Biometric lock - trigger authentication directly
                LockManager.shared.authenticateWithBiometrics { success in
                    if success {
                        // Access granted, proceed with the action
                        onSuccess()
                    } else {
                        // Biometric failed, show custom UnlockView with pending action
                        menuCoordinator.showUnlockView(for: url, pendingAction: pendingAction ?? onSuccess)
                    }
                }
            } else {
                // Custom PIN - show UnlockView with pending action
                menuCoordinator.showUnlockView(for: url, pendingAction: pendingAction ?? onSuccess)
            }
            return
        }
        // File/folder is not locked, proceed with the action
        onSuccess()
    }

    static func performTapWithLockCheck(
        for url: URL,
        menuCoordinator: MenuCoordinator,
        onSuccess: @escaping () -> Void
    ) {
        performActionWithLockCheck(
            for: url,
            menuCoordinator: menuCoordinator,
            onSuccess: onSuccess
        )
    }

    static func performMenuActionWithLockCheck(
        for url: URL,
        menuCoordinator: MenuCoordinator,
        action: @escaping () -> Void
    ) {
        performActionWithLockCheck(
            for: url,
            menuCoordinator: menuCoordinator,
            onSuccess: action,
            pendingAction: action
        )
    }
}