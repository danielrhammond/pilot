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

public final class CollectionViewBinder<M: Diffable, VM, V: HostableView> {

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
            viewBinder: viewBinder,
            collectionView: collectionView)
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
            viewBinder: @escaping (VM, V) -> Disposable,
            collectionView: UICollectionView
        ) {
            self.viewModelBinder = viewModelBinder
            self.viewCreator = viewCreator
            self.viewBinder = viewBinder
            self.collectionView = collectionView

            super.init()

            collectionView.register(Cell.self, forCellWithReuseIdentifier: reuseId)
            collectionView.dataSource = self
            collectionView.delegate = self
        }

        private let viewModelBinder: (M) -> VM
        private let viewCreator: (VM) -> V
        private let viewBinder: (VM, V) -> Disposable
        private weak var collectionView: UICollectionView?
        private var diffEngine = DiffEngine()

        var data: [[M]] {
            get {
                switch state {
                case .synced(let data): return data
                case .animating(from: _, to: let data, pending: _): return data
                }
            }
            set {
                switch state {
                case .synced:
                    processUpdate(to: newValue)
                case .animating(from: let from, to: let to, pending: _):
                    self.state = .animating(from: from, to: to, pending: data)
                }
            }
        }

        private enum State {
            case synced([[M]])
            case animating(from: [[M]], to: [[M]], pending: [[M]]?)

            var pending: [[M]]? {
                switch self {
                case .synced: return nil
                case .animating(from: _, to: _, pending: let pending): return pending
                }
            }
        }

        private var state: State = .synced([[]]) {
            didSet {
                if case .synced = state, let pending = oldValue.pending {
                    processUpdate(to: pending)
                }
            }
        }

        private func processUpdate(to newData: [[M]]) {
            self.state = .animating(from: data, to: newData, pending: nil)
            let updates = diffEngine.update(newData)
            guard updates.hasUpdates, let collectionView = collectionView else {
                self.state = .synced(newData)
                return
            }

            // There is a long-standing `UICollectionView` bug where adding the first item or removing the last item within
            // a section can cause an internal exception. This method detects those cases and returns `true` if the update
            // should use a full data reload.
            let shouldReload =
                updates.containsFirstAddInSection ||
                updates.containsLastRemoveInSection ||
                collectionView.window == nil // TODO also handle background/foreground

            let shouldAnimate = !shouldReload // TODO configurable disable animations too

            if !shouldAnimate {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
            }

            let completionHandler: (Bool) -> Void = { [weak self] _ in
                if !shouldAnimate {
                    CATransaction.commit()
                }
                self?.state = .synced(newData)
            }

            guard !shouldReload else {
                collectionView.reloadData()
                completionHandler(true)
                return
            }

            collectionView.performBatchUpdates({
                // Note: The ordering below is important and should not change. See note in
                // `CollectionEventUpdates`

                let removedSections = updates.removedSections
                if !removedSections.isEmpty {
                    collectionView.deleteSections(IndexSet(removedSections))
                }
                let addedSections = updates.addedSections
                if !addedSections.isEmpty {
                    collectionView.insertSections(IndexSet(addedSections))
                }

                let removed = updates.removedModelPaths
                if !removed.isEmpty {
                    collectionView.deleteItems(at: removed.map { $0.indexPath })
                }
                let added = updates.addedModelPaths
                if !added.isEmpty {
                    collectionView.insertItems(at: added.map { $0.indexPath })
                }
                for move in updates.movedModelPaths {
                    collectionView.moveItem(at: move.from.indexPath, to: move.to.indexPath)
                }
            }, completion: completionHandler)

            // Note that reloads are done outside of the batch update call because they're basically unsupported
            // alongside other complicated batch updates. Because reload actually does a delete and insert under
            // the hood, the collectionview will throw an exception if that index path is touched in any other way.
            // Splitting the call out here ensures this is avoided.
            let updated = updates.updatedModelPaths
            if !updated.isEmpty {
                var indexPathsToReload: [IndexPath] = []
                updated.forEach { indexPath in
                    // TODO once cacheing is enabled to rebind instead of always reload
                    indexPathsToReload.append(indexPath.indexPath)
                }
                if !indexPathsToReload.isEmpty {
                    collectionView.reloadItems(at: indexPathsToReload)
                }
            }
        }

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
