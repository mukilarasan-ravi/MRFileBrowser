import SwiftUI

public struct TopBar: View {

    @Binding var showSearchBar: Bool
    @Binding var titleName: String
    @Binding var isGridView: Bool  // <- added
    @Binding var columnsCount: Int
    public var onClose: () -> Void

    public init(showSearchBar: Binding<Bool>, titleName: Binding<String>, isGridView: Binding<Bool> = .constant(false), columnsCount :Binding<Int> = .constant(2) , onClose: @escaping () -> Void) {
        _showSearchBar = showSearchBar
        _titleName = titleName
        _isGridView = isGridView
        _columnsCount = columnsCount
        self.onClose = onClose
    }

    public var body: some View {
        HStack {

            // LEFT — CLOSE BUTTON
            Button(action: {
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.leading, 4)
            }

            Spacer()

            // CENTER — TITLE
            Text(titleName)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Spacer()

            // GRID TOGGLE (iOS 14+ only)
            if #available(iOS 14.0, *) {
                Button {
                    isGridView.toggle()
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .padding(.trailing, 4)
                }
            }

            // SEARCH ICON
            Button {
                withAnimation(.easeInOut) {
                    showSearchBar.toggle()
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .padding(.trailing, 4)
            }
        }
        .frame(height: 56)
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
    }
}
