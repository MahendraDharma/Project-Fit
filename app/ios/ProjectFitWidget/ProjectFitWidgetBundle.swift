//
//  ProjectFitWidgetBundle.swift
//  ProjectFitWidget
//
//  Created by Abdul Sahil - garden on 12/06/26.
//

import WidgetKit
import SwiftUI

@main
struct ProjectFitWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProjectFitWidget()
        ProjectFitSleepWidget()
        ProjectFitOvernightWidget()
        ProjectFitBatteryWidget()
        ProjectFitWidgetLiveActivity()
        ProjectFitBreathingLiveActivity()
    }
}
