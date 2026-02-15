import SwiftUI

/// Root wrapper for FileBrowserLayout with NavigationView
public struct FileBrowserRootView: View {

    public let folderURL: URL
    @Binding var titleName: String
    private let serverConfiguration: ServerConfiguration
    private let themeConfiguration: ThemeConfiguration
    private let viewConfiguration: ViewConfiguration

    // MARK: - Public initializer
    public init(
        folderURL: URL,
        titleName: Binding<String>,
        serverConfiguration: ServerConfiguration = .default,
        themeConfiguration: ThemeConfiguration = .blue,
        viewConfiguration: ViewConfiguration = .default
    ) {
        self.folderURL = folderURL
        self.serverConfiguration = serverConfiguration
        self.themeConfiguration = themeConfiguration
        self.viewConfiguration = viewConfiguration
        _titleName = titleName
    }

    public var body: some View {
        NavigationView {
            FileBrowserLayout(
                        folderURL: folderURL,
                        titleName: $titleName,
                        serverConfiguration : serverConfiguration,
                        viewConfiguration: viewConfiguration
                    )

            .navigationBarBackButtonHidden(true)
        }
        .environment(\.themeConfiguration, themeConfiguration) // Setting Theme as environment variable
        .navigationViewStyle(StackNavigationViewStyle()) // iPad-safe
    }
}
