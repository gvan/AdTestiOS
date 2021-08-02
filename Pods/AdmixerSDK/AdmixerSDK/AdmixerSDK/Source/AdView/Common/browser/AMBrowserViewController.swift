//
//  AMBrowserViewController.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
import WebKit
import StoreKit

class AMBrowserViewController: UIViewController, UIActionSheetDelegate, SKStoreProductViewControllerDelegate, WKNavigationDelegate, WKUIDelegate {
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var forwardButton: UIBarButtonItem!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var okButton: UIBarButtonItem!
    @IBOutlet weak var openInButton: UIBarButtonItem!
    @IBOutlet var refreshButton: UIBarButtonItem!
    @IBOutlet weak var webViewContainerView: UIView!
    @IBOutlet weak var containerViewSuperviewTopConstraint: NSLayoutConstraint!

        var delegate: AMBrowserViewControllerDelegate?

        @IBAction func closeAction(_ sender: Any) {
            userDidDismiss = true
            rootViewControllerShouldDismissPresentedViewController()
        }

        @IBAction func forwardAction(_ sender: Any) {
            if webView != nil {
                webView?.goForward()
            }
        }

        @IBAction func backAction(_ sender: Any) {
            if webView != nil {
                webView?.goBack()
            }
        }

        @IBAction func openInAction(_ sender: Any) {
            var webViewURL: URL?
            if webView != nil {
                webViewURL = webView?.url
            }
            if (webViewURL?.absoluteString.count ?? 0) != 0 {
                let appActivities = [AMOpenInExternalBrowserActivity()]
                let share = UIActivityViewController(
                    activityItems: [webViewURL].compactMap { $0 },
                    applicationActivities: appActivities)

                if UIDevice.current.userInterfaceIdiom == .pad {

                    let popController = share.popoverPresentationController
                    popController?.permittedArrowDirections = .any
                    popController?.barButtonItem = openInButton
                }
                present(share, animated: true)
            }
        }

        init?(url: URL?, delegate: AMBrowserViewControllerDelegate?, delayPresentationForLoad shouldDelayPresentation: Bool) {
            let nibName = "AMBrowserViewController"
            if AMPathForAMResource(nibName, "nib") == nil {
                AMLogError("Could not instantiate browser controller because of missing NIB file")
                return nil
            }
            super.init(nibName: nibName, bundle: resourcesBundle)
            self.url = url
            self.delegate = delegate
            delayPresentationForLoad = shouldDelayPresentation

            initializeWebView()
            loadViewIfNeeded()
        }


        private var _url: URL?
        var url: URL? {
            get {
                _url
            }
            set(url) {
                if !(url?.absoluteString == _url?.absoluteString) || (!loading && !completedInitialLoad) {
                    _url = url
                    resetBrowser()
                    initializeWebView()
                } else {
                    AMLogWarn("In-app browser ignoring request to load - request is already loading")
                }
            }
        }
        private(set) var delayPresentationForLoad = false
        private(set) var completedInitialLoad = false
        private(set) var loading = false

        func stopLoading() {
            if webView != nil {
                webView?.stopLoading()
            }
            updateLoadingStateForFinishLoad()
        }
        private var webView: AMWebView?

        private var _refreshIndicatorItem: UIBarButtonItem?
        private var refreshIndicatorItem: UIBarButtonItem? {
            if _refreshIndicatorItem == nil {
                let indicator = UIActivityIndicatorView(style: .gray)
                indicator.startAnimating()
                _refreshIndicatorItem = UIBarButtonItem(customView: indicator)
            }
            return _refreshIndicatorItem
        }
        private var iTunesStoreController: SKStoreProductViewController?
        private var presented = false

        private var _presenting = false
        private var presenting: Bool {
            get {
                _presenting
            }
            set(presenting) {
                _presenting = presenting
                if !_presenting && postPresentingOperation != nil {
                    if let postPresentingOperation = postPresentingOperation {
                        OperationQueue.main.addOperation(postPresentingOperation)
                    }
                    postPresentingOperation = nil
                }
            }
        }

        private var _dismissing = false
        private var dismissing: Bool {
            get {
                _dismissing
            }
            set(dismissing) {
                _dismissing = dismissing
                if !_dismissing && postDismissingOperation != nil {
                    if let postDismissingOperation = postDismissingOperation {
                        OperationQueue.main.addOperation(postDismissingOperation)
                    }
                    postDismissingOperation = nil
                }
            }
        }
        private var postPresentingOperation: Operation?
        private var postDismissingOperation: Operation?
        private var userDidDismiss = false
        private var receivedInitialRequest = false

        func initializeWebView() {
            webView = AMWebView(size: UIScreen.main.bounds.size, url: url)
            webView?.navigationDelegate = self
            webView?.uiDelegate = self

        }

    // MARK: - Lifecycle callbacks
        override func viewDidLoad() {
            super.viewDidLoad()
            refreshButtons()
            addWebViewToContainerView()
            setupToolbar()
        }

        deinit {
            resetBrowser()
            webView?.navigationDelegate = nil
            webView?.uiDelegate = nil
            iTunesStoreController?.delegate = nil
        }

        func resetBrowser() {
            completedInitialLoad = false
            loading = false
            receivedInitialRequest = false
            webView = nil
        }

        func loadingStateDidChange(fromOldValue oldValue: Bool, toNewValue newValue: Bool) {
            if oldValue != newValue {
                if delegate?.responds(to: #selector(AMVideoAdPlayer.browserViewController(_:browserIsLoading:))) ?? false {
                    delegate?.browserViewController?(
                        self,
                        browserIsLoading: newValue)
                }
            }
        }

        func updateLoadingStateForStartLoad() {
            let oldValue = loading
            if webView != nil {
                loading = webView?.isLoading ?? false
            }
            loadingStateDidChange(fromOldValue: oldValue, toNewValue: loading)
            refreshToolbarActivityIndicator()
            refreshButtons()
        }

        func updateLoadingStateForFinishLoad() {
            let oldValue = loading
            if webView != nil {
                loading = webView?.isLoading ?? false
            }
            loadingStateDidChange(fromOldValue: oldValue, toNewValue: loading)
            refreshToolbarActivityIndicator()
            refreshButtons()
        }

        func shouldStartLoad(with request: URLRequest?) -> Bool {
            let anURL = request?.url
            var iTunesId: NSNumber? = nil
            if let anURL = anURL {
                iTunesId = AMiTunesIDForURL(anURL)
            }
            var shouldStartLoadWithRequest = false

            if iTunesId != nil {
                if webView != nil {
                    webView?.stopLoading()
                }
                loadAndPresentStoreWithiTunesId(iTunesId)
            } else if AMHasHttpPrefix(anURL?.scheme ?? "") {
                if !presented && !presenting && !delayPresentationForLoad {
                    rootViewControllerShouldPresent()
                }
                shouldStartLoadWithRequest = true
            } else if let anURL = anURL {
                if UIApplication.shared.canOpenURL(anURL) {
                    if !completedInitialLoad {
                        rootViewControllerShouldDismissPresentedViewController()
                    }
                    if delegate?.responds(to: #selector(AMVideoAdPlayer.willLeaveApplication(from:))) ?? false {
                        delegate?.willLeaveApplication?(from: self)
                    }
                    AMLogDebug("\(NSStringFromSelector(#function))| Opening URL in external application: \(anURL)")
                    if webView != nil {
                        webView?.stopLoading()
                    }
                    AMGlobal.openURL(anURL.absoluteString)
                } else {
                    AMLogWarn("opening_url_failed %@", anURL)
                    if !receivedInitialRequest {
                        if delegate?.responds(to: #selector(AMVideoAdPlayer.browserViewController(_:couldNotHandleInitialURL:))) ?? false {
                            delegate?.browserViewController?(self, couldNotHandleInitialURL: anURL)
                        }
                    }
                }
            }

            if shouldStartLoadWithRequest {
                updateLoadingStateForStartLoad()
            }

            receivedInitialRequest = true

            return shouldStartLoadWithRequest
        }

    // MARK: - Adjust for status bar
        override func viewWillLayoutSubviews() {
            var containerViewDistanceToTopOfSuperview: CGFloat
            if responds(to: #selector(getter: UIViewController.modalPresentationCapturesStatusBarAppearance)) {
                let statusBarFrameSize = UIApplication.shared.statusBarFrame.size
                containerViewDistanceToTopOfSuperview = statusBarFrameSize.height
                if statusBarFrameSize.height > statusBarFrameSize.width {
                    containerViewDistanceToTopOfSuperview = statusBarFrameSize.width
                }
            } else {
                containerViewDistanceToTopOfSuperview = 0
            }

            containerViewSuperviewTopConstraint.constant = containerViewDistanceToTopOfSuperview
        }

    //#pragma - User Interface
        func addWebViewToContainerView() {
            var contentView: UIView?
            if webView != nil {
                contentView = webView
            }
            if let contentView = contentView {
                webViewContainerView.addSubview(contentView)
            }
            contentView?.translatesAutoresizingMaskIntoConstraints = false
            contentView?.anConstrainToSizeOfSuperview()
            contentView?.anAlignToSuperview(
                withXAttribute: .left,
                yAttribute: .top)
        }

        func setupToolbar() {
            if !responds(to: #selector(getter: UIViewController.modalPresentationCapturesStatusBarAppearance)) {
                let backArrow = UIImage(contentsOfFile: AMPathForAMResource("UIButtonBarArrowLeft", "png") ?? "")
                let forwardArrow = UIImage(contentsOfFile: AMPathForAMResource("UIButtonBarArrowRight", "png") ?? "")
                backButton.image = backArrow
                forwardButton.image = forwardArrow

                backButton.tintColor = UIColor.white
                forwardButton.tintColor = UIColor.white
                openInButton.tintColor = UIColor.white
                refreshButton.tintColor = nil
                okButton.tintColor = nil
            }
            // Setting OK button Localized String
            okButton.title = NSLocalizedString("OK", comment: "LabelForInAppBrowserReturnButton")
        }

        func refreshButtons() {
            if webView != nil {
                backButton.isEnabled = webView?.canGoBack ?? false
                forwardButton.isEnabled = webView?.canGoForward ?? false
            }
        }

        func refreshToolbarActivityIndicator() {
            var toolbarItems = toolbar.items
            var refreshItemIndex = toolbarItems?.firstIndex(of: refreshButton)
            if refreshItemIndex == nil {
                if let refreshIndicatorItem = refreshIndicatorItem {
                    refreshItemIndex = toolbarItems?.firstIndex(of: refreshIndicatorItem)
                }
            }
            
            guard let strongRefreshItemIndex = refreshItemIndex else { return }
            if loading {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
                if let refreshIndicatorItem = refreshIndicatorItem {
                    toolbarItems?[strongRefreshItemIndex] = refreshIndicatorItem
                }
            } else {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                toolbarItems?[strongRefreshItemIndex] = refreshButton
            }
            toolbar.setItems(toolbarItems, animated: false)
        }

    // MARK: - User Actions

        @IBAction func refresh(_ sender: Any) {
            if webView != nil {
                webView?.reload()
            }
        }

    // MARK: - Presentation Methods
        func rootViewControllerShouldPresent() {
            rootViewControllerShouldPresent(self)
        }

        func rootViewControllerShouldPresentStore() {
            rootViewControllerShouldPresent(iTunesStoreController)
        }

        func rootViewControllerShouldPresent(_ controllerToPresent: UIViewController?) {
            if presenting || presented || userDidDismiss {
                return
            }
            if dismissing {
                AMLogDebug("In-app browser dismissal in progress - will present after dismiss")
                weak var weakSelf = self
                postDismissingOperation = BlockOperation(block: {
                    let strongSelf = weakSelf
                    strongSelf?.rootViewControllerShouldPresent(controllerToPresent)
                })
                return
            }

            let rvc = self.delegate?.rootViewController(forDisplaying: self)
            if !AMCanPresentFromViewController(rvc) {
                AMLogDebug("No root view controller provided, or root view controller view not attached to window - could not present in-app browser")
                return
            }

            presenting = true
            delegate?.willPresent?(self)
            
            weak var weakSelf = self
            controllerToPresent?.modalPresentationStyle = .fullScreen
            if let controllerToPresent = controllerToPresent {
                rvc?.present(controllerToPresent, animated: true) {
                    let strongSelf = weakSelf
                    if strongSelf?.delegate?.responds(to: #selector(AMVideoAdPlayer.didPresent(_:))) ?? false {
                        strongSelf?.delegate?.didPresent?(strongSelf)
                    }
                    strongSelf?.presenting = false
                    strongSelf?.presented = true
                }
            }
        }

        func rootViewControllerShouldDismissPresentedViewController() {
            if dismissing || (!presented && !presenting) {
                return
            }
            if presenting {
                AMLogDebug("In-app browser presentation in progress - will dismiss after present")
                weak var weakSelf = self
                postPresentingOperation = BlockOperation(block: {
                    let strongSelf = weakSelf
                    strongSelf?.rootViewControllerShouldDismissPresentedViewController()
                })
                return
            }

            var controllerForDismissingModalView = iTunesStoreController?.presentingViewController
            if presentingViewController != nil {
                controllerForDismissingModalView = presentingViewController
            }

            UIApplication.shared.isNetworkActivityIndicatorVisible = false

            dismissing = true
            if delegate?.responds(to: #selector(AMVideoAdPlayer.willDismiss(_:))) ?? false {
                delegate?.willDismiss?(self)
            }
            weak var weakSelf = self
            controllerForDismissingModalView?.dismiss(animated: true) {
                let strongSelf = weakSelf
                if strongSelf?.delegate?.responds(to: #selector(AMVideoAdPlayer.didDismiss(_:))) ?? false {
                    strongSelf?.delegate?.didDismiss?(strongSelf)
                }
                strongSelf?.dismissing = false
                strongSelf?.presented = false
            }
        }

    // MARK: - WKWebView
        static var defaultWebViewConfigurationAnSdkProcessPool: WKProcessPool?

        class func defaultWebViewConfiguration() -> WKWebViewConfiguration? {
            // `dispatch_once()` call was converted to a static variable initializer

            let configuration = WKWebViewConfiguration()
            if let defaultWebViewConfigurationAnSdkProcessPool = defaultWebViewConfigurationAnSdkProcessPool {
                configuration.processPool = defaultWebViewConfigurationAnSdkProcessPool
            }
            configuration.allowsInlineMediaPlayback = true

            // configuration.allowsInlineMediaPlayback = YES is not respected
            // on iPhone on WebKit versions shipped with iOS 9 and below, the
            // video always loads in full-screen.
            // See: https://bugs.webkit.org/show_bug.cgi?id=147512
            if ProcessInfo.processInfo.responds(to: #selector(ProcessInfo.isOperatingSystemAtLeast(_:))) && ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 10, minorVersion: 0, patchVersion: 0)) {
                configuration.mediaTypesRequiringUserActionForPlayback = []
            } else {
                configuration.mediaTypesRequiringUserActionForPlayback = .all
            }

            return configuration
        }

    // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let shouldStartLoadWithRequest = shouldStartLoad(with: navigationAction.request)

            if shouldStartLoadWithRequest {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            AMLogTrace("%@", NSStringFromSelector(#function))
            updateLoadingStateForStartLoad()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            AMLogTrace("%@ %@", NSStringFromSelector(#function), error.localizedDescription)
            updateLoadingStateForFinishLoad()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            AMLogTrace("%@ %@", NSStringFromSelector(#function), error.localizedDescription)
            if (((error as NSError).domain) == NSURLErrorDomain) && ((error as NSError).code == NSURLErrorSecureConnectionFailed || (error as NSError).code == NSURLErrorAppTransportSecurityRequiresSecureConnection) {
                if let url = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL {
                    AMLogError(
                    """
                                    In-app browser attempted to load URL which is not compliant with App Transport Security.\
                    Opening the URL in the native browser. URL: \(url.absoluteString)
                    """)
                    AMGlobal.openURL(url.absoluteString)
                }
            }
            updateLoadingStateForFinishLoad()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            AMLogTrace("%@", NSStringFromSelector(#function))
            updateLoadingStateForFinishLoad()
            if !completedInitialLoad {
                completedInitialLoad = true
                if !presented {
                    rootViewControllerShouldPresent()
                }
            }
        }

    // MARK: - WKUIDelegate
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }
            guard let urlString = navigationAction.request.url?.absoluteString else { return nil }
            AMGlobal.openURL(urlString)
            return nil
        }

    // MARK: - SKStoreProductViewController
        func loadAndPresentStoreWithiTunesId(_ iTunesId: NSNumber?) {
            if iTunesId != nil {
                iTunesStoreController = SKStoreProductViewController()
                iTunesStoreController?.delegate = self
                if let iTunesId = iTunesId {
                    iTunesStoreController?.loadProduct(
                        withParameters: [
                            SKStoreProductParameterITunesItemIdentifier: iTunesId
                        ],
                        completionBlock: nil)
                }
                if presenting {
                    postPresentingOperation = BlockOperation(block: {
                        self.presentStore()
                    })
                    return
                } else if dismissing {
                    postDismissingOperation = BlockOperation(block: {
                        self.presentStore()
                    })
                    return
                }
                presentStore()
            }
        }

        func presentStore() {
            if presented {
                if let iTunesStoreController = iTunesStoreController {
                    present(
                        iTunesStoreController,
                        animated: true)
                }
            } else {
                rootViewControllerShouldPresentStore()
            }
        }

        func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
            userDidDismiss = true
            rootViewControllerShouldDismissPresentedViewController()
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }

}

@objc protocol AMBrowserViewControllerDelegate: NSObjectProtocol {
    func rootViewController(forDisplaying controller: AMBrowserViewController?) -> UIViewController?

    @objc optional func browserViewController(
        _ controller: AMBrowserViewController?,
        couldNotHandleInitialURL url: URL?
    )
    @objc optional func browserViewController(
        _ controller: AMBrowserViewController?,
        browserIsLoading isLoading: Bool
    )
    @objc optional func willPresent(_ controller: AMBrowserViewController?)
    @objc optional func didPresent(_ controller: AMBrowserViewController?)
    @objc optional func willDismiss(_ controller: AMBrowserViewController?)
    @objc optional func didDismiss(_ controller: AMBrowserViewController?)
    @objc optional func willLeaveApplication(from controller: AMBrowserViewController?)
}
