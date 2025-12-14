import SwiftUI

struct FileRowNormalView: View {
    let url: URL
    var thumbnailSize: CGFloat = 44

    /// Closure to call when this row is tapped
    var onTap: ((URL) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {

            // -------------------------
            // Thumbnail
            // -------------------------
            if url.isDirectory {
                FolderIconView(size: thumbnailSize)
            } else {
                FileRowItemView(url: url, size: thumbnailSize)
            }

            // -------------------------
            // File Info
            // -------------------------
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                Text(finfoExtraDetails)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // -------------------------
            // 3-dot menu
            // -------------------------
            Button(action: {
                print("menu tapped for \(url.lastPathComponent)")
            }) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(.secondary)
                    .padding(6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle()) // make the whole row tappable
        .onTapGesture {
            debugPrint("on Tap called --> \(url.lastPathComponent)")
            onTap?(url)
        }
    }

    // MARK: - Extra Info
    private var finfoExtraDetails: String {
        if url.isDirectory {
            let count = (try? FileManager.default.contentsOfDirectory(atPath: url.path).count) ?? 0
            return "\(count) item\(count == 1 ? "" : "s")"
        } else {
            let typeName = url.pathExtension.mediaType
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let sizeStr = ByteCountFormatter.string(
                fromByteCount: Int64(size),
                countStyle: .file
            )
            return "\(typeName), \(sizeStr)"
        }
    }
}

// MARK: - Folder Icon
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
