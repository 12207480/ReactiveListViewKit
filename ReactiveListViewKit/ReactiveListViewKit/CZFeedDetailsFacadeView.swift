//
//  CZFeedDetailsFacadeView.swift
//  ReactiveListViewKit
//
//  Created by Cheng Zhang on 1/9/17.
//  Copyright © 2017 Cheng Zhang. All rights reserved.
//

import UIKit

private var kViewModelObserverContext: Int = 0

/// Elegant facade class encapsulating UIStackView for non-reusable cells
@objc open class CZFeedDetailsFacadeView: UIView {
    var onEvent: OnEvent?
    var viewModel: CZFeedDetailsViewModel {
        return _viewModel
    }
    var _viewModel: CZFeedDetailsViewModel!
    fileprivate lazy var prevViewModel: CZFeedDetailsViewModel = CZFeedDetailsViewModel()
    public var collectionView: UICollectionView!
    fileprivate var stackView: UIStackView!
    fileprivate var scrollView: UIScrollView?
    fileprivate var onScrollView: Bool = true
    // CZFeedCellViewable can be UIViewController or UIView
    public lazy var components: [CZFeedCellViewable] = []
    var containerViewController: UIViewController?
    fileprivate var hasSetup = false

    public init(containerViewController: UIViewController? = nil, onEvent: OnEvent? = nil, onScrollView: Bool = true) {
        self.onScrollView = onScrollView
        super.init(frame: .zero)
        self.containerViewController = containerViewController
        self.onEvent = onEvent
        setup()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public func batchUpdate(with feedModels: [CZFeedModelable]) {
        guard let _ = try? checkDuplicatediffId(in: feedModels) else {
            assertionFailure("Should not have duplicate diffId for each section.")
            return
        }
        viewModel.batchUpdate(with: feedModels)
        reloadListView()
    }

    public func listenToEvents(_ onEvent: @escaping OnEvent) {
        self.onEvent = onEvent
    }

    func setup() {
        guard !hasSetup else {return}
        hasSetup = true
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        _viewModel = CZFeedDetailsViewModel()
        setupContentView()
    }

    public func reloadListView() {
        let diffResult: [CZListDiff.ResultKey: [CZFeedDetailsModel]] = CZListDiff.diffFeedModels(current: viewModel.feedModels,
                                                                                                    prev: prevViewModel.feedModels)

        // deleted
        if let removedItemModels = diffResult[.deleted] {
        removedItemModels.forEach { itemModel in
            let cachedComponent = components.first { $0.diffId == itemModel.viewModel.diffId }
            switch cachedComponent {
            case let cachedComponent as UIViewController:
                cachedComponent.removeFromParentViewController()
                cachedComponent.view.removeFromSuperview()
                cachedComponent.didMove(toParentViewController: nil)
            case let cachedComponent as UIView:
                cachedComponent.removeFromSuperview()
            default:
                break
            }
            components = components.filter{ $0.diffId != cachedComponent?.diffId }
        }
        }

        // unchanged
        let unchangedItemModels = diffResult[.unchanged]

        // updated
        if let updatedItemModels = diffResult[.updated] {
            updatedItemModels.forEach { itemModel in
                guard let cachedComponent = components.first(where: {$0.diffId == itemModel.viewModel.diffId}) else {
                    assertionFailure("Updated item should have been cached in `components`.")
                    return
                }
                cachedComponent.config(with: itemModel.viewModel)
            }
        }

        // inserted
        if let insertedItemModels = diffResult[.inserted] {
            if insertedItemModels.count > 0 {
                // The remaining components in stackView should be `updated`, according to nature of number,
                // it's safe to insert component at i to stackView exactly as the order in newViewModel without exception
                let insertedSet = Set<CZFeedDetailsModel>(insertedItemModels)
                viewModel.feedModels.filter({insertedSet.contains($0)}).forEach { model in
                    guard let i = viewModel.feedModels.index(of: model) else {return}
                    let itemComponent = model.viewClass.init(viewModel: model.viewModel, onEvent: onEvent)
                    if let containerViewController = containerViewController,
                        let itemViewController = itemComponent as? UIViewController {
                        // Component is UIViewController
                        containerViewController.addChildViewController(itemViewController)
                        stackView.insertArrangedSubview(itemViewController.view!, at: i)
                        itemViewController.didMove(toParentViewController: containerViewController)
                    } else if let itemView = itemComponent as? UIView {
                        // Component is UIView
                        stackView.insertArrangedSubview(itemView, at: i)
                    } else {
                        assertionFailure("\(itemComponent) is invalid Component type.")
                    }
                    components.append(itemComponent)
                }
            }
        }
        prevViewModel = viewModel.copy() as! CZFeedDetailsViewModel
    }
}

// MARK: - Private methods
fileprivate extension CZFeedDetailsFacadeView  {
    struct Constants {
        static let stackViewBottomMargin: CGFloat = 12
        static let stackViewSpacing: CGFloat = 12
    }
    enum DuplicatediffIdError: Error {
        case regular
        case custom(reason: String)
    }
    @discardableResult
    func checkDuplicatediffId(in componentModels: [CZFeedModelable]) throws ->  Bool  {
        var mapper: [String: [CZFeedModelable]] = [:]
        componentModels.forEach {
            let diffId = $0.viewModel.diffId
            mapper[diffId] = mapper[diffId] ?? []
            mapper[diffId]!.append($0)
        }
        for (key, value) in mapper {
            if value.count > 1 {
                let reason = "Duplicate values found in the same key '\(key)'."
                assertionFailure("diffId should be unique for each section. \n Reason: \(reason)")
                throw(DuplicatediffIdError.custom(reason: reason))
            }
        }
        return false
    }

    func setupContentView() {
        let rootView: UIView
        if (onScrollView) {
            scrollView = UIScrollView(frame: .zero)
            scrollView?.isDirectionalLockEnabled = true
            scrollView?.overlayOnSuperview(self)
            rootView = scrollView!
        } else {
            rootView = self
        }

        stackView = UIStackView(frame: .zero)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.layoutMargins = UIEdgeInsetsMake(0, 0, Constants.stackViewBottomMargin, 0)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.spacing = Constants.stackViewSpacing

        rootView.addSubview(stackView)
        // stackView's leading/trailing anchor should stick to parentView, instead of scrollView to avoid layout issue. e.g. trailing inset
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: rootView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
            ])
    }
}


