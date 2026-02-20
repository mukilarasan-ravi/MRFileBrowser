# FileBrowserRootView Documentation

## Overview

`FileBrowserRootView` is a comprehensive SwiftUI component from the MRFileBrowser framework that provides a full-featured file browser with WiFi sharing capabilities, customizable themes, and advanced server configurations.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Parameters](#parameters)
3. [Server Configuration](#server-configuration)
4. [Theme Configuration](#theme-configuration)
5. [HTML Providers](#html-providers)
6. [Complete Examples](#complete-examples)
7. [Best Practices](#best-practices)

## Basic Usage

```swift
import SwiftUI
import MRFileBrowser

struct ContentView: View {
    @State private var folderURL: URL? = nil
    @State private var titleName: String = "My File Browser"

    var body: some View {
        // Your UI to trigger file browser
        Button("Open File Browser") {
            folderURL = getDocumentsDirectory()
        }
        .fullScreenCover(item: $folderURL) { url in
            FileBrowserRootView(
                folderURL: url,
                titleName: $titleName,
                serverConfiguration: .default,
                themeConfiguration: .blue
            )
        }
    }
}
```

## Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `folderURL` | `URL` | The root directory URL to browse |
| `titleName` | `Binding<String>` | The display title for the browser |
| `serverConfiguration` | `ServerConfiguration` | Server and sharing configuration |
| `themeConfiguration` | `ThemeConfiguration` | UI theme settings |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `viewConfiguration` | `ViewConfiguration` | `.default` | Switch between list view, grid view, or both.
 |

## Server Configuration

The `ServerConfiguration` defines how the WiFi sharing server behaves and appears.

### Server Button Modes

```swift
// 1. Hidden - No WiFi sharing
let noSharingConfig = ServerConfiguration(
    serverButtonMode: .hidden
)

// 2. Show Default - Standard WiFi sharing button
let defaultConfig = ServerConfiguration(
    serverButtonMode: .show
)

// 3. Custom View - Show custom UI instead of server button
// It would be useful to offer this as a premium feature, with a pop-up prompting users to either pay for access or dismiss the offer.
let customConfig = ServerConfiguration(
    serverButtonMode: .showCustomView { dismissCallback in
        AnyView(
            CustomServerView(onDismiss: dismissCallback)
        )
    }
)
```

### Background Modes
If you want to control whether the server stops or continues running when the app goes into the background, you can use this configuration.

```swift
// Stop server when app goes to background
let stopOnBackgroundConfig = ServerConfiguration(
    serverButtonMode: .show,
    backgroundMode: .stopOnBackground
)

// Continue server in background
let continueInBackgroundConfig = ServerConfiguration(
    serverButtonMode: .show,
    backgroundMode: .continueInBackground
)
```


## Theme Configuration

Control the visual appearance of the file browser.

```swift
// Available theme options
.blue    // Blue theme
.green   // Green theme
.orange  // Orange theme
.multi   // Multi-color theme -> for testing purpose
```

### Theme Usage Example

```swift
FileBrowserRootView(
    folderURL: url,
    titleName: $titleName,
    serverConfiguration: serverConfig,
    themeConfiguration: .green  // Apply green theme
)
```
You can define your own colors and use them however you need.


## HTML Providers

Customize the web interface that appears when users connect via WiFi.

When the user starts the server, they can access the files through a browser. By default, a simple HTML page is used to display a list of files and folders.

If you want the page to match a specific theme, you can use the `ThemeAwareHTMLProvider`, which styles the page based on the `themeConfiguration` argument.

Alternatively, you can fully customize the HTML page as needed and supply your own implementation via the `htmlProvider`.

### 1. Default HTML Provider

```swift
let defaultConfig = ServerConfiguration(
    serverButtonMode: .show
    // No htmlProvider specified - uses default
)
```

### 2. Dark Theme HTML Provider

```swift
let darkThemeProvider = DarkThemeHTMLProvider(
    showLockedItems: true,           // Show locked/protected files
    showParentLockedItems: false     // Hide parent directory locks
)

let config = ServerConfiguration(
    serverButtonMode: .show,
    htmlProvider: darkThemeProvider
)
```

### 3. Theme Aware HTML Provider

```swift
let themeAwareProvider = ThemeAwareHTMLProvider(
    theme: .blue,                    // Match the app theme
    showLockedItems: false,
    showParentLockedItems: false
)

let config = ServerConfiguration(
    serverButtonMode: .show,
    htmlProvider: themeAwareProvider
)
```

## Complete Examples

### Example 1: Basic File Browser

```swift
struct BasicFileBrowserView: View {
    @State private var folderURL: URL? = nil
    @State private var titleName: String = "Documents"

    var body: some View {
        VStack {
            Button("Browse Documents") {
                folderURL = getDocumentsDirectory()
            }
        }
        .fullScreenCover(item: $folderURL) { url in
            FileBrowserRootView(
                folderURL: url,
                titleName: $titleName,
                serverConfiguration: ServerConfiguration(
                    serverButtonMode: .show,
                    backgroundMode: .continueInBackground
                ),
                themeConfiguration: .blue
            )
        }
    }

    private func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}
```

### Example 2: Advanced Configuration with Custom UI

```swift
struct AdvancedFileBrowserView: View {
    @State private var folderURL: URL? = nil
    @State private var titleName: String = "Premium Files"

    var body: some View {
        VStack {
            Button("Open Advanced Browser") {
                folderURL = getAppDirectory()
            }
        }
        .fullScreenCover(item: $folderURL) { url in
            let advancedConfig = ServerConfiguration(
                serverButtonMode: .showCustomView { dismissCallback in
                    AnyView(
                        PremiumFeatureView(
                            onDismiss: dismissCallback,
                            onUpgrade: {
                                // Handle premium upgrade
                                print("User wants to upgrade")
                            }
                        )
                    )
                },
                backgroundMode: .continueInBackground,
                htmlProvider: DefaultHTMLProvider(showLockedItems: false, showParentLockedItems: false)
            )

            FileBrowserRootView(
                folderURL: url,
                titleName: $titleName,
                serverConfiguration: advancedConfig,
                themeConfiguration: .orange,
                viewConfiguration: .default
            )
            .navigationBarHidden(true)
            .interactiveDismissDisabled(true)
        }
    }
}

struct PremiumFeatureView: View {
    let onDismiss: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Premium Feature")
                .font(.title)
                .fontWeight(.bold)

            Text("WiFi sharing is a premium feature.\nUpgrade to access all features.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Upgrade Now") {
                onUpgrade()
                onDismiss()
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") {
                onDismiss()
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding()
        .background(Color.black.opacity(0.3))
    }
}
```

### Example 3: Multiple Configuration Options

```swift
struct ConfigurableFileBrowserView: View {
    @State private var folderURL: URL? = nil
    @State private var titleName: String = "File Manager"
    @State private var selectedTheme: ThemeConfiguration = .blue
    @State private var showLockedItems: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Theme selection
            Picker("Theme", selection: $selectedTheme) {
                Text("Blue").tag(ThemeConfiguration.blue)
                Text("Green").tag(ThemeConfiguration.green)
                Text("Orange").tag(ThemeConfiguration.orange)
                Text("Multi").tag(ThemeConfiguration.multi)
            }
            .pickerStyle(.segmented)

            // Locked items toggle
            Toggle("Show Locked Items", isOn: $showLockedItems)


            Button("Launch File Browser") {
                folderURL = createTestDirectory()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .fullScreenCover(item: $folderURL) { url in
            let serverConfig = createServerConfiguration()

            FileBrowserRootView(
                folderURL: url,
                titleName: $titleName,
                serverConfiguration: serverConfig,
                themeConfiguration: selectedTheme
            )
        }
    }

    private func createServerConfiguration() -> ServerConfiguration {
        return ServerConfiguration(
            serverButtonMode: .show,
            backgroundMode: .continueInBackground,
            htmlProvider: DefaultHTMLProvider(showLockedItems: false, showParentLockedItems: false)
        )
    }

    private func createTestDirectory() -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let testURL = documentsURL.appendingPathComponent("TestFiles")

        do {
            try FileManager.default.createDirectory(at: testURL, withIntermediateDirectories: true)
            return testURL
        } catch {
            print("Failed to create test directory: \(error)")
            return nil
        }
    }
}
```

## Best Practices

### 1. Folder URL Management

```swift
// Always ensure the directory exists
private func getOrCreateDirectory(named: String) -> URL? {
    guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
    }

    let targetURL = documentsURL.appendingPathComponent(named)

    do {
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        return targetURL
    } catch {
        print("Failed to create directory: \(error)")
        return nil
    }
}
```

### 2. Server Configuration Selection

```swift
// Choose appropriate server mode based on app needs
private func selectServerConfiguration(isPremium: Bool, allowBackground: Bool) -> ServerConfiguration {
    if !isPremium {
        // Free users - no WiFi sharing
        return ServerConfiguration(
            serverButtonMode: .hidden,
            backgroundMode: .stopOnBackground
        )
    } else if allowBackground {
        // Premium with background support
        return ServerConfiguration(
            serverButtonMode: .show,
            backgroundMode: .continueInBackground
        )
    } else {
        // Premium without background
        return ServerConfiguration(
            serverButtonMode: .show,
            backgroundMode: .stopOnBackground
        )
    }
}
```

### 3. Theme and Branding Consistency

```swift
// Keep theme consistent across your app
extension ThemeConfiguration {
    static var appDefault: ThemeConfiguration {
        // Use your app's primary color scheme
        return .blue
    }
}

```

### 4. Error Handling

```swift
struct SafeFileBrowserWrapper: View {
    @State private var folderURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var showingError = false

    var body: some View {
        VStack {
            Button("Browse Files") {
                openFileBrowser()
            }
        }
        .fullScreenCover(item: $folderURL) { url in
            FileBrowserRootView(
                folderURL: url,
                titleName: .constant("Files"),
                serverConfiguration: .defaultSafe,
                themeConfiguration: .blue
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }

    private func openFileBrowser() {
        do {
            let url = try createBrowserDirectory()
            folderURL = url
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func createBrowserDirectory() throws -> URL {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileError.documentsDirectoryNotFound
        }

        let browserURL = documentsURL.appendingPathComponent("Browser")
        try FileManager.default.createDirectory(at: browserURL, withIntermediateDirectories: true)
        return browserURL
    }
}

enum FileError: LocalizedError {
    case documentsDirectoryNotFound

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryNotFound:
            return "Could not access documents directory"
        }
    }
}

extension ServerConfiguration {
    static var defaultSafe: ServerConfiguration {
        return ServerConfiguration(
            serverButtonMode: .show,
            backgroundMode: .stopOnBackground
        )
    }
}
```

## Common Configuration Patterns

### 1. No WiFi Sharing (Simple File Browser)

```swift
let simpleConfig = ServerConfiguration(
    serverButtonMode: .hidden,
    backgroundMode: .continueInBackground
)
```

### 2. Basic WiFi Sharing

```swift
let basicSharingConfig = ServerConfiguration(
    serverButtonMode: .show,
    backgroundMode: .continueInBackground
)
```

### 3. Dark Theme for Night Mode

```swift
let darkConfig = ServerConfiguration(
    serverButtonMode: .show,
    backgroundMode: .continueInBackground,
    htmlProvider: DarkThemeHTMLProvider(
        showLockedItems: false,
        showParentLockedItems: false
    )
)
```

### 4. Custom Paywall Integration

```swift
let paywallConfig = ServerConfiguration(
    serverButtonMode: .showCustomView { dismissCallback in
        AnyView(
            PaywallView(
                feature: "WiFi Sharing",
                onDismiss: dismissCallback,
                onPurchase: {
                    // Handle purchase
                    dismissCallback()
                }
            )
        )
    },
    backgroundMode: .stopOnBackground
)
```

## Integration Notes

- Always present `FileBrowserRootView` using `.fullScreenCover()` for the best user experience
- Use `.navigationBarHidden(true)` if you want to hide the navigation bar
- Add `.interactiveDismissDisabled(true)` to prevent accidental dismissal via swipe gestures
- Ensure proper directory permissions before passing URLs to the browser
- Consider using background modes appropriately based on your app's needs


