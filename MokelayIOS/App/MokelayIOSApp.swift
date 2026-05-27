import SwiftUI

@main
struct MokelayIOSApp: App {
    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    private var rootView: some View {
        let view = NavigationView {
            PageScreen(uuid: "index")
        }

        #if os(iOS)
        return view.navigationViewStyle(.stack)
        #else
        return view
        #endif
    }
}
