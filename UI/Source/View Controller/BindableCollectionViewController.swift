//
//  BindableCollectionViewController.swift
//  Pilot
//
//  Created by Daniel Hammond on 4/19/19.
//  Copyright © 2019 Dropbox, Inc. All rights reserved.
//

import Foundation
import Pilot
import RxSwift

public protocol CollectionModel: Model {
    var collectionState: ModelCollectionState { get }
}

public protocol CollectionViewContainer: View {
    var collectionView: PlatformCollectionView { get }
}

public final class DefaultCollectionView: UIView, CollectionViewContainer {

    public init() {
        self.collectionView = UICollectionView(frame: .zero)
        super.init(frame: .zero)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public var collectionView: PlatformCollectionView

    public var viewModel: ViewModel?

    public func bindToViewModel(_ viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    public func unbindFromViewModel() {
        self.viewModel = nil
    }
}

public final class BindableCollectionViewController<M: CollectionModel, VM: ViewModel, V: CollectionViewContainer & UIView>: UIViewController {

    public init(
        model: Observable<M>,
        view: V,
        layout: UICollectionViewLayout,
        cellViewModelBinder: ViewModelBindingProvider,
        cellViewBinder: ViewBindingProvider,
        containerViewModelBinder: @escaping (M) -> VM,
        containerViewBinder: @escaping (VM, V) -> Void
    ) {
        self.boundView = view
        self.containerViewModel = model.map(containerViewModelBinder)
        self.containerViewBinder = containerViewBinder
        self.dataSource = CollectionViewModelDataSource(
            model: .empty(),
            modelBinder: DefaultViewModelBindingProvider(),
            viewBinder: BlockViewBindingProvider(binder: { (_, _) in fatalError() }),
            context: Context(),
            reuseIdProvider: DefaultCollectionViewCellReuseIdProvider())
        super.init(nibName: nil, bundle: nil)
        view.collectionView.collectionViewLayout = layout
    }

    private let dataSource: CollectionViewModelDataSource
    private let boundView: V
    private let containerViewModel: Observable<VM>
    private let containerViewBinder: (VM, V) -> Void

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: UIViewController

    public override func loadView() {
        view = boundView
        containerViewModel
            .subscribe(onNext: { [containerViewBinder, boundView] in
                containerViewBinder($0, boundView)
            })
            .disposed(by: disposeBag)
    }

    private let disposeBag = DisposeBag()
}
