import SwiftUI

/// Lays children out left to right and wraps to a new line when the next one won't
/// fit — what an `HStack` would do if it could wrap.
///
/// Used anywhere a run of small pieces has to survive a long title or an
/// accessibility text size: the celebration's letter-by-letter title, chip rows,
/// stat pills, genre tags.
public struct FlowLayout: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat
    public var alignment: HorizontalAlignment

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8,
                alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    public func sizeThatFits(proposal: ProposedViewSize,
                             subviews: Subviews,
                             cache: inout ()) -> CGSize {
        // SwiftUI asks with an unspecified width to learn a view's *ideal* size, and
        // a parent stack adopts the widest ideal it gets back. Answering "every chip
        // on one line" there makes the whole page wider than the screen, which shows
        // up as the entire layout drifting left. So an unspecified proposal reports
        // the narrowest width this can actually lay out in — one subview wide.
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        guard let proposed = proposal.width, proposed > 0, proposed < .infinity else {
            return CGSize(width: widest, height: height(of: layout(subviews: subviews, maxWidth: widest)))
        }
        let rows = layout(subviews: subviews, maxWidth: proposed)
        return CGSize(width: min(proposed, max(widest, rows.map(\.width).max() ?? 0)),
                      height: height(of: rows))
    }

    private func height(of rows: [Row]) -> CGFloat {
        rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
    }

    public func placeSubviews(in bounds: CGRect,
                              proposal: ProposedViewSize,
                              subviews: Subviews,
                              cache: inout ()) {
        let rows = layout(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x: CGFloat
            switch alignment {
            case .center: x = bounds.minX + (bounds.width - row.width) / 2
            case .trailing: x = bounds.maxX - row.width
            default: x = bounds.minX
            }
            for index in row.indices {
                let size = measure(subviews[index], within: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    /// Never let a child claim more width than the row has. A chip whose text is
    /// longer than the screen should wrap inside itself, not overflow the gutter —
    /// which is exactly what happens at accessibility text sizes.
    private func measure(_ subview: LayoutSubview, within maxWidth: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard natural.width > maxWidth, maxWidth > 0 else { return natural }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layout(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = measure(subviews[index], within: maxWidth)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty, needed > maxWidth {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
