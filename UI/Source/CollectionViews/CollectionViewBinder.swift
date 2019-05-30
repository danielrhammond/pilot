import Pilot
import UIKit
import RxSwift

private let reuseId: String = "pilot.cvb.cell-reuse-id"

public protocol HostableView {
    var view: UIView { get }
}

public protocol SelectableViewModel { // todo (: ViewModel)
    func handleSelection()
}

public final class CollectionViewBinder<M, VM, V: HostableView> {

    public init(
        collectionView: UICollectionView,
        models: Observable<[M]>,
        viewModelBinder: @escaping (M) -> VM,
        viewCreator: @escaping (VM) -> V,
        viewBinder: @escaping (VM, V) -> Disposable
        ) {
        self.models = models
        self.dataSource = CollectionViewDataSource(
            viewModelBinder: viewModelBinder,
            viewCreator: viewCreator,
            viewBinder: viewBinder)
        collectionView.register(Cell.self, forCellWithReuseIdentifier: reuseId)
        collectionView.dataSource = self.dataSource
        collectionView.delegate = self.dataSource
        models
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.dataSource.data = [$0]
                collectionView.reloadData()
            })
            .disposed(by: disposeBag)
    }

    private let disposeBag = DisposeBag()
    private let models: Observable<[M]>
    private let dataSource: CollectionViewDataSource

    private final class CollectionViewDataSource: NSObject, UICollectionViewDelegate, UICollectionViewDataSource {

        init(
            viewModelBinder: @escaping (M) -> VM,
            viewCreator: @escaping (VM) -> V,
            viewBinder: @escaping (VM, V) -> Disposable
            ) {
            self.viewModelBinder = viewModelBinder
            self.viewCreator = viewCreator
            self.viewBinder = viewBinder
        }

        private let viewModelBinder: (M) -> VM
        private let viewCreator: (VM) -> V
        private let viewBinder: (VM, V) -> Disposable

        var data = [[M]]()

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return data.count
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return data[section].count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseId, for: indexPath)
            if let hostCell = cell as? Cell {
                let model = data[indexPath.section][indexPath.item]
                let viewModel = viewModelBinder(model) // todo cache
                let view = viewCreator(viewModel) // todo reuse
                hostCell.hostedView = view
                viewBinder(viewModel, view).disposed(by: hostCell.disposeBag)
            }
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let model = data[indexPath.section][indexPath.item]
            if let viewModel = viewModelBinder(model) as? SelectableViewModel {
                viewModel.handleSelection()
            }
        }
    }

    private final class Cell: UICollectionViewCell {

        fileprivate var disposeBag = DisposeBag()

        fileprivate var hostedView: V? {
            didSet {
                disposeBag = DisposeBag()
                if let oldView = oldValue {
                    oldView.view.removeFromSuperview()
                }
                if let newView = hostedView?.view {
                    addSubview(newView)
                    newView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        newView.topAnchor.constraint(equalTo: topAnchor),
                        newView.leadingAnchor.constraint(equalTo: leadingAnchor),
                        newView.bottomAnchor.constraint(equalTo: bottomAnchor),
                        newView.trailingAnchor.constraint(equalTo: trailingAnchor),
                        ])
                }
            }
        }
    }
}
