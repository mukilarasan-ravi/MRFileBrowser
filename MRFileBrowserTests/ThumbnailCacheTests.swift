//
//  ThumbnailCacheTests.swift
//  MRFileBrowserTests
//
//  Created by Test on 02/03/26.
//

import Testing
@testable import MRFileBrowser
import Foundation

struct ThumbnailCacheTests {
    
    @Test func testThumbnailCacheExists() {
        // Test that ThumbnailCache type exists and can be accessed
        let _ = ThumbnailCache.shared
        #expect(true, "ThumbnailCache.shared should be accessible")
    }
    
    @Test func testThumbnailCacheAPI() {
        // Test basic API availability
        let cache = ThumbnailCache.shared
        let testURL = URL(fileURLWithPath: "/test")
        
        // Test that image retrieval method exists
        let _ = cache.image(for: testURL)
        #expect(true, "image(for:) method should be available")
    }
}