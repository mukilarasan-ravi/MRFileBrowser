import SwiftUI

public struct TopBar: View {

    let isRoot: Bool

    @Binding var showSearchBar: Bool
    @Binding var titleName: String
    @Binding var isGridView: Bool
    @Binding var columnsCount: Int

    let showsSearch: Bool
    let viewConfiguration: ViewConfiguration
    @Environment(\.themeConfiguration) private var theme

    public var onBack: () -> Void

    public init(
        isRoot: Bool,
        showSearchBar: Binding<Bool>,
        titleName: Binding<String>,
        isGridView: Binding<Bool> = .constant(false),
        columnsCount: Binding<Int> = .constant(2),
        showsSearch: Bool = true,
        viewConfiguration: ViewConfiguration = .default,
        onBack: @escaping () -> Void
    ) {
        self.isRoot = isRoot
        _showSearchBar = showSearchBar
        _titleName = titleName
        _isGridView = isGridView
        _columnsCount = columnsCount
        self.showsSearch = showsSearch
        self.viewConfiguration = viewConfiguration
        self.onBack = onBack
    }

    public var body: some View {
        HStack {

            // LEFT — BACK / CLOSE
            Button(action: onBack) {
                Image(systemName: isRoot ? "xmark" : "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isRoot ? theme.topBarCloseButtonColor : theme.primaryColor)
            }

            Spacer()

            // CENTER — TITLE
            Text(titleName)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.primaryTextColor)

            Spacer()

            // GRID TOGGLE
            if viewConfiguration.allowsViewModeSwitch, #available(iOS 14.0, *) {
                Button {
                    isGridView.toggle()
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .foregroundColor(theme.primaryColor)
                }
            }

            // SEARCH
            if showsSearch {
                Button {
                    withAnimation(.easeInOut) {
                        showSearchBar.toggle()
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.primaryColor)
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal)
        .background(theme.secondaryBackgroundColor)
    }
}
