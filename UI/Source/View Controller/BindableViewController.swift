//
//  BindableViewController.swift
//  Pilot
//
//  Created by Daniel Hammond on 4/18/19.
//  Copyright © 2019 Dropbox, Inc. All rights reserved.
//

import Foundation
import Pilot
import UIKit
import RxSwift

public protocol ViewState {}

open class BindableViewController<Model: ViewState, ViewModel, View: ContainerView & UIView>: UIViewController {

    public init(
        state: Observable<Model>,
        setupView: @escaping (UIView) -> View,
        bindViewModel: @escaping (Model) -> ViewModel,
        bindView: @escaping (ViewModel, View) -> Disposable
    ) {
        self.model = state
        self.setupView = setupView
        self.viewModelBinder = bindViewModel
        self.viewBinder = bindView
        super.init(nibName: nil, bundle: nil)
    }

    private let setupView: (UIView) -> View
    private let model: Observable<Model>
    private var viewModel: Observable<ViewModel> { return model.map(viewModelBinder) }
    private let viewModelBinder: (Model) -> ViewModel
    private let viewBinder: (ViewModel, View) -> Disposable

    private var boundView: View!

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: UIViewController

    open override func viewDidLoad() {
        super.viewDidLoad()
        boundView = setupView(self.view)
        model
            .map(viewModelBinder)
            .subscribe(onNext: { [unowned self] in
                self.viewBindingBag = DisposeBag()
                self.viewBinder($0, self.boundView).disposed(by: self.viewBindingBag)
            })
            .disposed(by: disposeBag)
    }

    private var viewBindingBag = DisposeBag()
    private let disposeBag = DisposeBag()
}
