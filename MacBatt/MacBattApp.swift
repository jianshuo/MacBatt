import SwiftUI

@main
struct MacBattApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .frame(width: 500, height: 780)
        } label: {
            Image(systemName: "battery.100percent.bolt")
        }
        .menuBarExtraStyle(.window)
    }
}
