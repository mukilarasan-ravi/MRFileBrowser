//
//  HTTPServerHTMLProvider.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 27/01/26.
//

import Foundation

//HTML Provider Protocol
public protocol HTTPServerHTMLProvider {
    //Generate complete HTML for directory listing
    // -Parameter directoryListing: The directory data to display
    // -Returns: Complete HTML string
    func generateDirectoryListingHTML(for directoryListing: DirectoryListing) -> String

    //Generate HTML for individual file items (optional, used by default implementation)
    // -Parameter item: The file item to generate HTML for
    // -Returns: HTML string for the item
    func generateFileItemHTML(for item: FileItem) -> String

    //Generate CSS styles (optional, used by default implementation)
    // -Returns: CSS styles string
    func generateCSS() -> String

    //Generate header HTML (optional, used by default implementation)
    // -Parameter directoryListing: The directory data
    // -Returns: HTML string for the header
    func generateHeaderHTML(for directoryListing: DirectoryListing) -> String

    //Check if an item should be shown/accessible based on its lock status
    // -Parameter item: The file item to check
    // -Returns: True if the item should be accessible, false otherwise
    func shouldShowItem(_ item: FileItem) -> Bool

    //Generate HTML for access denied page when content is locked
    // -Parameters:
    //  -item: The locked item that was requested
    //  -reason: Reason for denial (LockReason enum)
    //  -Returns: Complete HTML page for access denied
    func generateAccessDeniedHTML(for item: FileItem, reason: LockReason) -> String
}

//Default HTML Provider Implementation
public class DefaultHTMLProvider: HTTPServerHTMLProvider {

    private let showLockedItems: Bool
    private let showParentLockedItems: Bool

    public init(showLockedItems: Bool = true, showParentLockedItems: Bool = true) {
        self.showLockedItems = showLockedItems
        self.showParentLockedItems = showParentLockedItems
    }

    public func generateDirectoryListingHTML(for directoryListing: DirectoryListing) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>\(directoryListing.title)</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
        \(generateCSS())
            </style>
        </head>
        <body>
        \(generateHeaderHTML(for: directoryListing))
        """

        // Add parent directory link if not at root
        if !directoryListing.isRoot, let parentPath = directoryListing.parentPath {
            // Ensure parent path is properly formatted for URL
            let parentURL = parentPath.isEmpty ? "" : parentPath
            let parentItem = FileItem(name: ".. (Parent Directory)", path: parentURL, isDirectory: true, size: nil, modificationDate: nil, fileExtension: "", isLocked: false, isParentLocked: false)
            html += generateFileItemHTML(for: parentItem)
        }

        // Filter and add items based on lock visibility settings
        let filteredItems = directoryListing.items.filter { item in
            return shouldShowItem(item)
        }

        // Add filtered items
        for item in filteredItems {
            html += generateFileItemHTML(for: item)
        }

        html += "</body></html>"
        return html
    }

    public func generateFileItemHTML(for item: FileItem) -> String {
        let baseIcon = item.isDirectory ? "&#x1F4C1;" : getFileIcon(for: item.fileExtension)
        let directLockIcon = item.isLocked ? "&#x1F512;" : ""
        let parentLockIcon = item.isParentLocked ? "&#x1F6E1;" : ""
        let lockIcon = "\(directLockIcon)\(parentLockIcon)"
        let icon = lockIcon.isEmpty ? baseIcon : "\(lockIcon) \(baseIcon)"
        let sizeText = item.isDirectory ? "" : FileUtils.formatFileSize(item.size ?? 0)
        let isAnyLocked = item.isLocked || item.isParentLocked
        let cssClass = isAnyLocked ? "item locked-item" : "item"

        // Generate proper absolute URL
        var url: String
        if item.path.isEmpty {
            // Root directory
            url = "/"
        } else {
            // Ensure path starts with / and ends with / for directories
            let cleanPath = item.path.hasPrefix("/") ? String(item.path.dropFirst()) : item.path
            if item.isDirectory {
                url = cleanPath.isEmpty ? "/" : "/\(cleanPath)/"
            } else {
                url = "/\(cleanPath)"
            }
        }

        var lockText = ""
        if item.isLocked && item.isParentLocked {
            lockText = " (Locked + Parent Locked)"
        } else if item.isLocked {
            lockText = " (Locked)"
        } else if item.isParentLocked {
            lockText = " (Parent Locked)"
        }

        return """
        <a href='\(url)' class='\(cssClass)'>
            <span class='icon'>\(icon)</span>
            <span class='name'>\(item.name)\(lockText)</span>
            <span class='size'>\(sizeText)</span>
        </a>
        """
    }

    public func generateCSS() -> String {
        return """
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }
            .header { background: #007AFF; color: white; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
            .item { display: flex; align-items: center; padding: 10px; border-bottom: 1px solid #eee; text-decoration: none; color: black; }
            .item:hover { background: #f5f5f5; }
            .locked-item { opacity: 0.7; background: #fff8dc; }
            .locked-item:hover { background: #f0e68c; }
            .icon { margin-right: 10px; width: 20px; }
            .name { flex: 1; }
            .size { color: #666; margin-left: 10px; }
        """
    }

    public func generateHeaderHTML(for directoryListing: DirectoryListing) -> String {
        return """
        <div class="header">
            <h2>&#x1F4C1; \(directoryListing.title)</h2>
        </div>
        """
    }

    public func shouldShowItem(_ item: FileItem) -> Bool {
        // Show item if it's not locked at all
        if !item.isLocked && !item.isParentLocked {
            return true
        }

        // Check if we should show directly locked items
        if item.isLocked && !showLockedItems {
            return false
        }

        // Check if we should show parent locked items
        if item.isParentLocked && !showParentLockedItems {
            return false
        }

        return true
    }

    public func generateAccessDeniedHTML(for item: FileItem, reason: LockReason) -> String {
        let iconType = item.isDirectory ? "&#x1F4C1;" : getFileIcon(for: item.fileExtension)
        let lockIcon = reason == .locked ? "&#x1F512;" : "&#x1F6E1;" // lock or shield
        let reasonText = reason.description

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Access Denied - \(item.name)</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
                    margin: 0; 
                    padding: 20px;
                    background: linear-gradient(135deg, #ff6b6b, #ee5a24);
                    color: white;
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .container {
                    text-align: center;
                    background: rgba(0,0,0,0.3);
                    padding: 40px;
                    border-radius: 20px;
                    backdrop-filter: blur(10px);
                    box-shadow: 0 20px 40px rgba(0,0,0,0.3);
                    max-width: 500px;
                }
                .icon {
                    font-size: 4em;
                    margin-bottom: 20px;
                    display: block;
                }
                .lock-icon {
                    font-size: 2em;
                    opacity: 0.9;
                }
                h1 {
                    margin: 0 0 20px 0;
                    font-size: 2em;
                    font-weight: 300;
                }
                .item-info {
                    background: rgba(255,255,255,0.1);
                    padding: 20px;
                    border-radius: 10px;
                    margin: 20px 0;
                }
                .item-name {
                    font-size: 1.2em;
                    font-weight: bold;
                    margin-bottom: 10px;
                }
                .reason {
                    opacity: 0.9;
                    line-height: 1.6;
                }
                .back-btn {
                    display: inline-block;
                    margin-top: 30px;
                    padding: 12px 24px;
                    background: rgba(255,255,255,0.2);
                    color: white;
                    text-decoration: none;
                    border-radius: 25px;
                    transition: all 0.3s ease;
                    border: 1px solid rgba(255,255,255,0.3);
                }
                .back-btn:hover {
                    background: rgba(255,255,255,0.3);
                    transform: translateY(-2px);
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="lock-icon">\(lockIcon)</div>
                <h1>Access Denied</h1>

                <div class="item-info">
                    <div class="icon">\(iconType)</div>
                    <div class="item-name">\(item.name)</div>
                    <div class="reason">\(reasonText)</div>
                </div>

                <p>You don't have permission to access this content.</p>

                <a href="javascript:history.back()" class="back-btn">&#x2190; Go Back</a>
            </div>
        </body>
        </html>
        """
    }

    //Helper Methods
    private func getFileIcon(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "jpg", "jpeg", "png", "gif", "bmp", "svg":
            return "&#x1F5BC;&#xFE0F;"
        case "mp4", "mov", "avi", "mkv":
            return "&#x1F3AC;"
        case "mp3", "wav", "aac", "flac":
            return "&#x1F3B5;"
        case "pdf":
            return "&#x1F4C4;"
        case "doc", "docx":
            return "&#x1F4DD;"
        case "xls", "xlsx":
            return "&#x1F4CA;"
        case "ppt", "pptx":
            return "&#x1F4CB;"
        case "zip", "rar", "7z":
            return "&#x1F4E6;"
        case "txt":
            return "&#x1F4C3;"
        default:
            return "&#x1F4C4;"
        }
    }
}

//Custom HTML Provider Examples

//Example: Dark Theme HTML Provider
public class DarkThemeHTMLProvider: DefaultHTMLProvider {

    public override func generateCSS() -> String {
        return """
            body { 
                font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
                margin: 20px; 
                background: #1a1a1a; 
                color: #ffffff; 
            }
            .header { 
                background: #2d2d2d; 
                color: #ffffff; 
                padding: 15px; 
                border-radius: 8px; 
                margin-bottom: 20px; 
                border: 1px solid #404040;
            }
            .item { 
                display: flex; 
                align-items: center; 
                padding: 10px; 
                border-bottom: 1px solid #404040; 
                text-decoration: none; 
                color: #ffffff; 
            }
            .item:hover { 
                background: #2d2d2d; 
            }
            .locked-item { 
                opacity: 0.7; 
                background: #3a2f00; 
                border-left: 3px solid #ff6b35; 
            }
            .locked-item:hover { 
                background: #4a3f10; 
            }
            .icon { margin-right: 10px; width: 20px; }
            .name { flex: 1; }
            .size { color: #999; margin-left: 10px; }
        """
    }

    public override func generateHeaderHTML(for directoryListing: DirectoryListing) -> String {
        return """
        <div class="header">
            <h2>&#x1F319; \(directoryListing.title)</h2>
            <p style="margin: 5px 0 0 0; opacity: 0.8;">Dark Theme File Browser</p>
        </div>
        """
    }

    // Inherit shouldShowItem from DefaultHTMLProvider
}