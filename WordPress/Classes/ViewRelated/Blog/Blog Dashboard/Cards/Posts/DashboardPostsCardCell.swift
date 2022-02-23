import UIKit

/// A cell that can display 4 different types of cards:
/// * Write your first post
/// * Write our next post
/// * Show your latest drafts
/// * Show the upcoming scheduled posts
///
/// This cell uses PostsCardViewController to display the list of posts
///
/// One important thing to keep in mind is that we take into account what
/// comes from the API but we rely on local data to decide which card to show.
///
/// Eg.: The API might return that the user has no posts at all but
/// they actually have a draft saved locally. In this case we show the drafts.
class DashboardPostsCardCell: UICollectionViewCell, Reusable {
    private var cardFrameView: BlogDashboardCardFrameView?

    /// The VC presenting this cell
    private weak var viewController: UIViewController?

    private var blog: Blog?

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = Constants.spacing
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(stackView)
        contentView.pinSubviewToAllEdges(stackView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DashboardPostsCardCell: BlogDashboardCardConfigurable {
    func configure(blog: Blog, viewController: BlogDashboardViewController?, apiResponse: BlogDashboardRemoteEntity?) {
        guard let viewController = viewController, let apiResponse = apiResponse else {
            return
        }

        self.viewController = viewController
        self.blog = blog

        let hasDrafts = (apiResponse.posts?.draft?.count ?? 0) > 0
        let hasScheduled = (apiResponse.posts?.scheduled?.count ?? 0) > 0
        let hasPublished = apiResponse.posts?.hasPublished ?? true

        clearFrames()

        if !hasDrafts && !hasScheduled {
            showCard(for: blog, status: .draft, to: viewController,
                     hasPublishedPosts: hasPublished, hidesHeader: true, shouldSync: false)
        } else {
            if hasDrafts {
                showCard(for: blog, status: .draft, to: viewController,
                         hasPublishedPosts: hasPublished)
            }

            if hasScheduled {
                showCard(for: blog, status: .scheduled, to: viewController,
                         hasPublishedPosts: hasPublished)
            }
        }
    }

    /// Remove any card frame, if present
    private func clearFrames() {
        stackView.removeAllSubviews()
    }

    /// Embed the post list into a "card frame" and display it
    private func showCard(for blog: Blog, status: BasePost.Status, to viewController: UIViewController, hasPublishedPosts: Bool, hidesHeader: Bool = false, shouldSync: Bool = true) {
        // Get the VC to present posts
        let childViewController = createOrDequeueVC(blog: blog,
                                                    status: status,
                                                    hasPublishedPosts: hasPublishedPosts,
                                                    shouldSync: shouldSync)
        childViewController.delegate = self

        // Create the card frame and configure
        let frame = BlogDashboardCardFrameView()
        frame.title = status == .draft ? Strings.draftsTitle : Strings.scheduledTitle
        frame.icon = UIImage.gridicon(.posts, size: Constants.iconSize)

        if hidesHeader {
            frame.hideHeader()
        }

        frame.onHeaderTap = { [weak self] in
            self?.presentPostList(with: status)
        }

        // Add the VC to the card frame and configure as a child VC
        frame.add(subview: childViewController.view)

        viewController.addChild(childViewController)
        stackView.addArrangedSubview(frame)
        childViewController.didMove(toParent: viewController)

        self.cardFrameView = frame
    }

    /// Creates a new PostsCardViewController or dequeue an existing
    /// for optimal performance
    private func createOrDequeueVC(blog: Blog, status: BasePost.Status, hasPublishedPosts: Bool, shouldSync: Bool) -> PostsCardViewController {
        // Try to find an already existing PostsCardViewController
        // (that is not being displayed here)
        if let dequeuedViewController = viewController?.children
            .first(where: {
                $0 is PostsCardViewController
                && cardFrameView?.currentView != $0.view
            }) as? PostsCardViewController {
            dequeuedViewController.update(blog: blog, status: status,
                                          hasPublishedPosts: hasPublishedPosts, shouldSync: shouldSync)
            return dequeuedViewController
        } else {
            return PostsCardViewController(blog: blog, status: status,
                                           hasPublishedPosts: hasPublishedPosts, shouldSync: shouldSync)
        }
    }

    private func presentPostList(with status: BasePost.Status) {
        guard let blog = blog, let viewController = viewController else {
            return
        }

        PostListViewController.showForBlog(blog, from: viewController, withPostStatus: status)
    }

    private enum Strings {
        static let draftsTitle = NSLocalizedString("Work on a draft post", comment: "Title for the card displaying draft posts.")
        static let scheduledTitle = NSLocalizedString("Upcoming scheduled posts", comment: "Title for the card displaying upcoming scheduled posts.")
    }

    private enum Constants {
        static let spacing: CGFloat = 20
        static let iconSize = CGSize(width: 18, height: 18)
    }
}

extension DashboardPostsCardCell: PostsCardViewControllerDelegate {
    func didShowNextPostPrompt() {
        cardFrameView?.hideHeader()
    }

    func didHideNextPostPrompt() {
        cardFrameView?.showHeader()
    }
}
