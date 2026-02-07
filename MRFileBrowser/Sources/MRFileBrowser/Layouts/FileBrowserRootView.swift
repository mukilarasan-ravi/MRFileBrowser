import SwiftUI

/// Root wrapper for FileBrowserLayout with NavigationView
public struct FileBrowserRootView: View {

    public let folderURL: URL
    @Binding var titleName: String
    private let serverConfiguration: ServerConfiguration
    private let themeConfiguration: ThemeConfiguration
    @State private var isGridView = true
    @State private var columnsCount = 2

    // MARK: - Public initializer
    public init(
        folderURL: URL,
        titleName: Binding<String>,
        serverConfiguration: ServerConfiguration = .default,
        themeConfiguration: ThemeConfiguration = .blue
    ) {
        self.folderURL = folderURL
        self.serverConfiguration = serverConfiguration
        self.themeConfiguration = themeConfiguration
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
        .environment(\.themeConfiguration, themeConfiguration) // Setting Theme as environment variable
        .navigationViewStyle(StackNavigationViewStyle()) // iPad-safe
    }
}
