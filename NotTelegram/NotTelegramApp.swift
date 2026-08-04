import SwiftUI

@main
struct NotTelegramApp: App {
    var body: some Scene {
        WindowGroup {
            MessengerPrototypeView()
                .preferredColorScheme(.dark)
        }
    }
}
