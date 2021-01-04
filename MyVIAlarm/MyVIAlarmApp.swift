//
//  MyVIAlarmApp.swift
//  MyVIAlarm
//
//  Created by Joel Schow on 1/4/21.
//

import SwiftUI

@main
struct MyVIAlarmApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
