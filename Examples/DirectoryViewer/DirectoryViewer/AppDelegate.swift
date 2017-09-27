import Cocoa
import Pilot

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: NSApplicationDelegate

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.minSize = CGSize(width: 600, height: 200)
        window.contentViewController = DirectoryViewController(
            url: FileManager.default.homeDirectoryForCurrentUser,
            context: rootContext)
    }

    // MARK: Public

    @IBOutlet public weak var window: NSWindow!

    // MARK: Private

    private let rootContext = Context()
}
