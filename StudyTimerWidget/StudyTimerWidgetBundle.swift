import SwiftUI
import WidgetKit

@main
struct StudyTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        StudyTimerWidget()
        StudyStatsWidget()
    }
}
