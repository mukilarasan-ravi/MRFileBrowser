import SwiftUI

public struct TopBar: View {

    let isRoot: Bool

    @Binding var showSearchBar: Bool
    @Binding var titleName: String
    @Binding var isGridView: Bool
    @Binding var columnsCount: Int

    let showsSearch: Bool
    let showsGridToggle: Bool

    public var onBack: () -> Void

    public init(
        isRoot: Bool,
        showSearchBar: Binding<Bool>,
        titleName: Binding<String>,
        isGridView: Binding<Bool> = .constant(false),
        columnsCount: Binding<Int> = .constant(2),
        showsSearch: Bool = true,
        showsGridToggle: Bool = true,
        onBack: @escaping () -> Void
    ) {
        self.isRoot = isRoot
        _showSearchBar = showSearchBar
        _titleName = titleName
        _isGridView = isGridView
        _columnsCount = columnsCount
        self.showsSearch = showsSearch
        self.showsGridToggle = showsGridToggle
        self.onBack = onBack
    }

    public var body: some View {
        HStack {

            // LEFT — BACK / CLOSE
            Button(action: onBack) {
                Image(systemName: isRoot ? "xmark" : "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
            }

            Spacer()

            // CENTER — TITLE
            Text(titleName)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Spacer()

            // GRID TOGGLE
            if showsGridToggle, #available(iOS 14.0, *) {
                Button {
                    isGridView.toggle()
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
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
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
    }
}
