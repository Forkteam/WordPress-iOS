import Foundation
import UIKit
import CoreData

typealias DashboardSnapshot = NSDiffableDataSourceSnapshot<DashboardCardSection, DashboardCardModel>
typealias DashboardDataSource = UICollectionViewDiffableDataSource<DashboardCardSection, DashboardCardModel>

class BlogDashboardViewModel {
    private weak var viewController: BlogDashboardViewController?

    private let managedObjectContext: NSManagedObjectContext

    var blog: Blog

    private lazy var service: BlogDashboardService = {
        return BlogDashboardService(managedObjectContext: managedObjectContext)
    }()

    private lazy var dataSource: DashboardDataSource? = {
        guard let viewController = viewController else {
            return nil
        }

        return DashboardDataSource(collectionView: viewController.collectionView) { [unowned self] collectionView, indexPath, identifier in

            let cellType = identifier.id.cell
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellType.defaultReuseID, for: indexPath)

            if let cellConfigurable = cell as? BlogDashboardCardConfigurable {
                cellConfigurable.configure(blog: blog, viewController: viewController, apiResponse: identifier.apiResponse)
            }

            return cell

        }
    }()

    init(viewController: BlogDashboardViewController, managedObjectContext: NSManagedObjectContext = ContextManager.shared.mainContext, blog: Blog) {
        self.viewController = viewController
        self.managedObjectContext = managedObjectContext
        self.blog = blog
    }

    /// Apply the initial configuration when the view loaded
    func viewDidLoad() {
        loadCardsFromCache()
    }

    /// Call the API to return cards for the current blog
    func loadCards(completion: (() -> Void)? = nil) {
        viewController?.showLoading()

        service.fetch(blog: blog, completion: { [weak self] snapshot in
            self?.viewController?.stopLoading()
            self?.apply(snapshot: snapshot)
            completion?()
        }, failure: { [weak self] snapshot in
            self?.viewController?.stopLoading()
            self?.loadingFailure()

            if let snapshot = snapshot {
                self?.apply(snapshot: snapshot)
            }

            completion?()
        })
    }

    func loadCardsFromCache() {
        let snapshot = service.fetchLocal(blog: blog)
        apply(snapshot: snapshot)
    }

    func card(for sectionIndex: Int) -> DashboardCard? {
        dataSource?.itemIdentifier(for: IndexPath(row: 0, section: sectionIndex))?.id
    }
}

// MARK: - Private methods

private extension BlogDashboardViewModel {

    func apply(snapshot: DashboardSnapshot) {
        let scrollView = viewController?.mySiteScrollView
        let position = scrollView?.contentOffset

        dataSource?.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let scrollView = scrollView, let position = position else {
                return
            }

            self?.scroll(scrollView, to: position)
        }
    }

    func scroll(_ scrollView: UIScrollView, to position: CGPoint) {
        if position.y > 0 {
            scrollView.setContentOffset(position, animated: false)
        }
    }
}

// MARK: - Ghost/Skeleton cards and failures

private extension BlogDashboardViewModel {

    func isGhostCardsBeingShown() -> Bool {
        dataSource?.snapshot().sectionIdentifiers.filter { $0.id == .ghost }.count == 1
    }

    func loadingFailure() {
        if blog.dashboardState.hasCachedData {
            viewController?.loadingFailure()
        }
    }
}
