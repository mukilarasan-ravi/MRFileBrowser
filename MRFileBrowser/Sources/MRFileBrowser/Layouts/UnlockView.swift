//
//  UnlockView.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 18/01/26.
//

import SwiftUI
import LocalAuthentication

struct UnlockView: View {
    let filePath: String
    let fileName: String
    @Binding var isPresented: Bool
    let onUnlock: () -> Void
    let isPermanentUnlock: Bool // Add this parameter
    @State private var enteredPIN = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAttempting = false
    @State private var showBiometricButton = false
    @State private var shakeOffset: CGFloat = 0
    private let lockManager = LockManager.shared
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)
            // Header
            VStack(spacing: 15) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 50, weight: .thin))
                    .foregroundColor(.primary)
                Text("Enter Passcode")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.primary)
                Text(fileName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Spacer(minLength: 30)
                // PIN Dots
                VStack(spacing: 10) {
                    HStack(spacing: 22) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                                .background(
                                    Circle()
                                        .fill(index < enteredPIN.count ? Color.primary : Color.clear)
                                )
                                .frame(width: 15, height: 15)
                        }
                    }
                    .offset(x: shakeOffset)
                    .animation(.easeInOut(duration: 0.1), value: shakeOffset)
                    // Error Message
                    Group {
                        if showError {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .transition(.opacity)
                        } else {
                            Text(" ")
                                .font(.system(size: 14))
                        }
                    }
                    .frame(height: 20)
                }
                // Number Pad - Native iOS Style
                VStack(spacing: 15) {
                    // Rows 1-3
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 25) {
                            ForEach(1...3, id: \.self) { col in
                                let number = row * 3 + col
                                NumberPadButton(
                                    number: "\(number)",
                                    action: { addDigit("\(number)") }
                                )
                            }
                        }
                    }
                    // Bottom row (cancel, 0, delete)
                    HStack(spacing: 25) {
                        // Cancel button (X icon)
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(width: 65, height: 70)
                        }
                        // Zero
                        NumberPadButton(
                            number: "0",
                            action: { addDigit("0") }
                        )
                        // Delete
                        Button(action: deleteDigit) {
                            Image(systemName: "delete.backward.fill")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(width: 65, height: 70)
                        }
                        .disabled(enteredPIN.isEmpty)
                        .opacity(enteredPIN.isEmpty ? 0.3 : 1.0)
                    }
                }
                Spacer(minLength: 20)
            }
            .onAppear {
                enteredPIN = ""
                showError = false
                checkBiometricAvailability()
            }
    }
    private func addDigit(_ digit: String) {
        if enteredPIN.count < 4 {
            enteredPIN += digit
            showError = false
            if enteredPIN.count == 4 {
                validatePIN()
            }
        }
    }
    private func deleteDigit() {
        if !enteredPIN.isEmpty {
            enteredPIN.removeLast()
            showError = false
        }
    }
    private func validatePIN() {
        guard !isAttempting else { return }
        isAttempting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if lockManager.validatePIN(enteredPIN, for: filePath) {
                // PIN is correct
                if isPermanentUnlock {
                    // Permanently remove the lock
                    lockManager.permanentlyRemoveLock(from: filePath)
                }
                onUnlock()
                isPresented = false
            } else {
                // PIN is incorrect
                showError(message: "Incorrect PIN. Try again.")
                enteredPIN = ""
            }
            isAttempting = false
        }
    }
    private func showError(message: String) {
        errorMessage = message
        withAnimation {
            showError = true
        }
        // Trigger shake animation
        withAnimation(.easeInOut(duration: 0.1)) {
            shakeOffset = -10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = -5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 0
            }
        }
    }
    //Biometric Authentication
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        // Only show biometric button if file doesn't have custom PIN and biometrics are available
        if !lockManager.hasCustomPIN(filePath) && context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            showBiometricButton = true
        }
    }
    private func biometricIcon() -> String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if #available(iOS 11.0, *) {
                switch context.biometryType {
                case .faceID:
                    return "faceid"
                case .touchID:
                    return "touchid"
                default:
                    return "faceid"
                }
            }
        }
        return "faceid"
    }
    private func tryBiometricAuthentication() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock \(fileName)"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        // Biometric authentication successful
                        if self.isPermanentUnlock {
                            // Permanently remove the lock
                            self.lockManager.permanentlyRemoveLock(from: self.filePath)
                        }
                        self.onUnlock()
                        self.isPresented = false
                    } else {
                        // Biometric authentication failed, let user continue with PIN entry
                        if let error = authError as? LAError {
                            switch error.code {
                            case .userCancel, .userFallback:
                                // User cancelled or chose to enter PIN, do nothing
                                break
                            case .biometryNotAvailable, .biometryNotEnrolled:
                                self.showError(message: "Biometric authentication not available")
                            case .biometryLockout:
                                self.showError(message: "Biometric authentication locked. Use PIN.")
                            default:
                                self.showError(message: "Biometric authentication failed")
                            }
                        }
                    }
                }
            }
        } else {
            // Fallback to device passcode
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let reason = "Unlock \(fileName)"
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                    DispatchQueue.main.async {
                        if success {
                            if self.isPermanentUnlock {
                                self.lockManager.permanentlyRemoveLock(from: self.filePath)
                            }
                            self.onUnlock()
                            self.isPresented = false
                        } else {
                            self.showError(message: "Device authentication failed")
                        }
                    }
                }
            } else {
                showError(message: "Authentication not available")
            }
        }
    }
}

//Number Pad Button
struct NumberPadButton: View {
    let number: String
    let action: () -> Void
    @State private var isPressed = false
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.primary)
                .frame(width: 65, height: 70)
                .background(
                    Circle()
                        .fill(isPressed ? Color.primary.opacity(0.1) : Color.clear)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
