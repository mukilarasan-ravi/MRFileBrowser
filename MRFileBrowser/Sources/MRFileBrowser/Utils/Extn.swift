//
//  Extn.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 06/12/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
    /// Checks if this URL represents a trash folder
    var isTrashFolder: Bool {
        return FileUtils.isTrashFolder(self)
    }
    var displayName: String {
        // Only show "Trash" for the actual trash folder itself, not items inside it
        if self.lastPathComponent == ".MRFileBrowser_Trash" && FileUtils.isTrashFolder(self) {
            return "Trash"
        }
        return self.lastPathComponent
    }
    var fileType: String {
        let ext = self.pathExtension

        if #available(iOS 14.0, *) {
            if let type = UTType(filenameExtension: ext) {
                return type.localizedDescription ?? ext.uppercased()
            }
        } else {
            if let uti = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension,
                ext as CFString,
                nil
            )?.takeRetainedValue(),
               let description = UTTypeCopyDescription(uti)?.takeRetainedValue() {
                return description as String
            }
        }

        return ext.uppercased()
    }
}
extension String {
    var mediaType: String {
        switch self.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "bmp", "tiff": return "Image"
        case "mp4", "mov", "m4v", "avi", "mkv": return "Video"
        case "mp3", "wav", "aac", "flac": return "Audio"
        case "pdf": return "PDF Document"
        case "zip", "7z", "tar.gz", "rar", "tar": return "Archive"
        case "txt", "rtf": return "Text Document"
        case "csv": return "CSV File"
        case "json": return "JSON File"
        case "html": return "HTML File"
        case "doc", "docx": return "Word Document"
        case "xls", "xlsx": return "Excel Spreadsheet"
        case "ppt", "pptx": return "PowerPoint Presentation"
        default: return self.isEmpty ? "File" : self.uppercased() + " File"
        }
    }

    var fileExtension: String {
        return (self as NSString).pathExtension
    }
    // MARK: - File Type Icon Helpers
    var fileTypeIcon: String {
        let ext = self.lowercased()
        switch ext {
        // Images
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif":
            return "photo.on.rectangle"
        // Videos
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v":
            return "play.rectangle"
        // Audio
        case "mp3", "wav", "aac", "flac", "ogg", "wma", "m4a":
            return "waveform"
        // Documents
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx", "csv", "numbers":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.on.rectangle"
        case "txt", "rtf":
            return "doc.plaintext"
        // Code files
        case "swift", "js", "py", "java", "cpp", "c", "h", "html", "css", "php", "rb", "go", "rs":
            return "curlybraces"
        // Archives
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        // Default
        default:
            return "doc"
        }
    }

}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
public func actionButton(
    _ title: String,
    icon: String? = nil, // Optional icon
    isDestructive: Bool = false,
    backgroundColor: Color = Color(.systemGray6), // Default background
    width: CGFloat? = nil, // Optional width
    textAlignment: HorizontalAlignment = .leading,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        HStack {
            if let icon = icon, !icon.isEmpty { // Only show if icon exists
                Image(systemName: icon)
                    .frame(width: 24)
            }

            Text(title)
                .font(.system(size: 16))

        }
        .foregroundColor(isDestructive ? .red : .primary)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: width ?? .infinity, alignment: Alignment(horizontal: textAlignment, vertical: .center))
        .background(backgroundColor)
        .cornerRadius(10)
    }
    .buttonStyle(.plain)
}

struct AlertPrompt: View {
    var title: String
    var placeHolder: String? = nil
    var okButtonText: String = "OK"
    var cancelButtonText: String = "Cancel"
    var disableCancelButton: Bool = false

    @Binding var name: String
    @Binding var isPresented: Bool

    let onOK: () -> Void
    let onCancel: () -> Void

    private var okButton: some View {
        actionButton(okButtonText, backgroundColor: .blue, textAlignment: .center) {
                onOK()
                isPresented = false
            }
        }

        private var cancelButton: some View {
            actionButton(cancelButtonText, isDestructive: true, textAlignment: .center) {
                onCancel()
                isPresented = false
            }
        }

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        onCancel()
                        isPresented = false
                    }

                VStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    if let placeHolder = placeHolder {
                        TextField(placeHolder, text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                    }

                    Divider()

                    VStack(spacing: 10) {
                        okButton
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 30)
                            .contentShape(Rectangle())
                    }
                    if(!disableCancelButton){
                        Divider()
                        VStack(spacing: 10) {
                            cancelButton
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 30)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.vertical, 16)
                .frame(width: 270)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(radius: 20)
            }
            .transition(.opacity)
            .animation(.easeInOut)
        }
    }

}

public struct FolderNode {
    public let id = UUID()
    public let url: URL
    public let level: Int
    public let hasSubfolders: Bool
    public let subfolders: [URL]

    public init(url: URL, level: Int, hasSubfolders: Bool, subfolders: [URL]) {
        self.url = url
        self.level = level
        self.hasSubfolders = hasSubfolders
        self.subfolders = subfolders
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

//UI Related Functions
struct UIHelpers {
    static func actionButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    static func sortActionButton(for option: SortOption, menuCoordinator: MenuCoordinator, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(width: 24, height: 24)

                Text(option.displayName)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()
                if menuCoordinator.sortBy == option {
                    Text(menuCoordinator.sortOrder == .ascending ? "↑" : "↓")
                        .foregroundColor(.blue.opacity(0.7))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

//Clipboard Utilities
extension UIPasteboard {
    /// Copies text to clipboard with haptic feedback
    static func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text

        // Show haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    /// Copies text to clipboard with haptic feedback and optional toast notification
    static func copyToClipboard(_ text: String, showToast: Bool = true) {
        UIPasteboard.general.string = text

        // Show haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Show success toast if requested
        if showToast {
            Toast.showSuccess("Copied.")
        }
    }
}

// Toast Utilities

/// Configuration for toast appearance and behavior
struct ToastConfiguration {
    let message: String
    let icon: String?
    let backgroundColor: Color
    let textColor: Color
    let buttonTitle: String?
    let buttonAction: (() -> Void)?
    let autoHideDelay: TimeInterval
    let allowSwipeToDismiss: Bool

    init(
        message: String,
        icon: String? = "checkmark.circle.fill",
        backgroundColor: Color = Color.blue.opacity(0.7),
        textColor: Color = .white,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil,
        autoHideDelay: TimeInterval = 3.0,
        allowSwipeToDismiss: Bool = true
    ) {
        self.message = message
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
        self.autoHideDelay = autoHideDelay
        self.allowSwipeToDismiss = allowSwipeToDismiss
    }
}

/// Global Toast Manager - Singleton for app-wide toast management
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var isVisible = false
    @Published var configuration: ToastConfiguration?

    private var hideTimer: Timer?

    private init() {} // Private init for singleton

    /// Show toast with configuration
    func show(_ config: ToastConfiguration) {
        // Cancel any existing timer
        hideTimer?.invalidate()

        configuration = config
        isVisible = true

        // Auto-hide if delay is greater than 0
        if config.autoHideDelay > 0 {
            hideTimer = Timer.scheduledTimer(withTimeInterval: config.autoHideDelay, repeats: false) { _ in
                self.hide()
            }
        }
    }

    /// Hide the toast
    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        isVisible = false
    }
}

/// Static Toast utility functions
struct Toast {
    /// Show success toast with optional action button
    static func showSuccess(
        _ message: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        let config = ToastConfiguration(
            message: message,
            icon: "checkmark.circle.fill",
            backgroundColor: Color.blue.opacity(0.7),
            buttonTitle: buttonTitle,
            buttonAction: buttonAction
        )
        ToastManager.shared.show(config)
    }

    /// Show error toast
    static func showError(_ message: String) {
        let config = ToastConfiguration(
            message: message,
            icon: "xmark.circle.fill",
            backgroundColor: Color.red.opacity(0.8)
        )
        ToastManager.shared.show(config)
    }

    /// Show info toast with optional action button
    static func showInfo(
        _ message: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        let config = ToastConfiguration(
            message: message,
            icon: "info.circle.fill",
            backgroundColor: Color.blue.opacity(0.7),
            buttonTitle: buttonTitle,
            buttonAction: buttonAction
        )
        ToastManager.shared.show(config)
    }

    /// Show custom toast with full configuration
    static func show(_ config: ToastConfiguration) {
        ToastManager.shared.show(config)
    }

    /// Hide current toast
    static func hide() {
        ToastManager.shared.hide()
    }
}

/// Reusable Toast View Component
struct ToastView: View {
    let configuration: ToastConfiguration
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            // Icon (optional)
            if let icon = configuration.icon {
                Image(systemName: icon)
                    .foregroundColor(configuration.textColor)
                    .font(.system(size: 20))
            }

            // Message
            Text(configuration.message)
                .foregroundColor(configuration.textColor)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)

            Spacer()

            // Action button (optional)
            if let buttonTitle = configuration.buttonTitle,
               let buttonAction = configuration.buttonAction {
                Button(buttonTitle) {
                    buttonAction()
                }
                .foregroundColor(configuration.textColor)
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(configuration.backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
        .gesture(
            configuration.allowSwipeToDismiss ? 
            DragGesture()
                .onEnded { gesture in
                    // If swipe down (positive height translation > 50)
                    if gesture.translation.height > 50 {
                        onDismiss()
                    }
                } : nil
        )
    }
}

/// View modifier for adding toast functionality to any view
struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager: ToastManager = ToastManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            if toastManager.isVisible, let config = toastManager.configuration {
                VStack {
                    Spacer()
                    ToastView(configuration: config) {
                        toastManager.hide()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Position above bottom bar
                }
                .zIndex(10000)
                .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.3), value: toastManager.isVisible)
            }
        }
    }
}

extension View {
    /// Add toast functionality to any view
    func toast() -> some View {
        self.modifier(ToastModifier())
    }
}
