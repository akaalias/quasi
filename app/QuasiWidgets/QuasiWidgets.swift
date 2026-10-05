import SwiftUI
import WidgetKit

/// The iPhone's widget extension: the Live Activity drawn in PhoneShared, and the Lock Screen widgets.
@main
struct QuasiWidgets: WidgetBundle {
    var body: some Widget {
        RecorderLiveActivity()
        RecorderWidget()
    }
}
