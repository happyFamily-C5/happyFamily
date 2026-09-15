import SwiftUI

struct AdminFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if currentX + subviewSize.width > containerWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, subviewSize.height)
            currentX += subviewSize.width + spacing
        }
        return CGSize(width: containerWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if currentX + subviewSize.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(subviewSize))
            lineHeight = max(lineHeight, subviewSize.height)
            currentX += subviewSize.width + spacing
        }
    }
}
