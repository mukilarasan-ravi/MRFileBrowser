import SwiftUI

struct FileBrowserLayout: View {

    @State private var showSearchBar = false
    @State private var scrollOffset: CGFloat = 0
    @State private var previousOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {

            // 🔵 TOP BAR (tbar)
            TopBar()
                .frame(height: 56)
                .background(Color.gray.opacity(0.1))

            // 🔵 SEARCH BAR (sbar)
            if showSearchBar {
                SearchBar()
                    .frame(height: 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 🔵 FILE LIST AREA (scrollable)
            ScrollView {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetKey.self,
                                    value: geo.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)

                FileListPlaceholder() // temp content
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { newOffset in
                handleScroll(offset: newOffset)
            }

            // 🔵 BOTTOM BAR (bbar)
            BottomBar()
                .frame(height: 60)
                .background(Color.gray.opacity(0.1))
        }
    }

    // MARK: - Logic: Show search bar only after tbar is hit
    func handleScroll(offset: CGFloat) {
        // Detect scrolling direction
        let scrollingDown = offset < previousOffset

        if scrollingDown && offset < -56 {  // 56 = topbar height
            withAnimation(.spring()) {
                showSearchBar = true
            }
        } else if !scrollingDown && offset > -56 {
            withAnimation(.spring()) {
                showSearchBar = false
            }
        }

        previousOffset = offset
    }
}

// MARK: - Dummy Views (will replace later)
struct TopBar: View {
    var body: some View {
        Rectangle().fill(Color.blue.opacity(0.2))
    }
}

struct SearchBar: View {
    var body: some View {
        Rectangle().fill(Color.green.opacity(0.2))
    }
}

struct BottomBar: View {
    var body: some View {
        Rectangle().fill(Color.red.opacity(0.2))
    }
}

struct FileListPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<50) { i in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 48)
                    .overlay(Text("ITEM \(i)").foregroundColor(.gray))
            }
        }
        .padding()
    }
}

// Track scroll offset
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

