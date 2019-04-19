import UIKit
import RxSwift

public final class CommentView: UIView {

    public init() {
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupSubviews()
    }

    func bind(_ comment: CommentViewModel) -> Disposable {
        unbind()
        labelView.text = comment.body
        labelViewLeadingConstraint.constant = comment.isReply ? 60 : 0
        return deleteTapSubject
            .subscribe(onNext: { comment.handleDeleteButtonTap() })
    }

    func unbind() {
        disposeBag = DisposeBag()
    }

    // MARK: Private

    private func setupSubviews() {
        addSubview(labelView)
        addSubview(deleteButton)

        labelView.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false

        labelView.backgroundColor = UIColor(red: 148/255.0, green: 215/255.0, blue: 246/255.0, alpha: 1)
        labelView.textColor = .white
        labelView.layer.masksToBounds = true
        labelView.layer.cornerRadius = 4.0

        labelViewLeadingConstraint = labelView.leadingAnchor.constraint(equalTo: self.leadingAnchor)

        deleteButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            labelView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            labelView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            labelView.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor),

            deleteButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            ])
    }

    @objc
    private func deleteAction() {
        deleteTapSubject.onNext(())
    }

    private let deleteTapSubject = PublishSubject<Void>()
    private var disposeBag = DisposeBag()

    private lazy var labelView = with(UILabel()) {
        $0.textAlignment = .left
    }

    private lazy var deleteButton = with(UIButton(type: .system)) {
        $0.setTitle("🚮", for: .normal)
        $0.addTarget(self, action: #selector(deleteAction), for: .touchUpInside)
    }

    private var labelViewLeadingConstraint: NSLayoutConstraint!
}
