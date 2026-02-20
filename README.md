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

## Screenshots

### Theme Customization

| Blue Theme | Green Theme |
|------------|-------------|
| ![Blue Theme](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/BlueTheme.png) | ![Green Theme](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/GreenTheme.png) |

### View Modes

| List View | Grid View |
|-----------|-----------|
| ![List View](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/ListView.png) | ![Grid View](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/GridView.png) |

### Search Functionality

| List Search | Grid Search |
|-------------|-------------|
| ![Search List View](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/Search_ListView.png) | ![Search Grid View](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/Search_GridView.png) |

### Sorting Options

| Name Ascending | Name Descending |
|----------------|-----------------|
| ![Sort Name Ascending](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/SortNameAsc.png) | ![Sort Name Descending](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/SortNameDsc.png) |

For more details, see [FileBrowserRootView Documentation](Docs/Components/FileBrowserRootView.md).

## FileBrowserRootView Demonstrations

<div align="center">
<video width="600" controls>
  <source src="https://github.com/mukilarasan-ravi/MRFileBrowserDemo/raw/refs/heads/main/Docs/recordings/FileBrowserDemo.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>
</div>

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

## FolderPickerView Screenshots

### Selection Modes

| Single Selection | Multi Selection |
|------------------|-----------------|
| ![Folder Single Selection](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/FolderOnly_SingleSelection.png) | ![File Multi Selection](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/FileOnly_MultiSelection.png) |

### Content Types

| Files Only | Files & Folders |
|------------|-----------------|
| ![File Single Selection](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/FileOnly_SingleSelection1.png) | ![Files and Folders Multi Selection](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/FileAndFolder_MultiSelection.png) |

### Additional Examples

![File Selection Example](https://raw.githubusercontent.com/mukilarasan-ravi/MRFileBrowserDemo/refs/heads/main/Docs/screenshots/FileOnly_SingleSelection2.png)

### FolderPickerView Demonstrations

<table>
<tr>
<td align="center"><strong>Demo 1</strong></td>
<td align="center"><strong>Demo 2</strong></td>
</tr>
<tr>
<td>
<video width="300" controls>
  <source src="https://github.com/mukilarasan-ravi/MRFileBrowserDemo/raw/refs/heads/main/Docs/recordings/FolderFilePicker_1.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>
</td>
<td>
<video width="300" controls>
  <source src="https://github.com/mukilarasan-ravi/MRFileBrowserDemo/raw/refs/heads/main/Docs/recordings/FolderFilePicker_2.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>
</td>
</tr>
</table>

For more details, see [FolderPickerView Documentation](Docs/Components/FolderPickerView.md).

