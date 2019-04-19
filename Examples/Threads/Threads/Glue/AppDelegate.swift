import UIKit
import Pilot
import PilotUI
import RxSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: viewControllerForThread("root"))
        window?.makeKeyAndVisible()
        return true
    }

    private func viewControllerForThread(_ id: String) -> UIViewController {
        let service = LocalOnlyService()
        let repository = ThreadRepositoryImpl(client: service)
        let user = User(username: "cmdrbanana")
        let interactor = ThreadInteractorImpl(threadId: id, repository: repository, currentUser: user, navigationHandler: {
            [weak self] action in
            switch action {
            case .selectThread(let id): self?.handleNavigationToThread(id)
            }
        })
        return ThreadViewController.create(interactor: interactor)
    }

    private func handleNavigationToThread(_ id: String) {
        guard let navigationController = window?.rootViewController as? UINavigationController else { return }
        navigationController.pushViewController(viewControllerForThread(id), animated: true)
    }
}
