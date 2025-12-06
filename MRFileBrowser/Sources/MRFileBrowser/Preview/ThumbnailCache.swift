//
//  ThumbnailCache.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 06/12/25.
//

import UIKit
import QuickLookThumbnailing

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {}

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct ThumbnailLoader {
    /// Loads a thumbnail for `url` (uses QuickLookThumbnailing). Completion runs on a background queue; call UI updates on main queue.
    static func load(url: URL, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        // Return cached image if available
        if let cached = ThumbnailCache.shared.image(for: url) {
            DispatchQueue.global(qos: .userInitiated).async {
                completion(cached)
            }
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
            if let img = representation?.uiImage {
                ThumbnailCache.shared.set(img, for: url)
                completion(img)
            } else {
                completion(nil)
            }
        }
    }
}
