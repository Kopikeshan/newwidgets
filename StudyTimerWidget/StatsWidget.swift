import SwiftUI
import WidgetKit

/// The second small widget from design 1a — the one that sits beside the timer
/// face and just answers "how much have I done today".
struct StudyStatsWidget: Widget {
    let kind = "StudyStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionProvider()) { entry in
            StudyStatsWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Study Today")
        .description("Time studied today and your current streak.")
        .supportedFamilies([.systemSmall])
    }
}

struct StudyStatsWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: SessionEntry

    private var palette: Palette { .of(scheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(.primary.opacity(0.4))

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.state.todayText(at: entry.date))
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-1.2)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("studied")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.45))
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(.primary.opacity(0.1))
                    .frame(height: 0.5)
                HStack(spacing: 6) {
                    Circle()
                        .fill(palette.rest)
                        .frame(width: 5, height: 5)
                    Text("\(entry.state.streakText) day streak")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                .padding(.top, 11)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
