//
//  SearchUtilTests.swift
//  MRFileBrowserTests
//
//  Created by Test on 02/03/26.
//

import Testing
@testable import MRFileBrowser
import Foundation

struct SearchUtilTests {
    
    @Test func testSearchUtilExists() {
        // Test that SearchUtil type exists and is accessible
        let _ = SearchUtil.shared
        #expect(true, "SearchUtil.shared should be accessible")
    }
    
    @Test func testSearchResultType() {
        // Test that SearchResult type exists and can be created
        let testURL = URL(fileURLWithPath: "/test/file.txt")
        let result = SearchResult(url: testURL, relativePath: "test", lockedParents: [], isInLockedFolder: false)
        #expect(result.url == testURL, "SearchResult should store URL correctly")
        #expect(result.relativePath == "test", "SearchResult should store relativePath correctly")
    }
    
    @Test func testSearchResultDisplayPath() {
        let testURL = URL(fileURLWithPath: "/test/document.txt")
        let result = SearchResult(url: testURL, relativePath: "folder", lockedParents: [], isInLockedFolder: false)
        
        let displayPath = result.displayPath
        #expect(displayPath.contains("document.txt"), "Display path should contain filename")
    }
    
    @Test func testSearchResultID() {
        let testURL = URL(fileURLWithPath: "/test/file1.txt")
        let result1 = SearchResult(url: testURL, relativePath: "", lockedParents: [], isInLockedFolder: false)
        let result2 = SearchResult(url: testURL, relativePath: "", lockedParents: [], isInLockedFolder: false)
        // Each result should have a unique ID
        #expect(result1.id != result2.id, "SearchResult instances should have unique IDs")
    }
}