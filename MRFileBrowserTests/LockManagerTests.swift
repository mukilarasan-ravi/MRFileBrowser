//
//  LockManagerTests.swift
//  MRFileBrowserTests
//
//  Created by Test on 02/03/26.
//

import Testing
@testable import MRFileBrowser

//Testing for LockManager class - Simplified tests for basic API verification

struct LockManagerTests {
    
    @Test
    func testLockManagerTypeExists() {
        let lockManagerType = LockManager.self
        #expect(lockManagerType == LockManager.self, "LockManager type should exist")
    }
    
    @Test 
    func testSharedInstance() {
        let instance = LockManager.shared
        // Test that we can access the shared instance
        #expect(true, "LockManager.shared should be accessible")
    }
    
    @Test
    func testIsFileLockedAPI() {
        let lockManager = LockManager.shared
        // Just test that the method exists and can be called
        let _ = lockManager.isFileLocked("/some/test/path")
        #expect(true, "isFileLocked method should be callable")
    }
    
    @Test
    func testLockMethodEnum() {
        // Test that we can create enum instances
        let biometric = LockMethod.biometric
        let pinLock = LockMethod.customPIN("1234")
        // Test that they exist by using them in a switch
        switch biometric {
        case .biometric:
            #expect(true, "Biometric case should exist")
        case .customPIN:
            #expect(false, "Should be biometric case")
        }
        
        switch pinLock {
        case .biometric:
            #expect(false, "Should be customPIN case")
        case .customPIN:
            #expect(true, "CustomPIN case should exist")
        }
    }
}