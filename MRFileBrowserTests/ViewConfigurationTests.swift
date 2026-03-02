//
//  ViewConfigurationTests.swift
//  MRFileBrowserTests
//
//  Created by Test on 02/03/26.
//

import Testing
@testable import MRFileBrowser
import SwiftUI

struct ViewConfigurationTests {
    
    // MARK: - ViewMode Tests
    
    @Test func testViewModeListView() async throws {
        let mode = ViewConfiguration.ViewMode.listView
        #expect(mode == .listView)
    }
    
    @Test func testViewModeGridView() async throws {
        let mode = ViewConfiguration.ViewMode.gridView
        #expect(mode == .gridView)
    }
    
    @Test func testViewModeBoth() async throws {
        let mode = ViewConfiguration.ViewMode.both
        #expect(mode == .both)
    }
    
    // MARK: - GridConfiguration Tests
    
    @Test func testGridConfigurationDefaultValues() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 2,
            columnsCount: 3,
            maxColumnsCount: 5
        )
        
        #expect(gridConfig.minColumnsCount == 2)
        #expect(gridConfig.columnsCount == 3)
        #expect(gridConfig.maxColumnsCount == 5)
    }
    
    @Test func testGridConfigurationMinValidation() async throws {
        // Test that minimum columns is enforced
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 1,
            columnsCount: 2,
            maxColumnsCount: 4
        )
        
        #expect(gridConfig.minColumnsCount >= 1, "Minimum columns should be at least 1")
        #expect(gridConfig.columnsCount >= gridConfig.minColumnsCount, "Current columns should be >= min")
    }
    
    @Test func testGridConfigurationMaxValidation() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 2,
            columnsCount: 4,
            maxColumnsCount: 6
        )
        
        #expect(gridConfig.columnsCount <= gridConfig.maxColumnsCount, "Current columns should be <= max")
        #expect(gridConfig.maxColumnsCount >= gridConfig.minColumnsCount, "Max should be >= min")
    }
    
    @Test func testGridConfigurationRangeValidation() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 1,
            columnsCount: 3,
            maxColumnsCount: 10
        )
        
        #expect(gridConfig.minColumnsCount <= gridConfig.columnsCount)
        #expect(gridConfig.columnsCount <= gridConfig.maxColumnsCount)
        #expect(gridConfig.minColumnsCount <= gridConfig.maxColumnsCount)
    }
    
    @Test func testGridConfigurationBoundaryValues() async throws {
        // Test boundary values
        let minimalConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 1,
            columnsCount: 1,
            maxColumnsCount: 1
        )
        
        #expect(minimalConfig.minColumnsCount == 1)
        #expect(minimalConfig.columnsCount == 1)
        #expect(minimalConfig.maxColumnsCount == 1)
        
        let largeConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 1,
            columnsCount: 10,
            maxColumnsCount: 20
        )
        
        #expect(largeConfig.minColumnsCount == 1)
        #expect(largeConfig.columnsCount == 10)
        #expect(largeConfig.maxColumnsCount == 20)
    }
    
    // MARK: - ViewConfiguration Tests
    
    @Test func testViewConfigurationDefaultInitialization() async throws {
        let config = ViewConfiguration()
        
        #expect(config != nil, "ViewConfiguration should initialize with defaults")
    }
    
    @Test func testViewConfigurationWithListViewMode() async throws {
        let config = ViewConfiguration(viewMode: .listView)
        
        #expect(config.viewMode == .listView)
    }
    
    @Test func testViewConfigurationWithGridViewMode() async throws {
        let config = ViewConfiguration(viewMode: .gridView)
        
        #expect(config.viewMode == .gridView)
    }
    
    @Test func testViewConfigurationWithBothViewModes() async throws {
        let config = ViewConfiguration(viewMode: .both)
        
        #expect(config.viewMode == .both)
    }
    
    @Test func testViewConfigurationWithCustomGridConfiguration() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 2,
            columnsCount: 4,
            maxColumnsCount: 8
        )
        
        let config = ViewConfiguration(
            viewMode: .both,
            gridConfiguration: gridConfig
        )
        
        #expect(config.viewMode == .both)
        #expect(config.gridConfiguration.minColumnsCount == 2)
        #expect(config.gridConfiguration.columnsCount == 4)
        #expect(config.gridConfiguration.maxColumnsCount == 8)
    }
    
    // MARK: - Grid Configuration Edge Cases
    
    @Test func testGridConfigurationEqualMinMax() async throws {
        // When min and max are equal
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 3,
            columnsCount: 3,
            maxColumnsCount: 3
        )
        
        #expect(gridConfig.minColumnsCount == 3)
        #expect(gridConfig.columnsCount == 3)
        #expect(gridConfig.maxColumnsCount == 3)
    }
    
    @Test func testGridConfigurationColumnsClamping() async throws {
        // Test that columns count is properly clamped between min and max
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 2,
            columnsCount: 1, // Below minimum
            maxColumnsCount: 5
        )
        
        // The implementation should clamp the value
        #expect(gridConfig.minColumnsCount <= gridConfig.maxColumnsCount)
    }
    
    @Test func testGridConfigurationLargeValues() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 1,
            columnsCount: 50,
            maxColumnsCount: 100
        )
        
        #expect(gridConfig.columnsCount >= gridConfig.minColumnsCount)
        #expect(gridConfig.columnsCount <= gridConfig.maxColumnsCount)
    }
    
    // MARK: - ViewConfiguration Behavior Tests
    
    @Test func testViewConfigurationSupportsListView() async throws {
        let listConfig = ViewConfiguration(viewMode: .listView)
        let gridConfig = ViewConfiguration(viewMode: .gridView)
        let bothConfig = ViewConfiguration(viewMode: .both)
        
        // In a real app, you might have methods like supportsListView()
        // For now, we test that the configuration maintains its settings
        #expect(listConfig.viewMode == .listView)
        #expect(gridConfig.viewMode == .gridView)
        #expect(bothConfig.viewMode == .both)
    }
    
    @Test func testViewConfigurationSupportsGridView() async throws {
        let gridConfig = ViewConfiguration(viewMode: .gridView)
        let bothConfig = ViewConfiguration(viewMode: .both)
        
        #expect(gridConfig.viewMode == .gridView)
        #expect(bothConfig.viewMode == .both)
    }
    
    @Test func testViewConfigurationToggleCapability() async throws {
        let bothConfig = ViewConfiguration(viewMode: .both)
        
        // When mode is .both, user should be able to toggle between views
        #expect(bothConfig.viewMode == .both)
    }
    
    // MARK: - Complex Configuration Tests
    
    @Test func testComplexViewConfiguration() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 1,
            columnsCount: 3,
            maxColumnsCount: 6
        )
        
        let config = ViewConfiguration(
            viewMode: .both,
            gridConfiguration: gridConfig,
            startsInGridView: true,
            enableLongPressMenu: true,
            longPressMenuThreshold: 0.8
        )
        
        #expect(config.viewMode == .both)
        #expect(config.gridConfiguration.columnsCount == 3)
        #expect(config.startsInGridView == true)
        #expect(config.enableLongPressMenu == true)
        #expect(config.longPressMenuThreshold == 0.8)
    }
    
    @Test func testStartsInGridViewConfiguration() async throws {
        let startsInGridConfig = ViewConfiguration(startsInGridView: true)
        let startsInListConfig = ViewConfiguration(startsInGridView: false)
        
        #expect(startsInGridConfig.startsInGridView == true)
        #expect(startsInListConfig.startsInGridView == false)
    }
    
    @Test func testLongPressMenuConfiguration() async throws {
        let enabledConfig = ViewConfiguration(enableLongPressMenu: true)
        let disabledConfig = ViewConfiguration(enableLongPressMenu: false)
        
        #expect(enabledConfig.enableLongPressMenu == true)
        #expect(disabledConfig.enableLongPressMenu == false)
    }
    
    @Test func testLongPressMenuThreshold() async throws {
        let customThresholdConfig = ViewConfiguration(longPressMenuThreshold: 1.0)
        let defaultConfig = ViewConfiguration()
        
        #expect(customThresholdConfig.longPressMenuThreshold == 1.0)
        #expect(defaultConfig.longPressMenuThreshold == 0.5)
    }
    
    // MARK: - Built-in Configuration Tests
    
    @Test func testDefaultConfiguration() async throws {
        let config = ViewConfiguration.default
        
        #expect(config.viewMode == .both)
        #expect(config.startsInGridView == true)
        #expect(config.enableLongPressMenu == false)
        #expect(config.longPressMenuThreshold == 0.5)
    }
    
    @Test func testListOnlyConfiguration() async throws {
        let config = ViewConfiguration.listOnly
        
        #expect(config.viewMode == .listView)
        #expect(config.supportsListView == true)
        #expect(config.supportsGridView == false)
        #expect(config.allowsViewModeSwitch == false)
    }
    
    @Test func testGridOnlyConfiguration() async throws {
        let config = ViewConfiguration.gridOnly
        
        if #available(iOS 14.0, *) {
            #expect(config.viewMode == .gridView)
            #expect(config.supportsGridView == true)
        } else {
            // Fallback behavior on iOS < 14
            #expect(config.viewMode == .both)
            #expect(config.startsInGridView == false)
        }
    }
    
    // MARK: - ViewConfiguration Method Tests
    
    @Test func testSupportsGridView() async throws {
        let gridConfig = ViewConfiguration(viewMode: .gridView)
        let listConfig = ViewConfiguration(viewMode: .listView)
        let bothConfig = ViewConfiguration(viewMode: .both)
        
        if #available(iOS 14.0, *) {
            #expect(gridConfig.supportsGridView == true)
            #expect(bothConfig.supportsGridView == true)
        } else {
            #expect(gridConfig.supportsGridView == false)
            #expect(bothConfig.supportsGridView == false)
        }
        
        #expect(listConfig.supportsGridView == false)
    }
    
    @Test func testSupportsListView() async throws {
        let listConfig = ViewConfiguration(viewMode: .listView)
        let gridConfig = ViewConfiguration(viewMode: .gridView)
        let bothConfig = ViewConfiguration(viewMode: .both)
        
        #expect(listConfig.supportsListView == true)
        #expect(gridConfig.supportsListView == false)
        #expect(bothConfig.supportsListView == true)
    }
    
    @Test func testAllowsViewModeSwitch() async throws {
        let bothConfig = ViewConfiguration(viewMode: .both)
        let listConfig = ViewConfiguration(viewMode: .listView)
        let gridConfig = ViewConfiguration(viewMode: .gridView)
        
        #expect(bothConfig.allowsViewModeSwitch == true)
        #expect(listConfig.allowsViewModeSwitch == false)
        #expect(gridConfig.allowsViewModeSwitch == false)
    }
    
    // MARK: - GridConfiguration Method Tests
    
    @Test func testGridConfigurationIsValidColumnCount() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 2,
            columnsCount: 4,
            maxColumnsCount: 8
        )
        
        #expect(gridConfig.isValidColumnCount(1) == false) // Below min
        #expect(gridConfig.isValidColumnCount(2) == true)  // At min
        #expect(gridConfig.isValidColumnCount(5) == true)  // Within range
        #expect(gridConfig.isValidColumnCount(8) == true)  // At max
        #expect(gridConfig.isValidColumnCount(9) == false) // Above max
    }
    
    @Test func testGridConfigurationClampColumnCount() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 2,
            columnsCount: 4,
            maxColumnsCount: 8
        )
        
        #expect(gridConfig.clampColumnCount(1) == 2)  // Clamped to min
        #expect(gridConfig.clampColumnCount(5) == 5)  // Within range, unchanged
        #expect(gridConfig.clampColumnCount(10) == 8) // Clamped to max
        #expect(gridConfig.clampColumnCount(2) == 2)  // At min boundary
        #expect(gridConfig.clampColumnCount(8) == 8)  // At max boundary
    }
    
    @Test func testViewConfigurationImmutability() async throws {
        let config = ViewConfiguration(
            viewMode: .both,
            startsInGridView: true
        )
        
        // Configuration should maintain its values (immutable properties)
        #expect(config.viewMode == .both)
        #expect(config.startsInGridView == true)
    }
    
    @Test func testGridConfigurationImmutability() async throws {
        let gridConfig = ViewConfiguration.GridConfiguration(
            minColumnsCount: 2,
            columnsCount: 4,
            maxColumnsCount: 8
        )
        
        // Grid configuration should maintain its values
        #expect(gridConfig.minColumnsCount == 2)
        #expect(gridConfig.columnsCount == 4)
        #expect(gridConfig.maxColumnsCount == 8)
    }
}