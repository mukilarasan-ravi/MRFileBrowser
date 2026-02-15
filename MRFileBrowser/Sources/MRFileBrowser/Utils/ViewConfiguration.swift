//
//  ViewConfiguration.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 15/02/26.
//

import Foundation
import SwiftUI

//Configuration for managing view modes and grid layout settings in the file browser
public struct ViewConfiguration {

    //Supported view modes for the file browser
    public enum ViewMode {
        //Only list view is available
        case listView
        //Only grid view is available
        case gridView
        //Both list and grid views are available with toggle
        case both
    }

    //Grid configuration for column management
    public struct GridConfiguration {
        //Minimum number of columns (must be >= 1)
        public let minColumnsCount: Int
        //Current number of columns (will be clamped between min and max)
        public let columnsCount: Int
        //Maximum number of columns for zoom gestures
        public let maxColumnsCount: Int

        //Initialize grid configuration with validation
        //- Parameters:
        //  - minColumnsCount: Minimum columns (default: 1, cannot be less than 1)
        //  - columnsCount: Initial columns (default: 2, will be clamped to valid range)
        //  - maxColumnsCount: Maximum columns (default: 4, cannot be less than minColumnsCount)
        public init(
            minColumnsCount: Int = 1,
            columnsCount: Int = 2,
            maxColumnsCount: Int = 4
        ) {
            // Ensure min is at least 1
            self.minColumnsCount = max(1, minColumnsCount)

            // Ensure max is at least min
            self.maxColumnsCount = max(self.minColumnsCount, maxColumnsCount)

            // Clamp current between min and max
            self.columnsCount = max(self.minColumnsCount, min(maxColumnsCount, columnsCount))
        }

        //Validate if a column count is within the allowed range
        //- Parameter count: Column count to validate
        //- Returns: True if count is within minColumnsCount...maxColumnsCount
        public func isValidColumnCount(_ count: Int) -> Bool {
            return count >= minColumnsCount && count <= maxColumnsCount
        }

        //Clamp a column count to the valid range
        //- Parameter count: Column count to clamp
        //- Returns: Clamped column count within minColumnsCount...maxColumnsCount
        public func clampColumnCount(_ count: Int) -> Int {
            return max(minColumnsCount, min(maxColumnsCount, count))
        }
    }

    //The current view mode
    public let viewMode: ViewMode

    //Grid configuration (only relevant for GridView and Both modes)
    public let gridConfiguration: GridConfiguration

    //Whether the current view should start in grid mode
    //(only applicable when viewMode is .both)
    public let startsInGridView: Bool

    //Initialize view configuration
    //- Parameters:
    //  - viewMode: The supported view mode (default: .both)
    //  - gridConfiguration: Grid layout configuration (default: GridConfiguration())
    //  - startsInGridView: Whether to start in grid view when both are available (default: true)
    public init(
        viewMode: ViewMode = .both,
        gridConfiguration: GridConfiguration = GridConfiguration(),
        startsInGridView: Bool = true
    ) {
        self.viewMode = viewMode
        self.gridConfiguration = gridConfiguration
        self.startsInGridView = startsInGridView
    }

    //Default configuration for backward compatibility
    public static let `default` = ViewConfiguration()

    //List-only configuration
    public static let listOnly = ViewConfiguration(viewMode: .listView)

    //Grid-only configuration (automatically handles iOS version compatibility)
    public static var gridOnly: ViewConfiguration {
        if #available(iOS 14.0, *) {
            return ViewConfiguration(viewMode: .gridView)
        } else {
            // Fallback to .both on iOS < 14 since grid view isn't supported
            return ViewConfiguration(viewMode: .both, startsInGridView: false)
        }
    }

    //Whether grid view is supported by this configuration and current iOS version
    public var supportsGridView: Bool {
        let configurationSupportsGrid = viewMode == .gridView || viewMode == .both
        if #available(iOS 14.0, *) {
            return configurationSupportsGrid
        } else {
            return false // Grid view requires iOS 14+
        }
    }

    //Whether list view is supported by this configuration
    public var supportsListView: Bool {
        return viewMode == .listView || viewMode == .both
    }

    //Whether view mode switching is allowed
    public var allowsViewModeSwitch: Bool {
        return viewMode == .both
    }
}