//
//  ServerConfiguration.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 26/01/26.
//

import Foundation
import SwiftUI

//Configuration for server-related UI and behavior
public struct ServerConfiguration {
    //Options for how the server button appears and behaves in the bottom bar
    public enum ServerButtonMode {
        //Don't show the server button at all
        case hidden
        //Show server button and open the built-in server status popup
        case show
        //Show server button and open a custom view provided by the user
        //The closure receives a dismiss callback that the custom view can call to close itself
        case showCustomView((@escaping () -> Void) -> AnyView)
    }

    //Options for server background behavior
    public enum BackgroundMode {
        //Server stops when app goes to background
        case stopOnBackground
        //Server continues running in background
        case continueInBackground
    }

    //How the server button should appear and behave
    public let serverButtonMode: ServerButtonMode

    //Whether the server should run in background
    public let backgroundMode: BackgroundMode

    //HTML provider for generating web interface
    public let htmlProvider: HTTPServerHTMLProvider

    //Initialize server configuration
    //- Parameters:
    //  - serverButtonMode: How the server button should behave (default: show)
    //  - backgroundMode: Whether server should run in background (default: stopOnBackground)
    //  - htmlProvider: HTML provider for web interface (default: DefaultHTMLProvider)
    public init(
        serverButtonMode: ServerButtonMode = .show,
        backgroundMode: BackgroundMode = .stopOnBackground,
        htmlProvider: HTTPServerHTMLProvider = DefaultHTMLProvider()
    ) {
        self.serverButtonMode = serverButtonMode
        self.backgroundMode = backgroundMode
        self.htmlProvider = htmlProvider
    }

    //Default configuration with built-in popup and stop on background
    public static let `default` = ServerConfiguration()

    //Configuration with hidden server button
    public static let noServer = ServerConfiguration(serverButtonMode: .hidden)

    //Configuration with background server support
    public static let backgroundServer = ServerConfiguration(backgroundMode: .continueInBackground)

    //Configuration that hides all locked items from web interface
    public static let hidingAllLockedItems = ServerConfiguration(
        htmlProvider: DefaultHTMLProvider(showLockedItems: false, showParentLockedItems: false)
    )

    //Configuration that shows directly locked items but hides parent locked items
    public static let showingDirectLocksOnly = ServerConfiguration(
        htmlProvider: DefaultHTMLProvider(showLockedItems: true, showParentLockedItems: false)
    )
}

//Convenience methods for ServerButtonMode
extension ServerConfiguration.ServerButtonMode {
    //Check if the server button should be shown
    var isVisible: Bool {
        switch self {
        case .hidden:
            return false
        case .show, .showCustomView:
            return true
        }
    }

    //Check if this mode uses a custom view
    var usesCustomView: Bool {
        switch self {
        case .showCustomView:
            return true
        case .hidden, .show:
            return false
        }
    }
}