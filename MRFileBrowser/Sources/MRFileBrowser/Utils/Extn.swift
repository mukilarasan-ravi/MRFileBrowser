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
}
