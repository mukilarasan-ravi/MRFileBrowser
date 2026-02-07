//
//  ThemeConfiguration.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 31/01/26.
//

import Foundation
import SwiftUI

//Configuration for customizing the appearance and colors of the file browser
public struct ThemeConfiguration {

    //Core Colors
    //Primary accent color used for buttons, icons, and highlights
    public let primaryColor: Color

    //Secondary color for less prominent UI elements
    public let secondaryColor: Color

    //Success color for positive actions and feedback
    public let successColor: Color

    //Error/destructive color for warnings and destructive actions
    public let errorColor: Color

    //Information color for informational messages
    public let infoColor: Color

    //Background Colors
    //Main background color for views
    public let backgroundColor: Color

    //Secondary background color for cards and overlays
    public let secondaryBackgroundColor: Color

    //Overlay background color (typically semi-transparent)
    public let overlayBackgroundColor: Color

    //Text Colors
    //Primary text color
    public let primaryTextColor: Color

    //Secondary text color for less prominent text
    public let secondaryTextColor: Color

    //Text color to use on primary/colored backgrounds (typically white for contrast)
    public let textOnPrimaryColor: Color

    //File Browser Specific Colors
    //Color for folder icons and folder-related elements
    public let folderColor: Color

    //Color for file icons
    public let fileColor: Color

    //Color for locked item indicators
    public let lockColor: Color

    //Color for server-related indicators
    public let serverColor: Color

    //Color for close/dismiss buttons
    public let closeButtonColor: Color

    //Color for top bar close button
    public let topBarCloseButtonColor: Color

    //Border and Separator Colors
    //Color for borders and dividers
    public let borderColor: Color

    //Color for selected/highlighted borders
    public let selectedBorderColor: Color

    //Initializer
    public init(
        primaryColor: Color = Color.blue.opacity(0.7),
        secondaryColor: Color = Color.blue.opacity(0.7),
        successColor: Color = Color.green.opacity(0.7),
        errorColor: Color = Color.red.opacity(0.8),
        infoColor: Color = Color.blue.opacity(0.7),
        backgroundColor: Color = Color(red: 0.92, green: 0.92, blue: 0.92),
        secondaryBackgroundColor: Color = Color(red: 0.92, green: 0.92, blue: 0.92),
        overlayBackgroundColor: Color = Color.black.opacity(0.4),
        primaryTextColor: Color = Color.blue,
        secondaryTextColor: Color = Color.blue.opacity(0.7),
        textOnPrimaryColor: Color = Color.white,
        folderColor: Color = Color.blue.opacity(0.7),
        fileColor: Color = Color.blue.opacity(0.7),
        lockColor: Color = Color.blue.opacity(0.7),
        serverColor: Color = Color.blue.opacity(0.7),
        closeButtonColor: Color = Color.red.opacity(0.8),
        topBarCloseButtonColor: Color = Color.blue.opacity(0.7),
        borderColor: Color = Color(.systemGray4),
        selectedBorderColor: Color = Color.blue.opacity(0.7)
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.successColor = successColor
        self.errorColor = errorColor
        self.infoColor = infoColor
        self.backgroundColor = backgroundColor
        self.secondaryBackgroundColor = secondaryBackgroundColor
        self.overlayBackgroundColor = overlayBackgroundColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.textOnPrimaryColor = textOnPrimaryColor
        self.folderColor = folderColor
        self.fileColor = fileColor
        self.lockColor = lockColor
        self.serverColor = serverColor
        self.closeButtonColor = closeButtonColor
        self.topBarCloseButtonColor = topBarCloseButtonColor
        self.borderColor = borderColor
        self.selectedBorderColor = selectedBorderColor
    }
}

//Predefined Themes
extension ThemeConfiguration {

    //Default blue theme for backward compatibility
    public static let blue = ThemeConfiguration()

    //Green theme with green accent colors
    public static let green = ThemeConfiguration(
        primaryColor: Color.green.opacity(0.7),
        secondaryColor: Color.gray,
        successColor: Color.green.opacity(0.8),
        errorColor: Color.red.opacity(0.8),
        infoColor: Color.green.opacity(0.7),
        overlayBackgroundColor: Color.black.opacity(0.4),
        primaryTextColor: Color.green,
        secondaryTextColor: Color.green.opacity(0.7),
        folderColor: Color.green.opacity(0.7),
        fileColor: Color.green.opacity(0.7),
        lockColor: Color.green.opacity(0.7),
        serverColor: Color.green.opacity(0.7),
        closeButtonColor: Color.red.opacity(0.8),
        topBarCloseButtonColor: Color.green.opacity(0.7),
        borderColor: Color(.systemGray4),
        selectedBorderColor: Color.green.opacity(0.7)
    )

    //Orange theme with orange accent colors
    public static let orange = ThemeConfiguration(
        primaryColor: Color.orange.opacity(0.7),
        secondaryColor: Color.gray,
        successColor: Color.orange.opacity(0.8),
        errorColor: Color.red.opacity(0.8),
        infoColor: Color.orange.opacity(0.7),
        overlayBackgroundColor: Color.black.opacity(0.4),
        primaryTextColor: Color.orange,
        secondaryTextColor: Color.orange.opacity(0.7),
        folderColor: Color.orange.opacity(0.7),
        fileColor: Color.orange.opacity(0.7),
        lockColor: Color.orange.opacity(0.7),
        serverColor: Color.orange.opacity(0.7),
        closeButtonColor: Color.red.opacity(0.8),
        topBarCloseButtonColor: Color.orange.opacity(0.7),
        borderColor: Color(.systemGray4),
        selectedBorderColor: Color.orange.opacity(0.7)
    )

    //Multi theme with diverse colors for better visual hierarchy
    //This is purly for demonstration and testing purposes to show the effect of different colors in the UI
    public static let multi = ThemeConfiguration(
        primaryColor: Color.blue,
        secondaryColor: Color.gray.opacity(0.6),
        successColor: Color.green,
        errorColor: Color.red,
        infoColor: Color.blue.opacity(0.8),
        backgroundColor: Color(red: 0.96, green: 0.96, blue: 0.98),
        secondaryBackgroundColor: Color.white,
        overlayBackgroundColor: Color.black.opacity(0.4),
        primaryTextColor: Color.black,
        secondaryTextColor: Color.gray,
        textOnPrimaryColor: Color.white,
        folderColor: Color.blue,
        fileColor: Color.gray,
        lockColor: Color.red,
        serverColor: Color.green,
        closeButtonColor: Color.red,
        topBarCloseButtonColor: Color.blue,
        borderColor: Color(.systemGray4),
        selectedBorderColor: Color.blue
    )
}

//Environment Support
private struct ThemeConfigurationEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeConfiguration.blue
}

extension EnvironmentValues {
    public var themeConfiguration: ThemeConfiguration {
        get { self[ThemeConfigurationEnvironmentKey.self] }
        set { self[ThemeConfigurationEnvironmentKey.self] = newValue }
    }
}

extension View {
    //Apply a theme to the view hierarchy
    public func theme(_ theme: ThemeConfiguration) -> some View {
        self.environment(\.themeConfiguration, theme)
    }
}
