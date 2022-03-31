import Foundation

/// Methods used by the Reader in the Follow Conversation flow to:
/// - subscribe to post comments
/// - subscribe to in-app notifications

@objc protocol ReaderCommentsFollowPresenterDelegate: AnyObject {
    func followConversationComplete(success: Bool, post: ReaderPost)
    func toggleNotificationComplete(success: Bool, post: ReaderPost)
}

class ReaderCommentsFollowPresenter: NSObject {

    // MARK: - Properties

    private let post: ReaderPost
    private weak var delegate: ReaderCommentsFollowPresenterDelegate?
    private let presentingViewController: UIViewController
    private let followCommentsService: FollowCommentsService?

    // MARK: - Initialization

    @objc required init(post: ReaderPost,
                        delegate: ReaderCommentsFollowPresenterDelegate? = nil,
                        presentingViewController: UIViewController) {
        self.post = post
        self.delegate = delegate
        self.presentingViewController = presentingViewController
        followCommentsService = FollowCommentsService.createService(with: post)
    }

    // MARK: - Subscriptions

    /// Toggles the state of conversation subscription.
    /// When enabled, the user will receive emails for new comments.
    ///
    @objc func handleFollowConversationButtonTapped() {
        trackFollowToggled()

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()

        let oldIsSubscribed = post.isSubscribedComments
        let newIsSubscribed = !oldIsSubscribed

        // Define success block
        let successBlock = { [weak self] (taskSucceeded: Bool) in
            guard taskSucceeded else {
                DispatchQueue.main.async {
                    generator.notificationOccurred(.error)
                    let noticeTitle = newIsSubscribed ? Messages.followFail : Messages.unfollowFail
                    self?.presentingViewController.displayNotice(title: noticeTitle)
                    self?.informDelegateFollowComplete(success: false)
                }
                return
            }

            DispatchQueue.main.async {
                generator.notificationOccurred(.success)
                self?.informDelegateFollowComplete(success: true)

                guard newIsSubscribed else {
                    let noticeTitle = newIsSubscribed ? Messages.followSuccess : Messages.unfollowSuccess
                    self?.presentingViewController.displayNotice(title: noticeTitle)
                    return
                }

                // Show notice with Enable option.
                self?.presentingViewController.displayActionableNotice(title: Messages.promptTitle,
                                                                       message: Messages.promptMessage,
                                                                       actionTitle: Messages.enableActionTitle,
                                                                       actionHandler: { (accepted: Bool) in
                    self?.handleNotificationsButtonTapped(canUndo: true)
                })
            }
        }

        // Define failure block
        let failureBlock = { [weak self] (error: Error?) in
            DDLogError("Reader Comments: error toggling subscription status: \(String(describing: error))")

            DispatchQueue.main.async {
                generator.notificationOccurred(.error)
                let noticeTitle = newIsSubscribed ? Messages.subscribeFail : Messages.unsubscribeFail
                self?.presentingViewController.displayNotice(title: noticeTitle)
                self?.informDelegateFollowComplete(success: false)
            }
        }

        // Call the service to toggle the subscription status
        followCommentsService?.toggleSubscribed(oldIsSubscribed, success: successBlock, failure: failureBlock)
    }

    /// Toggles the state of comment subscription notifications.
    /// When enabled, the user will receive in-app notifications for new comments.
    ///
    /// - Parameter canUndo: Boolean. When true, this provides a way for the user to revert their actions.
    /// - Parameter completion: Block called as soon the view controller has been removed.
    ///
    @objc func handleNotificationsButtonTapped(canUndo: Bool, completion: ((Bool) -> Void)? = nil) {
        trackNotificationsToggled()

        let desiredState = !self.post.receivesCommentNotifications
        let action: PostSubscriptionAction = desiredState ? .enableNotification : .disableNotification

        followCommentsService?.toggleNotificationSettings(desiredState, success: { [weak self] in
            completion?(true)
            self?.informDelegateNotificationComplete(success: true)

            guard let self = self else {
                return
            }

            guard canUndo else {
                let title = self.noticeTitle(forAction: action, success: true)
                self.presentingViewController.displayNotice(title: title)
                return
            }

            let title = self.noticeTitle(forAction: action, success: true)

            self.presentingViewController.displayActionableNotice(title: title,
                                                                  actionTitle: Messages.undoActionTitle,
                                                                  actionHandler: { (accepted: Bool) in
                self.handleNotificationsButtonTapped(canUndo: false)
            })
        }, failure: { [weak self] error in
            DDLogError("Reader Comments: error toggling notification status: \(String(describing: error)))")
            let title = self?.noticeTitle(forAction: action, success: false) ?? ""
            self?.presentingViewController.displayNotice(title: title)
            completion?(false)
            self?.informDelegateNotificationComplete(success: false)
        })
    }

    // MARK: - Notification Sheet

    @objc func showNotificationSheet(sourceBarButtonItem: UIBarButtonItem?) {
        showBottomSheet(sourceBarButtonItem: sourceBarButtonItem)
    }

    func showNotificationSheet(sourceView: UIView?) {
        showBottomSheet(sourceView: sourceView)
    }

}

// MARK: - Private Extension

private extension ReaderCommentsFollowPresenter {

    func showBottomSheet(sourceView: UIView? = nil, sourceBarButtonItem: UIBarButtonItem? = nil) {
        let sheetViewController = ReaderCommentsNotificationSheetViewController(isNotificationEnabled: post.receivesCommentNotifications, delegate: self)
        let bottomSheet = BottomSheetViewController(childViewController: sheetViewController)
        bottomSheet.show(from: presentingViewController, sourceView: sourceView, sourceBarButtonItem: sourceBarButtonItem)
    }

    func informDelegateFollowComplete(success: Bool) {
        delegate?.followConversationComplete(success: success, post: post)
    }

    func informDelegateNotificationComplete(success: Bool) {
        delegate?.toggleNotificationComplete(success: success, post: post)
    }

    struct Messages {
        // Follow Conversation
        static let followSuccess = NSLocalizedString("Successfully followed conversation", comment: "The app successfully subscribed to the comments for the post")
        static let unfollowSuccess = NSLocalizedString("Successfully unfollowed conversation", comment: "The app successfully unsubscribed from the comments for the post")
        static let followFail = NSLocalizedString("Unable to follow conversation", comment: "The app failed to subscribe to the comments for the post")
        static let unfollowFail = NSLocalizedString("Failed to unfollow conversation", comment: "The app failed to unsubscribe from the comments for the post")

        // Subscribe to Comments
        static let subscribeFail = NSLocalizedString("Could not subscribe to comments", comment: "The app failed to subscribe to the comments for the post")
        static let unsubscribeFail = NSLocalizedString("Could not unsubscribe from comments", comment: "The app failed to unsubscribe from the comments for the post")

        // In-app notifications prompt
        static let promptTitle = NSLocalizedString("Following this conversation", comment: "The app successfully subscribed to the comments for the post")
        static let promptMessage = NSLocalizedString("Enable in-app notifications?", comment: "Hint for the action button that enables notification for new comments")
        static let enableActionTitle = NSLocalizedString("Enable", comment: "Button title to enable notifications for new comments")
        static let undoActionTitle = NSLocalizedString("Undo", comment: "Button title. Reverts the previous notification operation")
    }

    /// Enumerates the kind of actions available in relation to post subscriptions.
    /// TODO: Add `followConversation` and `unfollowConversation` once the "Follow Conversation" feature flag is removed.
    enum PostSubscriptionAction: Int {
        case enableNotification
        case disableNotification
    }

    func noticeTitle(forAction action: PostSubscriptionAction, success: Bool) -> String {
        switch (action, success) {
        case (.enableNotification, true):
            return NSLocalizedString("In-app notifications enabled", comment: "The app successfully enabled notifications for the subscription")
        case (.enableNotification, false):
            return NSLocalizedString("Could not enable notifications", comment: "The app failed to enable notifications for the subscription")
        case (.disableNotification, true):
            return NSLocalizedString("In-app notifications disabled", comment: "The app successfully disabled notifications for the subscription")
        case (.disableNotification, false):
            return NSLocalizedString("Could not disable notifications", comment: "The app failed to disable notifications for the subscription")
        }
    }

    // MARK: - Tracks

    func trackFollowToggled() {
        var properties = [String: Any]()
        let followAction: FollowAction = !post.isSubscribedComments ? .followed : .unfollowed
        properties[WPAppAnalyticsKeyFollowAction] = followAction.rawValue
        properties[WPAppAnalyticsKeyBlogID] = post.siteID
        properties[WPAppAnalyticsKeySource] = sourceForTracks()
        WPAnalytics.trackReader(.readerToggleFollowConversation, properties: properties)
    }

    func trackNotificationsToggled() {
        var properties = [String: Any]()
        properties[AnalyticsKeys.notificationsEnabled] = !post.receivesCommentNotifications
        properties[WPAppAnalyticsKeyBlogID] = post.siteID
        properties[WPAppAnalyticsKeySource] = sourceForTracks()
        WPAnalytics.trackReader(.readerToggleCommentNotifications, properties: properties)
    }

    func sourceForTracks() -> String {
        if presentingViewController is ReaderCommentsViewController {
            return AnalyticsSource.comments.description()
        }

        if presentingViewController is ReaderDetailViewController {
            return AnalyticsSource.postDetails.description()
        }

        return AnalyticsSource.unknown.description()
    }

    enum FollowAction: String {
        case followed
        case unfollowed
    }

    private struct AnalyticsKeys {
        static let notificationsEnabled = "notifications_enabled"
    }

    private enum AnalyticsSource: String {
        case comments
        case postDetails
        case unknown

        func description() -> String {
            switch self {
            case .comments:
                return "reader_threaded_comments"
            case .postDetails:
                return "reader_post_details_comments"
            case .unknown:
                return "unknown"
            }
        }
    }

}

// MARK: - ReaderCommentsNotificationSheetDelegate Methods

extension ReaderCommentsFollowPresenter: ReaderCommentsNotificationSheetDelegate {

    func didToggleNotificationSwitch(_ isOn: Bool, completion: @escaping (Bool) -> Void) {
        handleNotificationsButtonTapped(canUndo: false, completion: completion)
    }

    func didTapUnfollowConversation() {
        handleFollowConversationButtonTapped()
    }

}
