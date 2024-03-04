//
//  skincancerApp.swift
//  skincancer
//
//  Created by Beyzanur Okudan on 7.06.2023.
//

import SwiftUI

@main
struct skincancerApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                // Fallback on earlier versions
            }
        }
    }
}
