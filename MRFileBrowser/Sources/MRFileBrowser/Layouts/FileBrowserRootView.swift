import SwiftUI

/// Root wrapper for FileBrowserLayout with NavigationView
public struct FileBrowserRootView: View {

    public let folderURL: URL
    var onClose: () -> Void
    @Binding var titleName: String
    @State private var isGridView = true
    @State private var columnsCount = 2

    // MARK: - Public initializer
    public init(
        folderURL: URL,
        titleName: Binding<String>,
        onClose: @escaping () -> Void
    ) {
        self.folderURL = folderURL
        _titleName = titleName
        self.onClose = onClose
    }

    public var body: some View {
        NavigationView {

            FileBrowserLayout(
                        folderURL: folderURL,
                        titleName: $titleName,
                        isGridView: $isGridView,
                        columnsCount: $columnsCount,
                        onClose: onClose
                    )

            .navigationBarBackButtonHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // iPad-safe
    }
}
