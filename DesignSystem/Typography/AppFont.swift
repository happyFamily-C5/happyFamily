//
//  AppFont.swift
//  happyFamily
//
//  Created by Codex on 27/08/26.
//

import SwiftUI

enum AppFont {
    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    static let title = Font.system(.title, design: .default, weight: .bold)
    static let title2 = Font.system(.title2, design: .default, weight: .semibold)
    static let title3 = Font.system(.title3, design: .default, weight: .semibold)
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let bodyEmphasized = Font.system(.body, design: .default, weight: .semibold)
    static let callout = Font.system(.callout, design: .default, weight: .regular)
    static let footnote = Font.system(.footnote, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let captionEmphasized = Font.system(.caption, design: .default, weight: .semibold)
    static let caption2 = Font.system(.caption2, design: .default, weight: .regular)

    static let screenTitle = title
    static let organizerTitle = headline
    static let sectionTitle = headline
    static let cardTitle = bodyEmphasized
    static let primaryAction = headline
    static let secondaryAction = bodyEmphasized
    static let fieldLabel = subheadline
    static let fieldValue = body
    static let supportingText = footnote
    static let metadata = caption

    static func system(
        _ style: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        Font.system(style, design: design, weight: weight)
    }
}
