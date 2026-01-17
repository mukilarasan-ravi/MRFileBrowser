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
        case "jpg", "jpeg", "png", "gif", "heic": return "Image"
        case "mp4", "mov", "m4v": return "Video"
        case "pdf": return "PDF Document"
        case "zip","7z", "tar.gz", "rar": return "Archive"
        case "txt": return "Text File"
        case "csv": return "CSV File"
        case "json": return "JSON File"
        case "html": return "HTML File"
        default: return self.isEmpty ? "File" : self.uppercased() + " File"
        }
    }

    var fileExtension: String {
        return (self as NSString).pathExtension
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
