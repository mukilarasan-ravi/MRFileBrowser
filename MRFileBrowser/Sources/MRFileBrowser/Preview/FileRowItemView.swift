import SwiftUI

struct FileRowItemView: View {
    let url: URL
    var size: CGFloat        // size passed from parent grid

    @State private var thumbnail: UIImage? = nil
    @State private var isLoading = false
    @ObservedObject private var lockManager = LockManager.shared
    @Environment(\.themeConfiguration) private var theme

    var body: some View {
        ZStack {
            // Check if file/folder is locked and show lock overlay
            if lockManager.isFileLocked(url.path) {
                // Show lock overlay instead of thumbnail/preview
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.folderColor)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.primaryColor.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        ZStack {
                            Image(systemName: url.isDirectory ? "folder.fill" : url.pathExtension.fileTypeIcon)
                                .font(.system(size: size * 0.5))
                                .foregroundColor(url.isDirectory ? theme.folderColor: theme.fileColor)
                            // Show shield icon for both files and folders when locked
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: size * 0.25))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(theme.lockColor)
                                        .frame(width: size * 0.3, height: size * 0.3)
                                )
                                .offset(x: size * 0.25, y: -size * 0.25)
                        }
                    )
            } else {
                // Show normal thumbnail/preview for unlocked items
                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)  // enforce square
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: size, height: size) // enforce square
                        .overlay(
                            Image(systemName: url.hasDirectoryPath ? "folder.fill" : url.pathExtension.fileTypeIcon)
                                .font(.system(size: 24))
                                .foregroundColor(url.hasDirectoryPath ? theme.folderColor : theme.fileColor)
                        ).foregroundColor(theme.primaryColor)
                }
            }
        }
        .onAppear {
            loadThumbnailIfNeeded()
        }
    }

    private func loadThumbnailIfNeeded() {
        // Don't load thumbnails for locked files
        if lockManager.isFileLocked(url.path) { return }
        if thumbnail != nil || isLoading { return }
        isLoading = true

        let targetSize = CGSize(width: size * 2, height: size * 2) // higher res thumbnail

        ThumbnailLoader.load(url: url, size: targetSize) { img in
            DispatchQueue.main.async {
                self.thumbnail = img
                self.isLoading = false
            }
        }
    }
}
