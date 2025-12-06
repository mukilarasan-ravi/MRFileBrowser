import SwiftUI

struct FileRowItemView: View {
    let url: URL
    var size: CGFloat        // size passed from parent grid

    @State private var thumbnail: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)  // enforce square
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.9, green: 0.95, blue: 1.0))
                    .frame(width: size, height: size) // enforce square
                    .overlay(
                        Image(systemName: url.hasDirectoryPath ? "folder.fill" : "doc.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    )
            }
        }
        .onAppear {
            loadThumbnailIfNeeded()
        }
    }

    private func loadThumbnailIfNeeded() {
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
