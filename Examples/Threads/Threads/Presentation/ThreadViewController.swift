import Foundation
import Pilot
import PilotUI
import RxSwift

enum ThreadViewController {
    public static func create(
        interactor: ThreadInteractor
    ) -> BindableViewController<ThreadViewState, ThreadViewModel, ThreadView> {
        let view = ThreadView()

        let state = interactor.thread.debug("THREAD").map { ThreadViewState(entries: $0) }
        let cells = PublishSubject<[ThreadCellModel]>()

        let collectionViewBinder = CollectionViewBinder<ThreadCellModel, ThreadCellViewModel, ThreadCellView>(
            collectionView: view.collectionView,
            models: cells,
            viewModelBinder: { (model: ThreadCellModel) in
                switch model {
                case .comment(let comment):
                    return .comment(CommentViewModel(comment, actionHandler: interactor.commentViewModelActionHandler))
                case .replySummary(let summary):
                    return .replySummary(ReplySummaryViewModel(summary))
                }
            },
            viewCreator: { $0.createView() },
            viewBinder: { (viewModel, view) -> Disposable in
                switch (viewModel, view) {
                case (.comment(let vm), .comment(let v)):
                    return v.bind(vm)
                case (.replySummary(let vm), .replySummary(let v)):
                    return v.bind(vm)
                default: return Disposables.create()
                }
            })

        var capturedViewModel: ThreadViewModel?
        return BindableViewController<ThreadViewState, ThreadViewModel, ThreadView>(
            state: state,
            setupView: view.setupWithSuperview(_:),
            bindViewModel: {
                let vm =
                    capturedViewModel?.applyingState($0) ??
                    ThreadViewModel(state: $0, actionHandler: interactor.threadViewModelActionHandler)
                capturedViewModel = vm
                return vm
            },
            bindView: { (vm: ThreadViewModel, v: ThreadView) in
                v.loadingOverlay.isHidden = !vm.showLoadingIndicator
                cells.onNext(vm.entries)
                return CompositeDisposable(disposables: [
                    view.replyButtonTaps.subscribe(onNext: { vm.sendReply() }),
                    view.replyFieldText.subscribe(onNext: { vm.updateReplyFieldBody($0) }),
                    vm.replyButtonEnabled.subscribe(onNext: { v.replyButton.isEnabled = $0 }),
                    Disposables.create { _ = collectionViewBinder }
                    ])
            })
    }
}

extension ThreadInteractor {
    var threadViewModelActionHandler: (ThreadViewModel.ViewModelAction) -> Void {
        return { (action) in
            switch action {
            case .deleteComment(let id): self.deleteComment(id: id)
            case .postReply(let body): self.postComment(parentId: nil, body: body)
            }
        }
    }

    var commentViewModelActionHandler: (CommentViewModel.Action) -> Void {

        return { (action) in
            switch action {
            case .delete(let id): self.deleteComment(id: id)
            case .select(let id): self.navigate(.selectThread(id: id))
            }
        }
    }
}

public final class ThreadView: UIView, ContainerView, UITextFieldDelegate {

    public init() {
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: CollectionViewListFlowLayout())
        self.replyField = UITextField(frame: .zero)
        self.replyButton = UIButton(type: .system)
        self.loadingOverlay = UIView(frame: .zero)

        super.init(frame: .zero)

        insetsLayoutMarginsFromSafeArea = true

        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .gray

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])

        let bottomView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
        addSubview(bottomView)
        bottomView.translatesAutoresizingMaskIntoConstraints = false

        bottomView.contentView.addSubview(replyField)
        replyField.translatesAutoresizingMaskIntoConstraints = false
        replyField.backgroundColor = .white
        replyField.borderStyle = .roundedRect
        replyField.placeholder = "Reply"
        replyField.delegate = self

        bottomView.contentView.addSubview(replyButton)
        replyButton.setTitle("POST", for: .normal)
        replyButton.translatesAutoresizingMaskIntoConstraints = false
        replyButton.addTarget(self, action: #selector(replyButtonAction), for: .touchUpInside)

        replyFieldObserverHandle = NotificationCenter.default.addObserver(
            forName: UITextField.textDidChangeNotification,
            object: replyField,
            queue: nil,
            using: { [weak self] _ in self?.replyFieldChanged() })
        NotificationCenter.default.addObserver(
            forName: UIWindow.keyboardWillChangeFrameNotification,
            object: nil,
            queue: nil, using: { (notification) in
                if
                    let bounds = notification.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect,
                    let animationDuration = notification.userInfo?["UIKeyboardAnimationDurationUserInfoKey"] as? Double
                {
                    UIView.animate(withDuration: animationDuration, animations: {
                        self.replyFieldBottomConstraint.constant = -(self.bounds.height - bounds.minY)
                        self.layoutIfNeeded()
                    })
                }
                print("got kb notif: \(notification)")
            })

        replyButton.setContentHuggingPriority(.required, for: .horizontal)

        replyFieldBottomConstraint = replyField.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            bottomView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomView.topAnchor.constraint(equalTo: replyField.topAnchor, constant: -8),
            bottomView.bottomAnchor.constraint(equalTo: bottomAnchor),
            replyField.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            replyFieldBottomConstraint,
            replyField.heightAnchor.constraint(equalToConstant: 44),
            replyButton.leadingAnchor.constraint(equalTo: replyField.trailingAnchor, constant: 8),
            replyButton.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            replyButton.centerYAnchor.constraint(equalTo: replyField.centerYAnchor)
            ])

        loadingOverlay.backgroundColor = UIColor(white: 0, alpha: 0.8)
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingOverlay)

        let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        loadingOverlay.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()

        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate let collectionView: UICollectionView
    fileprivate let replyField: UITextField
    fileprivate var replyButton: UIButton

    fileprivate var replyFieldText: Observable<String> { return replyFieldTextSubject.asObservable() }
    fileprivate var replyButtonTaps: Observable<Void> { return replyButtonTapsSubject.asObservable() }
    fileprivate var loadingOverlay: UIView

    private var replyFieldBottomConstraint: NSLayoutConstraint!
    private var replyFieldObserverHandle: NSObjectProtocol?
    private let replyFieldTextSubject = PublishSubject<String>()
    private let replyButtonTapsSubject = PublishSubject<Void>()

    fileprivate func setupWithSuperview(_ superview: UIView) -> ThreadView {
        superview.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            topAnchor.constraint(equalTo: superview.topAnchor),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor),
            ])
        return self
    }

    @objc
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if replyButton.isEnabled {
            replyButtonTapsSubject.onNext(())
            textField.text = nil
        }
        return false
    }

    @objc
    private func replyFieldChanged() {
        replyFieldTextSubject.onNext(replyField.text ?? "")
    }

    @objc
    private func replyButtonAction() {
        replyButtonTapsSubject.onNext(())
        replyField.text = nil
        replyField.resignFirstResponder()
    }
}
