//
//  LockSetupView.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 18/01/26.
//

import SwiftUI
import LocalAuthentication

struct LockSetupView: View {
    let filePath: String
    let fileName: String
    let isDirectory: Bool
    @Binding var isPresented: Bool
    let onLockSet: () -> Void
    @State private var selectedMethod: LockMethod = .biometric
    @State private var customPIN = ""
    @State private var confirmPIN = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var biometricType: BiometricType = .none
    @Environment(\.themeConfiguration) private var theme
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundColor(theme.lockColor)
                    Text(isDirectory ? "Lock Folder" : "Lock File")
                        .font(.system(size: 22))
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primaryTextColor)
                    Text("Choose how to protect \"\(fileName)\"")
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                Divider()
                // Lock Method Selection
                VStack(spacing: 16) {
                    // Biometric Option - Always show, will fallback to device passcode if biometrics not available
                    LockMethodCard(
                        icon: biometricType != .none ? biometricType.iconName : "faceid",
                        title: biometricType != .none ? biometricType.displayName : "Device Authentication",
                        description: biometricType != .none ? "Use your device's biometric authentication" : "Use device passcode or biometrics if available",
                        isSelected: isBiometricSelected,
                        action: {
                            selectedMethod = .biometric
                        }
                    )
                    // Custom PIN Option
                    LockMethodCard(
                        icon: "number.circle",
                        title: "Custom PIN",
                        description: "Set a custom PIN code for this file",
                        isSelected: isPINSelected,
                        action: {
                            selectedMethod = .customPIN("")
                        }
                    )
                    // PIN Entry (only shown if Custom PIN is selected)
                    if isPINSelected {
                        VStack(spacing: 12) {
                            SecureField("Enter 4-digit PIN", text: customPINBinding)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                            SecureField("Confirm PIN", text: confirmPINBinding)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                Spacer()
                // Action Buttons
                VStack(spacing: 12) {
                    Button(isDirectory ? "Lock Folder" : "Lock File") {
                        lockFile()
                    }
                    .buttonStyle(PrimaryButtonStyle(theme: theme))
                    .disabled(!canLockFile)
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(SecondaryButtonStyle(theme: theme))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
//            .navigationTitle("Lock Setup")
//            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            checkBiometricAvailability()
        }
    }
    private var isBiometricSelected: Bool {
        if case .biometric = selectedMethod {
            return true
        }
        return false
    }
    private var isPINSelected: Bool {
        if case .customPIN = selectedMethod {
            return true
        }
        return false
    }
    private var canLockFile: Bool {
        switch selectedMethod {
        case .biometric:
            return true // Always allow biometric selection, will fallback to device passcode
        case .customPIN:
            return customPIN.count == 4 && customPIN == confirmPIN
        }
    }
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
        // Default to biometric (will use device authentication if biometrics not available)
        selectedMethod = .biometric
    }
    private func lockFile() {
        let finalMethod: LockMethod
        switch selectedMethod {
        case .biometric:
            finalMethod = .biometric
        case .customPIN:
            if customPIN.count != 4 {
                showError(message: "PIN must be exactly 4 digits")
                return
            }
            if customPIN != confirmPIN {
                showError(message: "PIN codes don't match")
                return
            }
            finalMethod = .customPIN(customPIN)
        }
        LockManager.shared.lockFile(at: filePath, with: finalMethod)
        onLockSet()
        isPresented = false
    }
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    // Custom bindings for PIN validation
    private var customPINBinding: Binding<String> {
        Binding(
            get: { customPIN },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                customPIN = String(filtered.prefix(4))
            }
        )
    }
    private var confirmPINBinding: Binding<String> {
        Binding(
            get: { confirmPIN },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                confirmPIN = String(filtered.prefix(4))
            }
        )
    }
}

// MARK: - Lock Method Card
struct LockMethodCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.themeConfiguration) private var theme
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.primaryColor)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(theme.primaryTextColor)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryTextColor)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(theme.primaryColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? theme.primaryColor.opacity(0.1) : theme.secondaryBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? theme.selectedBorderColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }
}

// MARK: - Biometric Type
enum BiometricType {
    case none, touchID, faceID
    var iconName: String {
        switch self {
        case .none:
            return "person.circle"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        }
    }
    var displayName: String {
        switch self {
        case .none:
            return "Device Authentication"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    let theme: ThemeConfiguration

    init(theme: ThemeConfiguration = .blue) {
        self.theme = theme
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(theme.textOnPrimaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.primaryColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let theme: ThemeConfiguration

    init(theme: ThemeConfiguration = .blue) {
        self.theme = theme
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(theme.primaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.primaryColor, lineWidth: 2)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
