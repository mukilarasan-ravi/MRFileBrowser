//
//  FileGridView.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 14/12/25.
//

import Foundation
import SwiftUI

struct FileGridView: View {
    let items: [URL]
    let columnsCount: Int
    let onItemTap: (URL) -> Void

    private var itemWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let spacing: CGFloat = 12
        let totalSpacing = spacing * CGFloat(columnsCount + 1)
        return (screenWidth - totalSpacing) / CGFloat(columnsCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<rowsCount, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<columnsCount, id: \.self) { column in
                            let index = row * columnsCount + column

                            if index < items.count {
                                FileRowGridView(
                                    url: items[index],
                                    width: itemWidth,
                                    onTap: onItemTap
                                )
                            } else {
                                Spacer()
                                    .frame(width: itemWidth, height: itemWidth)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.top, 12)
        }
    }

    private var rowsCount: Int {
        (items.count + columnsCount - 1) / columnsCount
    }
}
