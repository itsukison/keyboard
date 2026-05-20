import SwiftUI

@main
struct BilingualKeyboardApp: App {
    @StateObject private var session = UserSession()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(session)
                .task { await session.bootstrap() }
        }
    }
}
