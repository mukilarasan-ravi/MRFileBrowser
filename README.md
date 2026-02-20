# MRFileBrowser

A comprehensive SwiftUI framework that provides powerful file browsing and management capabilities for iOS applications.

## Overview

MRFileBrowser offers two main components:

- **FileBrowserRootView**: A full-featured file browser with WiFi sharing capabilities, customizable themes, and advanced server configurations.
- **FolderPickerView**: A reusable component that presents an expandable file system tree for selecting files or folders, with support for single/multiple selection modes and file type filtering.


## FileBrowserRootView Basic config

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

For more details, see [FileBrowserRootView Documentation](Docs/Components/FileBrowserRootView.md).

## FolderPickerView Basic config

```swift
struct MyView: View {
    @State private var showPicker = false

    var body: some View {
        Button("Pick Folder") { showPicker = true }
            .sheet(isPresented: $showPicker) {
                FolderPickerView(
                    configuration: FolderPickerConfiguration(
                        title: "Choose Destination",
                        allowedRootPath: FileManager.default
                            .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    ),
                    delegate: myDelegate
                )
            }
    }
}
```

### UIKit

```swift
let config = FolderPickerConfiguration(
    title: "Select Folder",
    allowedRootPath: rootURL
)
let picker = FolderPickerViewController(configuration: config)
picker.delegate = self
picker.modalPresentationStyle = .overFullScreen
picker.modalTransitionStyle = .crossDissolve
present(picker, animated: true)
```

For more details, see [FolderPickerView Documentation](Docs/Components/FolderPickerView.md).

