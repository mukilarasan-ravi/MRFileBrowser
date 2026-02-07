//
//  ThemeAwareHTMLProvider.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 31/01/26.
//

import Foundation
import SwiftUI

// HTML provider that generates themed CSS based on ThemeConfiguration
public class ThemeAwareHTMLProvider: DefaultHTMLProvider {
    private let theme: ThemeConfiguration

    public init(
        theme: ThemeConfiguration,
        showLockedItems: Bool = true,
        showParentLockedItems: Bool = true
    ) {
        self.theme = theme
        super.init(showLockedItems: showLockedItems, showParentLockedItems: showParentLockedItems)
    }

    public override func generateCSS() -> String {
        let primaryColorHex = theme.primaryColor.toHex()
        let secondaryColorHex = theme.secondaryColor.toHex()
        let backgroundColorHex = theme.backgroundColor.toHex()
        let secondaryBackgroundColorHex = theme.secondaryBackgroundColor.toHex()
        let textColorHex = theme.primaryTextColor.toHex()
        let secondaryTextColorHex = theme.secondaryTextColor.toHex()
        let errorColorHex = theme.errorColor.toHex()
        let lockColorHex = theme.lockColor.toHex()

        return """
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                margin: 20px;
                background-color: \(backgroundColorHex);
                color: \(textColorHex);
            }
            .header {
                background: \(primaryColorHex);
                color: white;
                padding: 15px;
                border-radius: 8px;
                margin-bottom: 20px;
            }
            .item {
                display: flex;
                align-items: center;
                padding: 10px;
                border-bottom: 1px solid \(secondaryColorHex)40;
                text-decoration: none;
                color: \(textColorHex);
                background: \(backgroundColorHex);
                border-radius: 4px;
                margin-bottom: 2px;
            }
            .item:hover {
                background: \(secondaryBackgroundColorHex);
            }
            .locked-item {
                opacity: 0.8;
                background: \(lockColorHex)20;
                border: 1px solid \(lockColorHex)60;
            }
            .locked-item:hover {
                background: \(lockColorHex)30;
            }
            .icon {
                margin-right: 10px;
                width: 20px;
                color: \(primaryColorHex);
            }
            .folder-icon {
                color: \(theme.folderColor.toHex());
            }
            .name {
                flex: 1;
                color: \(textColorHex);
            }
            .size {
                color: \(secondaryTextColorHex);
                margin-left: 10px;
            }
            .error {
                color: \(errorColorHex);
                font-weight: bold;
            }
            .breadcrumb {
                background: \(secondaryBackgroundColorHex);
                padding: 8px 12px;
                border-radius: 4px;
                margin-bottom: 16px;
            }
            .breadcrumb a {
                color: \(primaryColorHex);
                text-decoration: none;
            }
            .breadcrumb a:hover {
                text-decoration: underline;
            }
        """
    }

    public override func generateHeaderHTML(for directoryListing: DirectoryListing) -> String {
        return """
        <div class="header">
            <h2>\(directoryListing.title)</h2>
        </div>
        """
    }

    public override func generateAccessDeniedHTML(for item: FileItem, reason: LockReason) -> String {
        let iconType = item.isDirectory ? "&#x1F4C1;" : getFileIcon(for: item.fileExtension)
        let lockIcon = reason == .locked ? "&#x1F512;" : "&#x1F6E1;" // lock or shield
        let reasonText = reason.description

        let errorColorHex = theme.errorColor.toHex()
        let backgroundColorHex = theme.backgroundColor.toHex()
        let primaryColorHex = theme.primaryColor.toHex()
        let textColorHex = theme.primaryTextColor.toHex()
        let lockColorHex = theme.lockColor.toHex()

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
                    background: linear-gradient(135deg, \(errorColorHex), \(primaryColorHex));
                    color: \(theme.textOnPrimaryColor.toHex());
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
                    color: \(theme.textOnPrimaryColor.toHex());
                }
                .lock-icon {
                    font-size: 2em;
                    opacity: 0.9;
                    color: \(lockColorHex);
                }
                h1 {
                    margin: 0 0 20px 0;
                    font-size: 2em;
                    font-weight: 300;
                    color: \(theme.textOnPrimaryColor.toHex());
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
                    color: \(theme.textOnPrimaryColor.toHex());
                }
                .reason {
                    opacity: 0.9;
                    line-height: 1.6;
                    color: \(theme.textOnPrimaryColor.toHex());
                }
                .back-btn {
                    display: inline-block;
                    margin-top: 30px;
                    padding: 12px 24px;
                    background: rgba(255,255,255,0.2);
                    color: \(theme.textOnPrimaryColor.toHex());
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

    private func getFileIcon(for fileExtension: String) -> String {
        // Use the same logic as the parent class
        switch fileExtension.lowercased() {
        case "pdf": return "&#x1F4C4;"
        case "doc", "docx": return "&#x1F4C4;"
        case "xls", "xlsx": return "&#x1F4C8;"
        case "ppt", "pptx": return "&#x1F4CA;"
        case "txt": return "&#x1F4C4;"
        case "jpg", "jpeg", "png", "gif", "bmp": return "&#x1F5BC;"
        case "mp4", "mov", "avi": return "&#x1F3AC;"
        case "mp3", "wav", "m4a": return "&#x1F3B5;"
        case "zip", "rar", "7z": return "&#x1F4E6;"
        default: return "&#x1F4C4;"
        }
    }
}

// Color Extension for Hex Conversion
extension Color {
    func toHex() -> String {
        #if canImport(UIKit)
        // Handle iOS version compatibility
        let uiColor: UIColor
        if #available(iOS 14.0, *) {
            uiColor = UIColor(self)
        } else {
            // For iOS 13, we need to handle this differently
            // Use predefined system colors as fallbacks
            if self == Color.blue {
                uiColor = UIColor.systemBlue
            } else if self == Color.red {
                uiColor = UIColor.systemRed
            } else if self == Color.green {
                uiColor = UIColor.systemGreen
            } else if self == Color.orange {
                uiColor = UIColor.systemOrange
            } else if self == Color.purple {
                uiColor = UIColor.systemPurple
            } else if self == Color.primary {
                uiColor = UIColor.label
            } else if self == Color.secondary {
                uiColor = UIColor.secondaryLabel
            } else {
                // Default fallback
                uiColor = UIColor.systemBlue
            }
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        // Fallback for platforms without UIKit
        return "#007AFF"
        #endif
    }
}