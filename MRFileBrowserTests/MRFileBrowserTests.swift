//
//  MRFileBrowserTests.swift
//  MRFileBrowserTests
//
//  Created by Mukilarasan Ravi on 30/11/25.
//

import Testing
@testable import MRFileBrowser
import Foundation

struct MRFileBrowserTests {
    
    @Test func basicFrameworkTest() {
        // Basic test to verify the framework can be imported and accessed
        #expect(true, "Framework should be accessible")
    }
    
    @Test func documentsDirectoryExists() throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        #expect(documentsPath != nil, "Documents directory should exist")
    }
}
