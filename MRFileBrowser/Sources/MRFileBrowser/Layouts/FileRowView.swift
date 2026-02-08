//
//  FileRowView.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 25/12/25.
//

import SwiftUI

enum FileRowLayout {
    case grid(width: CGFloat)
    case list(thumbnailSize: CGFloat)
}

struct FileRowView: View {

    let url: URL
    let layout: FileRowLayout
    @ObservedObject var menuCoordinator: MenuCoordinator
    @ObservedObject private var lockManager = LockManager.shared
    @Environment(\.themeConfiguration) private var theme
    var onTap: ((URL) -> Void)? = nil

    // New property for search context
    var searchContext: String? = nil

    private var isLocked: Bool { lockManager.isFileLocked(url.path) }
    private var lockIcon: String {
        lockManager.hasCustomPIN(url.path) ? "lock.fill" : "faceid"
    }

    var body: some View {
        Group {
            switch layout {
            case .grid(let width):
                gridView(width: width)

            case .list(let thumbnailSize):
                listView(thumbnailSize: thumbnailSize)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?(url)
        }
        .allowsHitTesting(true)
    }

    func menuButton(rotation: Angle) -> some View {
        Button {
            menuCoordinator.showBottomSheet(for: url)
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(rotation)
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 30, height: 30)
                .background(theme.backgroundColor.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Circle())
    }

    private var fileInfoDetails: String {
        if url.isDirectory {
            let count = (try? FileManager.default.contentsOfDirectory(atPath: url.path).count) ?? 0
            return "\(count) item\(count == 1 ? "" : "s")"
        } else {
            let type = url.pathExtension.mediaType
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            return "\(type), \(sizeStr)"
        }
    }
}

//Extension for Grid View
private extension FileRowView {

    func gridView(width: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {

            VStack(alignment: .leading, spacing: 2) {

                if url.isDirectory {
                    // Check if folder is locked
                    if lockManager.isFileLocked(url.path) {
                        // Show folder with lock overlay instead of preview
                        VStack {
                            ZStack {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: width * 0.4))
                                    .foregroundColor(theme.folderColor)
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: width * 0.15))
                                    .foregroundColor(theme.textOnPrimaryColor)
                                    .background(
                                        Circle()
                                            .fill(theme.lockColor)
                                            .frame(width: width * 0.18, height: width * 0.18)
                                    )
                                    .offset(x: width * 0.15, y: -width * 0.15)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Show normal folder preview for unlocked folders (including empty folders)
                        FolderGridPreview(url: url, size: width * 0.70)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    FileRowItemView(url: url, size: width * 0.70)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer(minLength: 6)

                Text(url.displayName)
                    .foregroundColor(theme.primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Show search context path if available in grid view
                if let searchContext = searchContext, !searchContext.isEmpty {
                    Text(searchContext)
                        .foregroundColor(theme.secondaryTextColor)
                        .font(.system(size: 8, weight: .regular))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(fileInfoDetails)
                    .foregroundColor(theme.secondaryTextColor)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width, height: width)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.secondaryBackgroundColor)
                    .shadow(color: .black.opacity(0.1), radius: 3)
            )

            menuButton(rotation: .degrees(0))
                .padding(8)
                .zIndex(1)
            // Lock indicator for locked files
            if isLocked {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: lockIcon)
                            .foregroundColor(theme.lockColor)
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(8)
                .zIndex(1)
            }
        }
    }
}

//Extension for List View
private extension FileRowView {

    func listView(thumbnailSize: CGFloat) -> some View {
        HStack(spacing: 12) {

            if url.isDirectory {
                FolderIconView(
                    size: thumbnailSize,
                    isLocked: isLocked
                )
            } else {
                FileRowItemView(url: url, size: thumbnailSize)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(url.displayName)
                    .foregroundColor(theme.primaryTextColor)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                // Show search context path if available
                if let searchContext = searchContext, !searchContext.isEmpty {
                    Text(searchContext)
                        .foregroundColor(theme.secondaryTextColor.opacity(0.8))
                        .font(.system(size: 11, weight: .regular))
                        .lineLimit(1)
                        .padding(.top, -2)
                }

                Text(fileInfoDetails)
                    .foregroundColor(theme.secondaryTextColor)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }

            Spacer()
            // Lock indicator for locked files
            if isLocked {
                Image(systemName: lockIcon)
                    .foregroundColor(theme.lockColor)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 20, height: 20)
            }

            menuButton(rotation: .degrees(90))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(theme.backgroundColor)
        .contentShape(Rectangle())
    }
    // MARK: - Lock Icon Helper
    private func lockIconForFile(_ path: String) -> String {
        if lockManager.hasCustomPIN(path) {
            return "lock.fill"  // Custom PIN lock
        } else {
            return "faceid"     // Biometric lock (Face ID/Touch ID)
        }
    }
}

// MARK: - FOLDER ICON
struct FolderIconView: View {

    let size: CGFloat
    let isLocked: Bool
    @Environment(\.themeConfiguration) private var theme

    init(size: CGFloat, isLocked: Bool = false) {
        self.size = size
        self.isLocked = isLocked
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.folderColor)
                .overlay(
                    Image(systemName: "folder.fill")
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: size * 0.5))
                )
                .frame(width: size, height: size)
            if isLocked {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: size * 0.25))
                    .foregroundColor(theme.primaryColor)
                    .background(
                        Circle()
                            .fill(theme.lockColor)
                            .frame(width: size * 0.3, height: size * 0.3)
                    )
                    .offset(x: size * 0.25, y: -size * 0.25)
            }
        }
    }
}
