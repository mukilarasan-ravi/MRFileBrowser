//
//  ServerConfigurationTests.swift
//  MRFileBrowserTests
//
//  Created by Test on 02/03/26.
//

import Testing
@testable import MRFileBrowser
import SwiftUI

struct ServerConfigurationTests {
    
    // MARK: - Initialization Tests
    
    @Test func testDefaultInitialization() async throws {
        let config = ServerConfiguration()
        
        // Verify default values
        if case .show = config.serverButtonMode {
            // Test passes - default should be show
        } else {
            #expect(Bool(false), "Default server button mode should be .show")
        }
        
        if case .stopOnBackground = config.backgroundMode {
            // Test passes - default should be stopOnBackground  
        } else {
            #expect(Bool(false), "Default background mode should be .stopOnBackground")
        }
        
        #expect(config.htmlProvider != nil, "Default HTML provider should not be nil")
    }
    
    @Test func testCustomInitialization() async throws {
        let customProvider = DefaultHTMLProvider()
        
        let config = ServerConfiguration(
            serverButtonMode: .hidden,
            backgroundMode: .continueInBackground,
            htmlProvider: customProvider
        )
        
        if case .hidden = config.serverButtonMode {
            // Test passes
        } else {
            #expect(Bool(false), "Server button mode should be .hidden")
        }
        
        if case .continueInBackground = config.backgroundMode {
            // Test passes
        } else {
            #expect(Bool(false), "Background mode should be .continueInBackground")
        }
        
        #expect(config.htmlProvider != nil, "Custom HTML provider should be set")
    }
    
    // MARK: - ServerButtonMode Tests
    
    @Test func testServerButtonModeHidden() async throws {
        let config = ServerConfiguration(serverButtonMode: .hidden)
        
        if case .hidden = config.serverButtonMode {
            // Test passes
        } else {
            #expect(Bool(false), "Server button mode should be .hidden")
        }
    }
    
    @Test func testServerButtonModeShow() async throws {
        let config = ServerConfiguration(serverButtonMode: .show)
        
        if case .show = config.serverButtonMode {
            // Test passes
        } else {
            #expect(Bool(false), "Server button mode should be .show")
        }
    }
    
    @Test func testServerButtonModeCustomView() async throws {
        let customViewProvider: (@escaping () -> Void) -> AnyView = { dismissCallback in
            return AnyView(
                VStack {
                    Text("Custom Server View")
                    Button("Dismiss") {
                        dismissCallback()
                    }
                }
            )
        }
        
        let config = ServerConfiguration(serverButtonMode: .showCustomView(customViewProvider))
        
        if case .showCustomView(let provider) = config.serverButtonMode {
            // Test the custom view provider
            let testView = provider({})
            #expect(testView != nil, "Custom view provider should return a view")
        } else {
            #expect(Bool(false), "Server button mode should be .showCustomView")
        }
    }
    
    // MARK: - BackgroundMode Tests
    
    @Test func testBackgroundModeStopOnBackground() async throws {
        let config = ServerConfiguration(backgroundMode: .stopOnBackground)
        
        if case .stopOnBackground = config.backgroundMode {
            // Test passes
        } else {
            #expect(Bool(false), "Background mode should be .stopOnBackground")
        }
    }
    
    @Test func testBackgroundModeContinueInBackground() async throws {
        let config = ServerConfiguration(backgroundMode: .continueInBackground)
        
        if case .continueInBackground = config.backgroundMode {
            // Test passes
        } else {
            #expect(Bool(false), "Background mode should be .continueInBackground")
        }
    }
    
    // MARK: - HTML Provider Tests
    
    @Test func testDefaultHTMLProvider() async throws {
        let config = ServerConfiguration()
        
        #expect(config.htmlProvider is DefaultHTMLProvider, "Default should use DefaultHTMLProvider")
    }
    
    @Test func testCustomHTMLProvider() async throws {
        let customProvider = DefaultHTMLProvider()
        let config = ServerConfiguration(htmlProvider: customProvider)
        
        #expect(config.htmlProvider != nil, "Custom HTML provider should be set")
    }
    
    // MARK: - Complex Configuration Tests
    
    @Test func testComplexConfiguration() async throws {
        let customProvider = DefaultHTMLProvider()
        
        let config = ServerConfiguration(
            serverButtonMode: .showCustomView { dismissCallback in
                return AnyView(
                    Button("Custom Server Button") {
                        dismissCallback()
                    }
                )
            },
            backgroundMode: .continueInBackground,
            htmlProvider: customProvider
        )
        
        // Test all components are set correctly
        if case .showCustomView(_) = config.serverButtonMode {
            // Test passes
        } else {
            #expect(Bool(false), "Should have custom view button mode")
        }
        
        if case .continueInBackground = config.backgroundMode {
            // Test passes
        } else {
            #expect(Bool(false), "Should have continue in background mode")
        }
        
        #expect(config.htmlProvider != nil, "Should have custom HTML provider")
    }
    
    // MARK: - Configuration Validation Tests
    
    @Test func testValidConfigurationCombinations() async throws {
        // Test that all combinations are valid
        let buttonModes: [ServerConfiguration.ServerButtonMode] = [
            .hidden,
            .show,
            .showCustomView { _ in AnyView(Text("Test")) }
        ]
        
        let backgroundModes: [ServerConfiguration.BackgroundMode] = [
            .stopOnBackground,
            .continueInBackground
        ]
        
        for buttonMode in buttonModes {
            for backgroundMode in backgroundModes {
                let config = ServerConfiguration(
                    serverButtonMode: buttonMode,
                    backgroundMode: backgroundMode
                )
                
                #expect(config.htmlProvider != nil, "All configurations should have HTML provider")
            }
        }
    }
    
    // MARK: - Configuration Behavior Tests
    
    @Test func testServerButtonBehaviorHidden() async throws {
        let config = ServerConfiguration(serverButtonMode: .hidden)
        
        // When button mode is hidden, it should be properly configured
        if case .hidden = config.serverButtonMode {
            // This configuration should work with any background mode
            #expect(true, "Hidden button mode should be valid")
        } else {
            #expect(Bool(false), "Configuration error")
        }
    }
    
    @Test func testServerButtonBehaviorShow() async throws {
        let config = ServerConfiguration(serverButtonMode: .show)
        
        // When button mode is show, it should use built-in UI
        if case .show = config.serverButtonMode {
            #expect(true, "Show button mode should be valid")
        } else {
            #expect(Bool(false), "Configuration error")
        }
    }
    
    @Test func testBackgroundBehaviorConfiguration() async throws {
        let stopConfig = ServerConfiguration(backgroundMode: .stopOnBackground)
        let continueConfig = ServerConfiguration(backgroundMode: .continueInBackground)
        
        // Both configurations should be valid
        #expect(stopConfig.htmlProvider != nil, "Stop on background config should be valid")
        #expect(continueConfig.htmlProvider != nil, "Continue in background config should be valid")
    }
    
    // MARK: - Edge Cases
    
    @Test func testMultipleCustomViewConfigurations() async throws {
        let provider1: (@escaping () -> Void) -> AnyView = { _ in AnyView(Text("View 1")) }
        let provider2: (@escaping () -> Void) -> AnyView = { _ in AnyView(Text("View 2")) }
        
        let config1 = ServerConfiguration(serverButtonMode: .showCustomView(provider1))
        let config2 = ServerConfiguration(serverButtonMode: .showCustomView(provider2))
        
        // Both should be valid configurations
        if case .showCustomView(_) = config1.serverButtonMode,
           case .showCustomView(_) = config2.serverButtonMode {
            #expect(true, "Multiple custom view configurations should be valid")
        } else {
            #expect(Bool(false), "Custom view configurations should be valid")
        }
    }
    
    @Test func testConfigurationImmutability() async throws {
        let config = ServerConfiguration(
            serverButtonMode: .show,
            backgroundMode: .stopOnBackground
        )
        
        // Configuration properties should be immutable (let properties)
        // This test verifies the configuration is properly initialized
        if case .show = config.serverButtonMode,
           case .stopOnBackground = config.backgroundMode {
            #expect(true, "Configuration should maintain its values")
        } else {
            #expect(Bool(false), "Configuration values should be immutable")
        }
    }
}