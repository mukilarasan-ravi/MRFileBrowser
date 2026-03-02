//
//  ThemeConfigurationTests.swift
//  MRFileBrowserTests
//
//  Created by Test on 02/03/26.
//

import Testing
@testable import MRFileBrowser
import SwiftUI

struct ThemeConfigurationTests {
    
    // MARK: - Initialization Tests
    
    @Test func testDefaultInitialization() async throws {
        let themeConfig = ThemeConfiguration()
        
        // Verify that all color properties are accessible and not nil
        #expect(themeConfig.primaryColor != nil)
        #expect(themeConfig.secondaryColor != nil)
        #expect(themeConfig.successColor != nil)
        #expect(themeConfig.errorColor != nil)
        #expect(themeConfig.infoColor != nil)
        #expect(themeConfig.backgroundColor != nil)
        #expect(themeConfig.secondaryBackgroundColor != nil)
        #expect(themeConfig.overlayBackgroundColor != nil)
        #expect(themeConfig.primaryTextColor != nil)
        #expect(themeConfig.secondaryTextColor != nil)
        #expect(themeConfig.textOnPrimaryColor != nil)
    }
    
    @Test func testCustomInitialization() async throws {
        let customTheme = ThemeConfiguration(
            primaryColor: .red,
            secondaryColor: .blue,
            successColor: .green,
            errorColor: .orange,
            infoColor: .purple,
            backgroundColor: .white,
            secondaryBackgroundColor: .gray,
            overlayBackgroundColor: .black.opacity(0.5),
            primaryTextColor: .black,
            secondaryTextColor: .gray,
            textOnPrimaryColor: .white
        )
        
        #expect(customTheme.primaryColor == .red)
        #expect(customTheme.secondaryColor == .blue)
        #expect(customTheme.successColor == .green)
        #expect(customTheme.errorColor == .orange)
        #expect(customTheme.infoColor == .purple)
        #expect(customTheme.backgroundColor == .white)
        #expect(customTheme.secondaryBackgroundColor == .gray)
        #expect(customTheme.primaryTextColor == .black)
        #expect(customTheme.secondaryTextColor == .gray)
        #expect(customTheme.textOnPrimaryColor == .white)
    }
    
    // MARK: - Color Consistency Tests
    
    @Test func testColorContrast() async throws {
        let themeConfig = ThemeConfiguration()
        
        // Basic test to ensure text on primary color provides contrast
        // This is a conceptual test - in practice you'd need more sophisticated color analysis
        #expect(themeConfig.textOnPrimaryColor != themeConfig.primaryColor, "Text on primary should contrast with primary color")
    }
    
    // MARK: - Dark Theme Tests
    
    @Test func testDarkThemeConfiguration() async throws {
        let darkTheme = ThemeConfiguration(
            primaryColor: .blue,
            secondaryColor: .gray,
            successColor: .green,
            errorColor: .red,
            infoColor: .blue,
            backgroundColor: .black,
            secondaryBackgroundColor: Color(.systemGray6),
            overlayBackgroundColor: .black.opacity(0.8),
            primaryTextColor: .white,
            secondaryTextColor: .gray,
            textOnPrimaryColor: .white
        )
        
        #expect(darkTheme.backgroundColor == .black)
        #expect(darkTheme.primaryTextColor == .white)
        #expect(darkTheme.textOnPrimaryColor == .white)
    }
    
    // MARK: - Light Theme Tests
    
    @Test func testLightThemeConfiguration() async throws {
        let lightTheme = ThemeConfiguration(
            primaryColor: .blue,
            secondaryColor: .gray,
            successColor: .green,
            errorColor: .red,
            infoColor: .blue,
            backgroundColor: .white,
            secondaryBackgroundColor: Color(.systemGray6),
            overlayBackgroundColor: .black.opacity(0.3),
            primaryTextColor: .black,
            secondaryTextColor: .gray,
            textOnPrimaryColor: .white
        )
        
        #expect(lightTheme.backgroundColor == .white)
        #expect(lightTheme.primaryTextColor == .black)
        #expect(lightTheme.textOnPrimaryColor == .white)
    }
    
    // MARK: - Color Properties Tests
    
    @Test func testAllCoreColors() async throws {
        let testColors = [Color.red, Color.blue, Color.green, Color.yellow, Color.purple]
        
        for (index, color) in testColors.enumerated() {
            let themeConfig = ThemeConfiguration(
                primaryColor: color,
                secondaryColor: .gray,
                successColor: .green,
                errorColor: .red,
                infoColor: .blue,
                backgroundColor: .white,
                secondaryBackgroundColor: .gray,
                overlayBackgroundColor: .black.opacity(0.3),
                primaryTextColor: .black,
                secondaryTextColor: .gray,
                textOnPrimaryColor: .white
            )
            
            #expect(themeConfig.primaryColor == color, "Theme \\(index) should have correct primary color")
        }
    }
    
    @Test func testAllBackgroundColors() async throws {
        let backgroundColors = [Color.white, Color.black, Color.gray, Color.blue.opacity(0.1)]
        
        for (index, bgColor) in backgroundColors.enumerated() {
            let themeConfig = ThemeConfiguration(
                primaryColor: .blue,
                secondaryColor: .gray,
                successColor: .green,
                errorColor: .red,
                infoColor: .blue,
                backgroundColor: bgColor,
                secondaryBackgroundColor: .gray,
                overlayBackgroundColor: .black.opacity(0.3),
                primaryTextColor: .black,
                secondaryTextColor: .gray,
                textOnPrimaryColor: .white
            )
            
            #expect(themeConfig.backgroundColor == bgColor, "Theme \\(index) should have correct background color")
        }
    }
    
    @Test func testAllTextColors() async throws {
        let textColors = [Color.black, Color.white, Color.gray, Color.blue]
        
        for (index, textColor) in textColors.enumerated() {
            let themeConfig = ThemeConfiguration(
                primaryColor: .blue,
                secondaryColor: .gray,
                successColor: .green,
                errorColor: .red,
                infoColor: .blue,
                backgroundColor: .white,
                secondaryBackgroundColor: .gray,
                overlayBackgroundColor: .black.opacity(0.3),
                primaryTextColor: textColor,
                secondaryTextColor: .gray,
                textOnPrimaryColor: .white
            )
            
            #expect(themeConfig.primaryTextColor == textColor, "Theme \\(index) should have correct primary text color")
        }
    }
    
    // MARK: - Status Color Tests
    
    @Test func testStatusColors() async throws {
        let themeConfig = ThemeConfiguration(
            primaryColor: .blue,
            secondaryColor: .gray,
            successColor: .green,
            errorColor: .red,
            infoColor: .blue,
            backgroundColor: .white,
            secondaryBackgroundColor: .gray,
            overlayBackgroundColor: .black.opacity(0.3),
            primaryTextColor: .black,
            secondaryTextColor: .gray,
            textOnPrimaryColor: .white
        )
        
        #expect(themeConfig.successColor == .green, "Success color should be green")
        #expect(themeConfig.errorColor == .red, "Error color should be red") 
        #expect(themeConfig.infoColor == .blue, "Info color should be blue")
    }
    
    // MARK: - Opacity Tests
    
    @Test func testOverlayBackgroundOpacity() async throws {
        let transparentOverlay = Color.black.opacity(0.5)
        let themeConfig = ThemeConfiguration(
            primaryColor: .blue,
            secondaryColor: .gray,
            successColor: .green,
            errorColor: .red,
            infoColor: .blue,
            backgroundColor: .white,
            secondaryBackgroundColor: .gray,
            overlayBackgroundColor: transparentOverlay,
            primaryTextColor: .black,
            secondaryTextColor: .gray,
            textOnPrimaryColor: .white
        )
        
        #expect(themeConfig.overlayBackgroundColor == transparentOverlay, "Overlay should maintain opacity")
    }
    
    // MARK: - Color Equality Tests
    
    @Test func testColorEquality() async throws {
        let theme1 = ThemeConfiguration(
            primaryColor: .blue,
            secondaryColor: .gray,
            successColor: .green,
            errorColor: .red,
            infoColor: .blue,
            backgroundColor: .white,
            secondaryBackgroundColor: .gray,
            overlayBackgroundColor: .black.opacity(0.3),
            primaryTextColor: .black,
            secondaryTextColor: .gray,
            textOnPrimaryColor: .white
        )
        
        let theme2 = ThemeConfiguration(
            primaryColor: .blue,
            secondaryColor: .gray,
            successColor: .green,
            errorColor: .red,
            infoColor: .blue,
            backgroundColor: .white,
            secondaryBackgroundColor: .gray,
            overlayBackgroundColor: .black.opacity(0.3),
            primaryTextColor: .black,
            secondaryTextColor: .gray,
            textOnPrimaryColor: .white
        )
        
        // Test individual color properties are equal
        #expect(theme1.primaryColor == theme2.primaryColor)
        #expect(theme1.backgroundColor == theme2.backgroundColor)
        #expect(theme1.primaryTextColor == theme2.primaryTextColor)
    }
    
    // MARK: - Edge Cases
    
    @Test func testClearColors() async throws {
        let themeConfig = ThemeConfiguration(
            primaryColor: .clear,
            secondaryColor: .clear,
            successColor: .green,
            errorColor: .red,
            infoColor: .blue,
            backgroundColor: .clear,
            secondaryBackgroundColor: .clear,
            overlayBackgroundColor: .clear,
            primaryTextColor: .clear,
            secondaryTextColor: .clear,
            textOnPrimaryColor: .clear
        )
        
        #expect(themeConfig.primaryColor == .clear)
        #expect(themeConfig.backgroundColor == .clear)
        #expect(themeConfig.primaryTextColor == .clear)
    }
    
    @Test func testSystemColors() async throws {
        let themeConfig = ThemeConfiguration(
            primaryColor: Color(.systemBlue),
            secondaryColor: Color(.systemGray),
            successColor: Color(.systemGreen),
            errorColor: Color(.systemRed),
            infoColor: Color(.systemBlue),
            backgroundColor: Color(.systemBackground),
            secondaryBackgroundColor: Color(.secondarySystemBackground),
            overlayBackgroundColor: Color(.systemGray).opacity(0.8),
            primaryTextColor: Color(.label),
            secondaryTextColor: Color(.secondaryLabel),
            textOnPrimaryColor: Color(.white)
        )
        
        #expect(themeConfig.primaryColor == Color(.systemBlue))
        #expect(themeConfig.backgroundColor == Color(.systemBackground))
        #expect(themeConfig.primaryTextColor == Color(.label))
    }
}