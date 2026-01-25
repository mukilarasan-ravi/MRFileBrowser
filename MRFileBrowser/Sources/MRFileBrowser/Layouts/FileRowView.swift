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

    private static let folderColor = Color(red: 0.85, green: 0.92, blue: 1.0)
    private static let lockColor = Color.blue.opacity(0.7)

    let url: URL
    let layout: FileRowLayout
    @ObservedObject var menuCoordinator: MenuCoordinator
    @ObservedObject private var lockManager = LockManager.shared
    var onTap: ((URL) -> Void)? = nil

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
                .background(Color(UIColor.systemBackground).opacity(0.9))
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
                                    .foregroundColor(Color.blue.opacity(0.7))
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: width * 0.15))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.blue.opacity(0.7))
                                            .frame(width: width * 0.18, height: width * 0.18)
                                    )
                                    .offset(x: width * 0.15, y: -width * 0.15)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Show normal folder preview for unlocked folders
                        let items = (try? FileManager.default
                            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []

                        if !items.isEmpty {
                            FolderGridPreview(url: url, size: width * 0.70)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    FileRowItemView(url: url, size: width * 0.70)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer(minLength: 6)

                Text(url.displayName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(fileInfoDetails)
                    .foregroundColor(.gray)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width, height: width)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.85, green: 0.92, blue: 1.0))
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
                            .foregroundColor(Self.lockColor)
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
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                Text(fileInfoDetails)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            // Lock indicator for locked files
            if isLocked {
                Image(systemName: lockIcon)
                    .foregroundColor(Self.lockColor)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 20, height: 20)
            }

            menuButton(rotation: .degrees(90))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemBackground))
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
    init(size: CGFloat, isLocked: Bool = false) {
        self.size = size
        self.isLocked = isLocked
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.85, green: 0.92, blue: 1.0))
                .overlay(
                    Image(systemName: "folder.fill")
                        .foregroundColor(Color.blue.opacity(0.7))
                        .font(.system(size: size * 0.5))
                )
                .frame(width: size, height: size)
            if isLocked {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: size * 0.25))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: size * 0.3, height: size * 0.3)
                    )
                    .offset(x: size * 0.25, y: -size * 0.25)
            }
        }
    }
}
