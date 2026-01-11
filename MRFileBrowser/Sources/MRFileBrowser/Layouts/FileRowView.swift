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
    var onTap: ((URL) -> Void)? = nil

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

    var fileInfoDetails: String {
        if url.isDirectory {
            let count = (try? FileManager.default
                .contentsOfDirectory(atPath: url.path).count) ?? 0
            return "\(count) item\(count == 1 ? "" : "s")"
        } else {
            let type = url.pathExtension.mediaType
            let size = (try? url.resourceValues(
                forKeys: [.fileSizeKey]
            ).fileSize) ?? 0

            let sizeStr = ByteCountFormatter.string(
                fromByteCount: Int64(size),
                countStyle: .file
            )
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
                    let items = (try? FileManager.default
                        .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []

                    if !items.isEmpty {
                        FolderGridPreview(url: url, size: width * 0.70)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    FileRowItemView(url: url, size: width * 0.70)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer(minLength: 6)

                Text(url.lastPathComponent)
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
        }
    }
}

//Extension for List View
private extension FileRowView {

    func listView(thumbnailSize: CGFloat) -> some View {
        HStack(spacing: 12) {

            if url.isDirectory {
                FolderIconView(size: thumbnailSize)
            } else {
                FileRowItemView(url: url, size: thumbnailSize)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                Text(fileInfoDetails)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            menuButton(rotation: .degrees(90))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
    }
}

// MARK: - FOLDER ICON
struct FolderIconView: View {

    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(red: 0.85, green: 0.92, blue: 1.0))
            .overlay(
                Image(systemName: "folder.fill")
                    .foregroundColor(Color.blue.opacity(0.7))
                    .font(.system(size: size * 0.5))
            )
            .frame(width: size, height: size)
    }
}
