//
//  ScrollOffsetKey.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 30/11/25.
//

import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
