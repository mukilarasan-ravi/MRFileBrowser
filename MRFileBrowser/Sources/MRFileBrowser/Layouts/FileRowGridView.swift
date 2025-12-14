import SwiftUI

struct FileRowGridView: View {
    let url: URL
    var width: CGFloat? = nil   // Cell size provided by parent grid
    var onTap: ((URL) -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {

            VStack(alignment: .leading, spacing: 2) {

                // -------------------------
                // Top Thumbnail / Preview
                // -------------------------
                if url.isDirectory {
                    let fm = FileManager.default
                    let items = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []

                    if items.isEmpty {
                        EmptyView()
                    } else {
                        FolderGridPreview(url: url, size: (width ?? 100) * 0.70)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    FileRowItemView(url: url, size: (width ?? 100) * 0.70)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer(minLength: 6)

                // -------------------------
                // File / Folder Name
                // -------------------------
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)

                // -------------------------
                // Extra Info
                // -------------------------
                Text(finfoExtraDetails)
                    .foregroundColor(.gray)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            }
            .frame(width: width, height: width)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.85, green: 0.92, blue: 1.0))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )

            // -------------------------
            // diropertheedotmenu
            // -------------------------
            Button(action: {
                print("diropertheedotmenu tapped for \(url.lastPathComponent)")
            }) {
                Image(systemName: "ellipsis")
                    .padding(6)
                    .background(Color(UIColor.systemBackground).opacity(0.9))
                    .clipShape(Circle())
            }
            .padding(6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?(url)
        }
    }

    // MARK: - Extra Info
    private var finfoExtraDetails: String {
        if url.isDirectory {
            let fm = FileManager.default
            let count = (try? fm.contentsOfDirectory(atPath: url.path).count) ?? 0
            return "\(count) item\(count <= 1 ? "" : "s")"
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
