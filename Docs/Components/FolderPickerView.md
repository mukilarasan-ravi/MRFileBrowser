# FolderPickerView

`FolderPickerView` is a reusable SwiftUI component that presents an expandable file system tree. It lets users choose files, folders, or both, supports single or multiple selection modes, and allows filtering by specific file types.

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [FolderPickerConfiguration](#folderpickerconfiguration)
  - [Properties](#properties)
  - [Enums](#enums)
- [FolderPickerDelegate](#folderpickerdelegate)
- [FolderPickerViewController (UIKit)](#folderpickerviewcontroller-uikit)
- [Features](#features)
- [Examples](#examples)

---

## Overview

`FolderPickerView` is configured through a `FolderPickerConfiguration` value and reports results via the `FolderPickerDelegate` protocol. It can be embedded directly as a SwiftUI view or presented modally in UIKit using `FolderPickerViewController`.

---

## Quick Start

### SwiftUI

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

---

## FolderPickerConfiguration

The single configuration object that drives all behaviour of the picker.

### Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `title` | `String` | `"Choose Folder"` | Title shown in the picker header. |
| `allowedRootPath` | `URL` | *(required)* | Root directory for the folder tree. The picker cannot navigate above this path. |
| `showCancelButton` | `Bool` | `true` | Whether the Cancel button is visible. |
| `confirmButtonTitle` | `String` | `"Select"` | Label for the confirm/select button. |
| `lockDisplayMode` | `LockDisplayMode` | `.showAsLocked` | Controls how locked items are rendered. See [LockDisplayMode](#lockdisplaymode). |
| `lockSelectabilityMode` | `LockSelectabilityMode` | `.selectable` | Controls whether locked items can be tapped. See [LockSelectabilityMode](#lockselectabilitymode). |
| `lockExpandable` | `Bool` | `false` | Whether locked folders can be expanded. Automatically forced to `false` when `lockSelectabilityMode` is `.nonSelectable`. |
| `itemType` | `ItemType` | `.folderOnly` | Which item types are listed and selectable. See [ItemType](#itemtype). |
| `defaultSelectedPaths` | `[URL]?` | `nil` | Paths that are pre-selected when the picker opens. Invalid or out-of-root paths are silently ignored. |
| `allowMultipleSelection` | `Bool` | `false` | When `true`, multiple items can be selected simultaneously. |
| `allowedExtensions` | `Set<String>?` | `nil` | File extension filter applied when `itemType` is `.folderAndFile` or `.fileOnly`. Use `"filewithnoextension"` to include extension-less files. `nil` means all types are shown. |

### Initialiser

```swift
FolderPickerConfiguration(
    title: String = "Choose Folder",
    allowedRootPath: URL,
    showCancelButton: Bool = true,
    confirmButtonTitle: String = "Select",
    lockDisplayMode: LockDisplayMode = .showAsLocked,
    lockSelectabilityMode: LockSelectabilityMode = .selectable,
    lockExpandable: Bool = false,
    itemType: ItemType = .folderOnly,
    defaultSelectedPaths: [URL]? = nil,
    allowMultipleSelection: Bool = false,
    allowedExtensions: Set<String>? = nil
)
```

---

### Enums

#### LockDisplayMode

Controls how locked files and folders are rendered in the list.

| Case | Description |
|---|---|
| `.dontShow` | Locked items are completely hidden. |
| `.showAsNormal` | Locked items are shown without any lock indicator. |
| `.showAsLocked` | Locked items are shown with a lock badge. *(default)* |

---

#### LockSelectabilityMode

Controls whether locked items can be tapped and selected.

| Case | Description |
|---|---|
| `.selectable` | Locked items can be selected normally. *(default)* |
| `.nonSelectable` | Locked items are dimmed and tapping them has no effect. Also forces `lockExpandable` to `false`. |

---

#### ItemType

Determines which file-system items are displayed and selectable.

| Case | Description |
|---|---|
| `.folderOnly` | Only folders are shown and selectable. *(default)* |
| `.folderAndFile` | Both folders and files are shown and selectable. |
| `.fileOnly` | Only files are selectable. Folders are still rendered for navigation but cannot be selected. |

---

## FolderPickerDelegate

Adopt this protocol to receive the result of user interaction.

```swift
public protocol FolderPickerDelegate: AnyObject {
    func folderPicker(_ picker: FolderPickerView, selectItems urls: [URL])
    func folderPickerDidCancel(_ picker: FolderPickerView)
}
```

| Method | When called |
|---|---|
| `folderPicker(_:selectItems:)` | User tapped the confirm button with one or more items selected. `urls` contains the selected `URL` values. |
| `folderPickerDidCancel(_:)` | User tapped Cancel or dismissed without selecting. |

### Example

```swift
extension MyViewController: FolderPickerDelegate {
    func folderPicker(_ picker: FolderPickerView, selectItems urls: [URL]) {
        print("User selected:", urls)
    }

    func folderPickerDidCancel(_ picker: FolderPickerView) {
        print("Picker cancelled")
    }
}
```

---

## FolderPickerViewController (UIKit)

A `UIViewController` wrapper that hosts `FolderPickerView` in a `UIHostingController` and pins it to the bottom of the screen. Tapping the dimmed background automatically fires `folderPickerDidCancel`.

```swift
public class FolderPickerViewController: UIViewController {
    public weak var delegate: FolderPickerDelegate?
    public init(configuration: FolderPickerConfiguration)
}
```

**Recommended presentation style:**

```swift
picker.modalPresentationStyle = .overFullScreen
picker.modalTransitionStyle = .crossDissolve
```

---

## Features

- **Expandable tree** — Lazily builds the folder hierarchy from any root `URL`.
- **Single & multi-select** — Controlled via `allowMultipleSelection`.
- **Lock-aware** — Integrates with `LockManager`; locked items can be hidden, shown normally, or badged.
- **Extension filtering** — Show only specific file types using `allowedExtensions`.
- **Pre-selection** — Open with items already selected via `defaultSelectedPaths`.
- **Resizable sheet** — Users can drag the handle to resize the picker between 250 pt and 90 % of screen height.
- **Theme-aware** — Reads `ThemeConfiguration` from the SwiftUI environment.

---

## Examples

### Folder-only picker (move destination)

```swift
let config = FolderPickerConfiguration(
    title: "Move to…",
    allowedRootPath: documentsURL,
    confirmButtonTitle: "Move Here",
    lockDisplayMode: .showAsLocked,
    lockSelectabilityMode: .nonSelectable,
    itemType: .folderOnly
)
```

### File picker filtered to images

```swift
let config = FolderPickerConfiguration(
    title: "Select Image",
    allowedRootPath: documentsURL,
    confirmButtonTitle: "Use This",
    itemType: .fileOnly,
    allowedExtensions: ["jpg", "jpeg", "png", "heic"]
)
```

### Multi-select with pre-selection

```swift
let config = FolderPickerConfiguration(
    title: "Select Files",
    allowedRootPath: documentsURL,
    itemType: .folderAndFile,
    defaultSelectedPaths: [previouslySelectedURL],
    allowMultipleSelection: true
)
```

