import SwiftUI

// MARK: - Countdown ring
//
// The ring depletes: a full circle when the phase begins, empty when it is
// spent. Geometry follows the design's SVG — the box is the outer square and
// the stroke centreline sits `inset` in from its edge.

struct TimerRing: View {
    let fraction: Double
    let tint: Color
    let track: Color
    var lineWidth: CGFloat = 7
    var inset: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .inset(by: inset)
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .inset(by: inset)
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Round dots

struct RoundDots: View {
    let total: Int
    let isFilled: (Int) -> Bool
    let tint: Color
    var size: CGFloat = 7
    var spacing: CGFloat = 5
    var emptyTint: Color = .primary.opacity(0.2)

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Circle()
                    .fill(isFilled(index) ? tint : emptyTint)
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Session timeline
//
// Alternating study and break blocks, study three times the width of a break,
// filled left to right as the session is worked through.

struct TimelineBar: View {
    struct Segment {
        let isStudy: Bool
        let minutes: Int
        let isFilled: Bool
    }

    let segments: [Segment]
    let palette: Palette
    var showsLabels: Bool = true
    var height: CGFloat = 22

    private let gap: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let weights = segments.map { $0.isStudy ? 3.0 : 1.0 }
            let unit = max(0, (geometry.size.width - gap * CGFloat(max(segments.count - 1, 0)))
                / CGFloat(weights.reduce(0, +)))

            HStack(spacing: gap) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    let width = unit * (segment.isStudy ? 3 : 1)
                    block(segment, at: index, width: width)
                        .frame(width: width)
                }
            }
        }
        .frame(height: height)
    }

    private func block(_ segment: Segment, at index: Int, width: CGFloat) -> some View {
        let fill = segment.isStudy ? palette.study : palette.rest
        let unfilled = segment.isStudy ? palette.studyTrack : palette.restTrack

        return ZStack {
            shape(at: index).fill(segment.isFilled ? fill : unfilled)
            if showsLabels, width >= 26 {
                Text("\(segment.minutes)m")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    /// Rounded on the outer ends of the run, squared off in between.
    private func shape(at index: Int) -> UnevenRoundedRectangle {
        let outer: CGFloat = 5
        let inner: CGFloat = 2
        return UnevenRoundedRectangle(
            topLeadingRadius: index == 0 ? outer : inner,
            bottomLeadingRadius: index == 0 ? outer : inner,
            bottomTrailingRadius: index == segments.count - 1 ? outer : inner,
            topTrailingRadius: index == segments.count - 1 ? outer : inner
        )
    }
}

// MARK: - Small shared labels

/// The letter-spaced all-caps phase label used above and below the ring.
struct PhaseCaption: View {
    let text: String
    var size: CGFloat = 9.5
    var opacity: Double = 0.5

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(.primary.opacity(opacity))
    }
}

/// A stat pair — big tabular number over a small caption.
struct StatBlock: View {
    let value: String
    let caption: String
    var valueSize: CGFloat = 13
    var captionSize: CGFloat = 9.5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: valueSize, weight: .semibold))
                .monospacedDigit()
            Text(caption)
                .font(.system(size: captionSize))
                .tracking(0.3)
                .foregroundStyle(.primary.opacity(0.4))
        }
    }
}
