//
//  Extn.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 06/12/25.
//

import Foundation

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
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
