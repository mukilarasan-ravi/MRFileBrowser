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
