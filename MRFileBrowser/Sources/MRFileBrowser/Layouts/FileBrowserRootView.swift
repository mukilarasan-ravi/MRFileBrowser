import SwiftUI

/// Root wrapper for FileBrowserLayout with NavigationView
public struct FileBrowserRootView: View {

    public let folderURL: URL
    @Binding var titleName: String
    private let serverConfiguration: ServerConfiguration
    @State private var isGridView = true
    @State private var columnsCount = 2

    // MARK: - Public initializer
    public init(
        folderURL: URL,
        titleName: Binding<String>,
        serverConfiguration: ServerConfiguration = .default
    ) {
        self.folderURL = folderURL
        self.serverConfiguration = serverConfiguration
        _titleName = titleName
    }

    public var body: some View {
        NavigationView {
            FileBrowserLayout(
                        folderURL: folderURL,
                        titleName: $titleName,
                        isGridView: $isGridView,
                        columnsCount: $columnsCount,
                        serverConfiguration : serverConfiguration,
                    )

            .navigationBarBackButtonHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // iPad-safe
    }
}
