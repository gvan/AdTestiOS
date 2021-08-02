//
//  AMAdWebViewController.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//
import Foundation
import CoreGraphics
import WebKit

let kAMWebViewControllerMraidJSFilename = "bundle = 'inApp'"
let kAMUISupportedInterfaceOrientations = "UISupportedInterfaceOrientations"
let kAMUIInterfaceOrientationPortrait = "UIInterfaceOrientationPortrait"
let kAMUIInterfaceOrientationPortraitUpsideDown = "UIInterfaceOrientationPortraitUpsideDown"
let kAMUIInterfaceOrientationLandscapeLeft = "UIInterfaceOrientationLandscapeLeft"
let kAMUIInterfaceOrientationLandscapeRight = "UIInterfaceOrientationLandscapeRight"
let kAMPortrait = "portrait"
let kAMLandscape = "landscape"

class AMAdWebViewController: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private(set) var isMRAID = false
    private(set) var contentView: UIView?
    private(set) var completedFirstLoad = false
    //@property (nonatomic, readwrite, strong) OMIDAdmixerAdSession *omidAdSession;
    private(set) var configuration: AMAdWebViewControllerConfiguration?
    weak var adViewAMJAMDelegate: AMAdViewInternalDelegate?
    private var videoAdReady = false

    private weak var _adViewDelegate: AMAdViewInternalDelegate?
    weak var adViewDelegate: AMAdViewInternalDelegate? {
        get {
            _adViewDelegate
        }
        set(adViewDelegate) {
            _adViewDelegate = adViewDelegate
            if _adViewDelegate != nil {
                fireJavaScript(AMMRAIDJavascriptUtil.placementType(_adViewDelegate?.adTypeForMRAID()))
            }
        }
    }
    weak var anjamDelegate: AMAdWebViewControllerAMJAMDelegate?
    weak var browserDelegate: AMAdWebViewControllerBrowserDelegate?
    var loadingDelegate: AMAdWebViewControllerLoadingDelegate?
    weak var mraidDelegate: AMAdWebViewControllerMRAIDDelegate?
    weak var videoDelegate: AMAdWebViewControllerVideoDelegate?

    var checkViewableTimeInterval: TimeInterval = 1.0 {didSet{
        self.checkViewableRunLoopMode = .common
        if viewabilityTimer == nil { return }
        enableViewabilityTimer(with: checkViewableTimeInterval, mode: .common)
    }}
    

    private(set) var videoAdOrientation: AMVideoOrientation!

    convenience init(size: CGSize, url URL: URL?, webViewBaseURL baseURL: URL?) {
        self.init(size: size, url: URL, webViewBaseURL: baseURL, configuration: nil)
    }

    convenience init(size: CGSize,url URL: URL?, webViewBaseURL baseURL: URL?, configuration: AMAdWebViewControllerConfiguration?) {
        self.init(configuration: configuration)

        webView = AMWebView(size: size, url: URL, baseURL: baseURL)
        loadWebViewWithUserScripts()
    }

    convenience init(size: CGSize, html: String?, webViewBaseURL baseURL: URL?) {
        self.init(size: size, html: html, webViewBaseURL: baseURL, configuration: nil)
    }

    convenience init(size: CGSize, html: String?, webViewBaseURL baseURL: URL?, configuration: AMAdWebViewControllerConfiguration?) {
        self.init(configuration: configuration)

        //
        let mraidJSRange = (html as NSString?)?.range(of: kAMWebViewControllerMraidJSFilename)
        var base = baseURL

        isMRAID = mraidJSRange?.location != NSNotFound

        if base == nil {
            base = URL(string: AMSDKSettings.sharedInstance.baseUrlConfig.webViewBaseUrl())
        }

        var htmlToLoad = html

        if !(self.configuration?.scrollingEnabled ?? false) {
            htmlToLoad = AMAdWebViewController.prependViewport(toHTML: htmlToLoad)
        }
        webView = AMWebView(size: size, content: htmlToLoad, baseURL: base)
        loadWebViewWithUserScripts()
    }

    convenience init(size: CGSize, videoXML: String?) {
        self.init(configuration: nil)

        configuration?.scrollingEnabled = false
        configuration?.isVASTVideoAd = true

        //Encode videoXML to Base64String
        let injectXML = videoXML?
            .replacingOccurrences(of: "'", with: "\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n\r", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        self.videoXML = injectXML

        handleMRAIDURL(URL(string: "mraid://enable"))

        webView = AMWebView(size: size, url: AMSDKSettings.sharedInstance.baseUrlConfig.videoWebViewUrl())

        loadWebViewWithUserScripts()

        let currentWindow = UIApplication.shared.keyWindow
        if let webView = webView {
            currentWindow?.addSubview(webView)
        }
        webView?.isHidden = true

        //

    }

    func fireJavaScript(_ javascript: String?) {
        webView?.evaluateJavaScript(javascript ?? "", completionHandler: nil)
    }

    func updateViewability(_ isViewable: Bool) {
        let exec = "viewabilityUpdate('\(isViewable ? "true" : "false")');"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }
    private var webView: AMWebView?
    private var viewabilityTimer: Timer?
    private var viewable = false
    private var defaultPosition = CGRect.zero
    private var currentPosition = CGRect.zero
    private var lastKnownExposedPercentage: CGFloat = 0.0
    private var lastKnownVisibleRect = CGRect.zero
    private var rapidTimerSet = false
    private var checkViewableRunLoopMode: RunLoop.Mode!
    private var videoXML: String?
    private var appIsInBackground = false

    init(configuration: AMAdWebViewControllerConfiguration?) {
        super.init()
            if configuration != nil {
                self.configuration = configuration
            } else {
                self.configuration = AMAdWebViewControllerConfiguration()
            }

            checkViewableTimeInterval = TimeInterval(kAdmixerMRAIDCheckViewableFrequency)
            checkViewableRunLoopMode = .common

            appIsInBackground = false
    }

    //- (void)stopOMIDAdSession {
    //    if(self.omidAdSession != nil){
    //        [[AMOMIDImplementation sharedInstance] stopOMIDAdSession:self.omidAdSession];
    //    }
    //}
    deinit {
        deallocActions()
    }

    func deallocActions() {
        //    [self stopOMIDAdSession];
        stopWebViewLoadForDealloc()
        viewabilityTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

// MARK: - Scripts
    class func mraidHTML() -> String? {
        return "<script type=\"text/javascript\">\(self.mraidJS() ?? "")</script>"
    }

    class func anjamHTML() -> String? {
        return "<script type=\"text/javascript\">\(self.anjamJS() ?? "")</script>"
    }

    class func mraidJS() -> String? {
        guard let mraidPath = AMPathForAMResource("mraid", "js") else { return "" }
        guard let mraidmData = NSData(contentsOfFile: mraidPath) as Data? else { return "" }
        guard let mraid = String(data: mraidmData, encoding: .utf8) else { return "" }

        return mraid
    }

    class func anjamJS() -> String? {
        let sdkjsPath = AMPathForAMResource("sdkjs", "js")
        let anjamPath = AMPathForAMResource("anjam", "js")
        if sdkjsPath == nil || anjamPath == nil {
            return ""
        }

        let sdkjsData = NSData(contentsOfFile: sdkjsPath ?? "") as Data?
        let anjamData = NSData(contentsOfFile: anjamPath ?? "") as Data?
        var sdkjs: String? = nil
        if let sdkjsData = sdkjsData {
            sdkjs = String(data: sdkjsData, encoding: .utf8)
        }
        var anjam: String? = nil
        if let anjamData = anjamData {
            anjam = String(data: anjamData, encoding: .utf8)
        }

        let anjamString = "\(sdkjs ?? "") \(anjam ?? "")"

        return anjamString
    }

    class func prependViewport(toHTML html: String?) -> String? {
        return "\("<meta name=\"viewport\" content=\"initial-scale=1.0, user-scalable=no\">")\(html ?? "")"
    }

    class func prependScripts(toHTML html: String?) -> String? {
        return "\(self.anjamHTML() ?? "")\(self.mraidHTML() ?? "")\(html ?? "")"
    }

// MARK: - configure WKWebView
    func loadWebViewWithUserScripts() {
        guard let webView = self.webView else { return }
        let config = webView.configuration
        let controller = config.userContentController

        let mraidJS = AMAdWebViewController.mraidJS() ?? ""
        let mraidScript = WKUserScript(source: mraidJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)

        let anjamJS = AMAdWebViewController.anjamJS() ?? ""
        let anjamScript = WKUserScript(source: anjamJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)

        controller.addUserScript(anjamScript)
        controller.addUserScript(mraidScript)

        if !(configuration?.userSelectionEnabled ?? false) {
            let userSelectionSuppressionJS = "document.documentElement.style.webkitUserSelect='none';"

            let userSelectionSuppressionScript = WKUserScript(
                source: userSelectionSuppressionJS,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false)
            controller.addUserScript(userSelectionSuppressionScript)
        }

        // Attach  OMID JS script to WKWebview for HTML Banner Ad's
        // This is used inplace of [OMIDScriptInjector injectScriptContent] because it scrambles the creative HTML. See MS-3707 for more details.
        //    if(!self.configuration.isVASTVideoAd){
        //        WKUserScript *omidScript = [[WKUserScript alloc] initWithSource: [[AMOMIDImplementation sharedInstance] getOMIDJS]
        //                                                          injectionTime: WKUserScriptInjectionTimeAtDocumentStart
        //                                                       forMainFrameOnly: YES];
        //        [controller addUserScript:omidScript];
        //    }

        if configuration?.scrollingEnabled ?? false {
            webView.scrollView.isScrollEnabled = true
            webView.scrollView.bounces = true
        } else {
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.bounces = false

            NotificationCenter.default.removeObserver(webView, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            NotificationCenter.default.removeObserver(webView, name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
            NotificationCenter.default.removeObserver(webView, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(webView, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        
        webView.configuration.allowsInlineMediaPlayback = true
        if configuration?.isVASTVideoAd ?? false {
            webView.configuration.userContentController.add(self, name: "observe")
            webView.configuration.userContentController.add(self, name: "interOp")

            webView.backgroundColor = UIColor.black
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self

        contentView = webView
    }

// MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        AMLogInfo("WKWebView didStartProvisionalNavigation")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        processWebViewDidFinishLoad()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        AMLogDebug("\(NSStringFromSelector(#function)), \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        AMLogDebug("\(NSStringFromSelector(#function)), \(error)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let anURL = navigationAction.request.url
        let mainDocumentURL = navigationAction.request.mainDocumentURL
        let URLScheme = anURL?.scheme

        if (URLScheme == "anwebconsole") {
            printConsoleLog(with: anURL)
            decisionHandler(.cancel)
            return
        }
        let urlStr = anURL?.absoluteString.removingPercentEncoding ?? "no_url"
        AMLogDebug("Loading URL: \(urlStr)")

        // For security reasons, test for fragment of path to vastVideo.html.
        //
        if (URLScheme == "file") {
            let filePathContainsThisString = "/admixer_vast_video.html"

            if (anURL?.absoluteString as NSString?)?.range(of: filePathContainsThisString).location == NSNotFound {
                return
            }

            decisionHandler(.allow)
            return
        }

        if completedFirstLoad {
            if AMHasHttpPrefix(URLScheme ?? "") {
                if isMRAID {
                    if ((mainDocumentURL?.absoluteString == anURL?.absoluteString) || navigationAction.targetFrame == nil) && configuration?.navigationTriggersDefaultBrowser ?? false {
                        browserDelegate?.openDefaultBrowser(with: anURL)
                        decisionHandler(.cancel)
                        return
                    }
                } else {
                    if ((mainDocumentURL?.absoluteString == anURL?.absoluteString) || navigationAction.navigationType == .linkActivated || navigationAction.targetFrame == nil) && configuration?.navigationTriggersDefaultBrowser ?? false {
                        browserDelegate?.openDefaultBrowser(with: anURL)
                        decisionHandler(.cancel)
                        return
                    }
                }
            } else if (URLScheme == "mraid") {
                handleMRAIDURL(anURL)
                decisionHandler(.cancel)
                return
            } else if (URLScheme == "anjam") {
                anjamDelegate?.handleAMJAMURL(anURL)
                decisionHandler(.cancel)
                return
            } else if (URLScheme == "about") {
                if navigationAction.targetFrame != nil && navigationAction.targetFrame?.isMainFrame == false {
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }
                return
            } else {
                if configuration?.navigationTriggersDefaultBrowser ?? false {
                    browserDelegate?.openDefaultBrowser(with: anURL)
                    decisionHandler(.cancel)
                    return
                }
            }
        } else {
            if (URLScheme == "mraid") {
                if (anURL?.host == "enable") {
                    handleMRAIDURL(anURL)
                }
                decisionHandler(.cancel)
                return
            } else if (URLScheme == "anjam") {
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }

// MARK: - WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            browserDelegate?.openDefaultBrowser(with: navigationAction.request.url)
        }

        return nil
    }

// MARK: - WKScriptMessageHandler.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        var eventName = ""
        var paramsDictionary: [AnyHashable : Any] = [:]

        if (message.body is String) {
            eventName = message.body as? String ?? ""
        } else if (message.body is [AnyHashable : Any]) {
            let messageDictionary = message.body as? [AnyHashable : Any]

            if (messageDictionary?.count ?? 0) > 0 {
                if(messageDictionary?["event"] is String) {
                    eventName = messageDictionary?["event"] as? String ?? ""
                } else if(messageDictionary?["event"] is Int) {
                    eventName = String(messageDictionary?["event"] as? Int ?? -1)
                }
                if let object = messageDictionary?["params"] as? [AnyHashable : Any] {
                    paramsDictionary = object
                }
            }
        }

        AMLogDebug("Event: \(eventName)")

        if (eventName == "adReady") {
            if paramsDictionary.count > 0 {
                videoAdOrientation = AMGlobal.parseVideoOrientation(paramsDictionary[kAMAspectRatio] as? String)
            }
            // For VideoAds's wait unitll adReady to create AdSession if not the adsession will run in limited access mode.
            //        self.omidAdSession = [[AMOMIDImplementation sharedInstance] createOMIDAdSessionforWebView:self.webView isVideoAd:true];
            if !videoAdReady && videoDelegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdReady)) ?? false {
                videoDelegate?.videoAdReady()
            }
            videoAdReady = true
        } else if (eventName == "videoStart") || (eventName == "videoRewind") {
            viewabilityTimer?.fire()

            if mraidDelegate?.responds(to: #selector(AMAdWebViewControllerMRAIDDelegate.isViewable)) ?? false {
                updateViewability(mraidDelegate?.isViewable() ?? false)
            }
        } else if (eventName == "video-fullscreen-enter") {
            if videoDelegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdPlayerFullScreenEntered(_:))) ?? false {
                videoDelegate?.videoAdPlayerFullScreenEntered(self)
            }
        } else if (eventName == "video-fullscreen-exit") {
            if videoDelegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdPlayerFullScreenExited(_:))) ?? false {
                videoDelegate?.videoAdPlayerFullScreenExited(self)
            }
        } else if (eventName == "video-error") || (eventName == "Timed-out") {
            //we need to remove the webview to makesure we dont get any other response from the loaded index.html page
            deallocActions()

            if videoDelegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdError(_:))) ?? false {
                let error = AMError("Timeout reached while parsing VAST", AMAdResponseCode.amAdResponseInternalError.rawValue)
                videoDelegate?.videoAdError(error)
            }

        } else if (eventName == "video-complete") {

            //        [self stopOMIDAdSession];
        } else if ((videoXML?.count ?? 0) > 0) && ((eventName == "video-first-quartile") || (eventName == "video-mid") || (eventName == "video-third-quartile") || (eventName == "audio-mute") || (eventName == "audio-unmute")) {
            //EMPTY -- Silently ignore spurious VAST playback errors that might scare a client-dev into thinking something is wrong...
        } else {
            AMLogError("UNRECOGNIZED video event.  (%@)", eventName)
        }
    }

// MARK: - MRAID
    func processWebViewDidFinishLoad() {
        if !completedFirstLoad {
            completedFirstLoad = true
            // If it is VAST ad then donot call didCompleteFirstLoadFromWebViewController videoAdReady will call it later.
            if (videoXML?.count ?? 0) > 0 {
                let lockQueue = DispatchQueue(label: "self")
                lockQueue.sync {
                    processVideoViewDidFinishLoad()
                }
            } else if loadingDelegate?.responds(to: #selector(AMUniversalAdFetcher.didCompleteFirstLoad(from:))) ?? false {
                let lockQueue = DispatchQueue(label: "self")
                lockQueue.sync {
                    loadingDelegate?.didCompleteFirstLoad(from: self)
                }
            }

            //
            if isMRAID {
                finishMRAIDLoad()
            }
            //        if(!([self.videoXML length] > 0)){
            //             self.omidAdSession = [[AMOMIDImplementation sharedInstance] createOMIDAdSessionforWebView:self.webView isVideoAd:false];
            //        }
        }
    }

    func finishMRAIDLoad() {
        fireJavaScript(AMMRAIDJavascriptUtil.pageFinished())
        if adViewDelegate?.adTypeForMRAID() != nil {
            fireJavaScript(AMMRAIDJavascriptUtil.placementType(adViewDelegate?.adTypeForMRAID()))
        }
        fireJavaScript(
            AMMRAIDJavascriptUtil.feature(
                "sms",
                isSupported: AMMRAIDUtil.supportsSMS()))
        fireJavaScript(
            AMMRAIDJavascriptUtil.feature(
                "tel",
                isSupported: AMMRAIDUtil.supportsTel()))
        fireJavaScript(
            AMMRAIDJavascriptUtil.feature(
                "calendar",
                isSupported: AMMRAIDUtil.supportsCalendar()))
        fireJavaScript(
            AMMRAIDJavascriptUtil.feature(
                "inlineVideo",
                isSupported: AMMRAIDUtil.supportsInlineVideo()))
        fireJavaScript(
            AMMRAIDJavascriptUtil.feature(
                "storePicture",
                isSupported: AMMRAIDUtil.supportsStorePicture()))
        updateCurrentAppOrientation()

        updateWebViewOnOrientation()


        updateWebViewOnPositionAndViewabilityStatus()

        if configuration?.initialMRAIDState == .expanded || configuration?.initialMRAIDState == .resized {
            setupRapidTimerForCheckingPositionAndViewability()
            rapidTimerSet = true
        } else {
            setupTimerForCheckingPositionAndViewability()
        }

        setupApplicationBackgroundNotifications()
        setupOrientationChangeNotification()

        if let initialMRAIDState1 = configuration?.initialMRAIDState {
            fireJavaScript(AMMRAIDJavascriptUtil.stateChange(initialMRAIDState1))
        }
        fireJavaScript(AMMRAIDJavascriptUtil.readyEvent())
    }

    func setupApplicationBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidEnterBackground(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: UIApplication.shared)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)

    }

    @objc func handleApplicationDidEnterBackground(_ notification: Notification?) {
        viewable = false
        appIsInBackground = true

        if videoDelegate != nil {
            updateViewability(false)
        } else {
            fireJavaScript(AMMRAIDJavascriptUtil.isViewable(false))
        }
    }

    @objc func handleApplicationDidBecomeActive(_ notification: Notification?) {
        appIsInBackground = false
    }

    func setupOrientationChangeNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange(_:)),
            name: UIApplication.didChangeStatusBarOrientationNotification,
            object: UIApplication.shared)
    }

    @objc func handleOrientationChange(_ notification: Notification?) {
        updateWebViewOnOrientation()
    }

    func setupTimerForCheckingPositionAndViewability() {
        enableViewabilityTimer( with: checkViewableTimeInterval, mode: checkViewableRunLoopMode)
    }

    func setupRapidTimerForCheckingPositionAndViewability() {
        enableViewabilityTimer(with: 0.1, mode: .common)
    }

    func enableViewabilityTimer(with timeInterval: TimeInterval, mode: RunLoop.Mode) {
        self.viewabilityTimer?.invalidate()

        guard mode == .common else {
            self.viewabilityTimer = Timer.anScheduledTimer(
                with: timeInterval,
                block: { [weak self] in
                    self?.updateWebViewOnPositionAndViewabilityStatus()
                },
                repeats: true)
            return
        }
        viewabilityTimer = Timer.anScheduledTimer(
            with: timeInterval,
            block: { [weak self] in
                self?.updateWebViewOnPositionAndViewabilityStatus()
            },
            repeats: true,
            mode: mode)
    }

    func updateWebViewOnPositionAndViewabilityStatus() {
        guard let mraidDelegate = mraidDelegate else { return }
        
        let isCurrentlyViewable = !appIsInBackground && mraidDelegate.isViewable()

        if viewable != isCurrentlyViewable {
            AMLogDebug("Viewablity change: \(isCurrentlyViewable)" )
            viewable = isCurrentlyViewable

            if videoDelegate != nil {
                updateViewability(viewable)
            } else {
                fireJavaScript(AMMRAIDJavascriptUtil.isViewable(viewable))
            }
        }
        
        let updatedDefaultPosition = mraidDelegate.defaultPosition()
        if !defaultPosition.equalTo(updatedDefaultPosition) {
            AMLogDebug("Default position change: \(NSCoder.string(for: updatedDefaultPosition))")
            defaultPosition = updatedDefaultPosition
            fireJavaScript(AMMRAIDJavascriptUtil.defaultPosition(defaultPosition))
        }

        let updatedCurrentPosition = mraidDelegate.currentPosition
        if currentPosition != updatedCurrentPosition {
            AMLogDebug("Current position change: \(String(describing: updatedCurrentPosition))")
            self.currentPosition = updatedCurrentPosition
            let currPosition = CGRect(x: 0, y: 0, width: 375, height: 667)
            fireJavaScript(AMMRAIDJavascriptUtil.currentPosition(currPosition))
            fireJavaScript(AMMRAIDJavascriptUtil.currentSize(currPosition))
        }
        
        let updatedExposedPercentage = mraidDelegate.exposedPercent() // updatedExposedPercentage from MRAID Delegate
        let updatedVisibleRectangle = mraidDelegate.visibleRect // updatedVisibleRectangle from MRAID Delegate

        // Send exposureChange Event only when there is an update from the previous.
        if lastKnownExposedPercentage != updatedExposedPercentage || !lastKnownVisibleRect.equalTo(updatedVisibleRectangle) {
            lastKnownExposedPercentage = updatedExposedPercentage
            lastKnownVisibleRect = updatedVisibleRectangle
            fireJavaScript(AMMRAIDJavascriptUtil.exposureChangeExposedPercentage(lastKnownExposedPercentage, visibleRectangle: lastKnownVisibleRect))
        }
    }

    func updateWebViewOnOrientation() {
        fireJavaScript(AMMRAIDJavascriptUtil.screenSize(AMMRAIDUtil.screenSize()))
        fireJavaScript(AMMRAIDJavascriptUtil.maxSize(AMMRAIDUtil.maxSizeSafeArea()))
    }

    func updateCurrentAppOrientation() {

        let currentAppOrientation = UIApplication.shared.statusBarOrientation
        let currentAppOrientationString = (currentAppOrientation.isPortrait) ? kAMPortrait : kAMLandscape

        let supportedOrientations = Bundle.main.infoDictionary?[kAMUISupportedInterfaceOrientations] as? [AnyHashable]
        let isPortraitOrientationSupported = supportedOrientations?.contains(kAMUIInterfaceOrientationPortrait) ?? false || supportedOrientations?.contains(kAMUIInterfaceOrientationPortraitUpsideDown) ?? false
        let isLandscapeOrientationSupported = supportedOrientations?.contains(kAMUIInterfaceOrientationLandscapeLeft) ?? false || supportedOrientations?.contains(kAMUIInterfaceOrientationLandscapeRight) ?? false

        let lockedOrientation = !(isPortraitOrientationSupported && isLandscapeOrientationSupported)


        fireJavaScript(AMMRAIDJavascriptUtil.setCurrentAppOrientation(currentAppOrientationString, lockedOrientation: lockedOrientation))

    }

    func stopWebViewLoadForDealloc() {
        if webView != nil {
            webView?.stopLoading()

            webView?.navigationDelegate = nil
            webView?.uiDelegate = nil

            webView?.removeFromSuperview()
            webView = nil
        }
        contentView = nil
    }

    func handleMRAIDURL(_ anURL: URL?) {
        AMLogDebug("Received MRAID query: \(String(describing: anURL))")

        let mraidCommand = anURL?.host
        let query = anURL?.query
        let queryComponents = query?.anQueryComponents()

        let action = AMMRAIDUtil.action(forCommand: mraidCommand)
        switch action {
            case .unknown:
                AMLogDebug("Unknown MRAID action requested: \(String(describing: mraidCommand))")
                return
            case .expand:
                adViewDelegate?.adWasClicked()
                forwardExpandRequest(withQueryComponents: queryComponents)
            case .close:
                forwardCloseAction()
            case .resize:
                adViewDelegate?.adWasClicked()
                forwardResizeRequest(withQueryComponents: queryComponents)
            case .createCalendarEvent:
                adViewDelegate?.adWasClicked()
                guard let w3cEventJson = queryComponents?["p"] as? String else { return }
                forwardCalendarEventRequest(withW3CJSONString: w3cEventJson)
            case .playVideo:
                adViewDelegate?.adWasClicked()
                guard let uri = queryComponents?["uri"] as? String else { return }
                mraidDelegate?.adShouldPlayVideo(withUri: uri)
            case .storePicture:
                adViewDelegate?.adWasClicked()
                guard let uri = queryComponents?["uri"] as? String else { return }
                mraidDelegate?.adShouldSavePicture(withUri: uri)
            case .setOrientationProperties:
                forwardOrientationProperties(withQueryComponents: queryComponents)
            case .setUseCustomClose:
                guard let value = queryComponents?["value"] as? String else { return }
                let useCustomClose = value == "true"
                mraidDelegate?.adShouldSetUseCustomClose(useCustomClose)
            case .openURI:
                guard let uri = queryComponents?["uri"] as? String else { return }
                let anURL = URL(string: uri )
                if uri.count != 0 && anURL != nil {
                    browserDelegate?.openDefaultBrowser(with: anURL)
                }
            case .enable:
                if isMRAID { return }
                isMRAID = true
                if completedFirstLoad {
                    finishMRAIDLoad()
                }
        }
    }

    func forwardCloseAction() {
        mraidDelegate?.adShouldClose()
    }

    func forwardResizeRequest(withQueryComponents queryComponents: [AnyHashable : Any]?) {
        let resizeProperties = AMMRAIDResizeProperties(fromQueryComponents: queryComponents)
        mraidDelegate?.adShouldAttemptResize(with: resizeProperties)
    }

    func forwardExpandRequest(withQueryComponents queryComponents: [AnyHashable : Any]?) {
        if !rapidTimerSet {
            setupRapidTimerForCheckingPositionAndViewability()
            rapidTimerSet = true
        }
        let expandProperties = AMMRAIDExpandProperties(fromQueryComponents: queryComponents)
        forwardOrientationProperties(withQueryComponents: queryComponents)
        mraidDelegate?.adShouldExpand(with: expandProperties)
    }

    func forwardOrientationProperties(withQueryComponents queryComponents: [AnyHashable : Any]?) {
        let orientationProperties = AMMRAIDOrientationProperties(fromQueryComponents: queryComponents)
        mraidDelegate?.adShouldSetOrientationProperties(orientationProperties)
    }

    func forwardCalendarEventRequest(withW3CJSONString json: String?) {
        var err: Error?
        var jsonObject: Any? = nil
        do {
            if let data = json?.data(using: .utf8) {
                jsonObject = try JSONSerialization.jsonObject(
                    with: data,
                    options: [])
            }
        } catch {
            err = error
        }
        if err == nil && (jsonObject is [AnyHashable : Any]) {
            mraidDelegate?.adShouldOpenCalendar(withCalendarDict: jsonObject as? [AnyHashable : Any])
        }
    }

    func updatePlacementType(_ placementType: String?) {
        if isMRAID {
            fireJavaScript(AMMRAIDJavascriptUtil.placementType(placementType))
        }
    }

// MARK: - MRAID Callbacks
    
    func adDidFinishExpand() {
        fireJavaScript(AMMRAIDJavascriptUtil.stateChange(.expanded))
    }

    func adDidFinishResize(_ success: Bool, errorString: String?, isResized: Bool) {
        if success {
            fireJavaScript(AMMRAIDJavascriptUtil.stateChange(.resized))
        } else {
            fireJavaScript(
                AMMRAIDJavascriptUtil.error(
                    errorString,
                    forFunction: "mraid.resize()"))
        }
    }

    func adDidResetToDefault() {
        fireJavaScript(AMMRAIDJavascriptUtil.stateChange(.`default`))
    }

    func adDidHide() {
        fireJavaScript(AMMRAIDJavascriptUtil.stateChange(.hidden))
        stopWebViewLoadForDealloc()
    }

    func adDidFailCalendarEditWithErrorString(_ errorString: String?) {
        fireJavaScript(
            AMMRAIDJavascriptUtil.error(
                errorString,
                forFunction: "mraid.createCalendarEvent()"))
    }

    func adDidFailPhotoSaveWithErrorString(_ errorString: String?) {
        fireJavaScript(
            AMMRAIDJavascriptUtil.error(
                errorString,
                forFunction: "mraid.storePicture()"))
    }

// MARK: - AMWebConsole
    func printConsoleLog(with anURL: URL?) {
        let decodedString = anURL?.absoluteString.removingPercentEncoding
        print("------- \(decodedString ?? "")")
    }

// MARK: - Banner Video.
    func processVideoViewDidFinishLoad() {
        let videoOptions = AMVideoPlayerSettings.sharedInstance.fetchBannerSettings() ?? ""
        
        let videoXML = self.videoXML ?? ""
        
        let exec = "createVastPlayerWithContent('\(videoXML)','\(videoOptions)');"

        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }
}

class AMAdWebViewControllerConfiguration: NSObject, NSCopying {
    var scrollingEnabled = false
    var navigationTriggersDefaultBrowser = false
    var initialMRAIDState: AMMRAIDState!
    var userSelectionEnabled = false
    var isVASTVideoAd = false

    override init() {
        super.init()
            scrollingEnabled = false
            navigationTriggersDefaultBrowser = true
            initialMRAIDState = .`default`
            userSelectionEnabled = false
            isVASTVideoAd = false
    }

    func copy(with zone: NSZone? = nil) -> Any {
        let configurationCopy = AMAdWebViewControllerConfiguration()
        configurationCopy.scrollingEnabled = scrollingEnabled
        configurationCopy.navigationTriggersDefaultBrowser = navigationTriggersDefaultBrowser
        configurationCopy.initialMRAIDState = initialMRAIDState
        configurationCopy.userSelectionEnabled = userSelectionEnabled
        configurationCopy.isVASTVideoAd = isVASTVideoAd
        return configurationCopy
    }

    override var description: String {
        let state = self.initialMRAIDState.rawValue
        return "scrollingEnabled: \(scrollingEnabled), navigationTriggersDefaultBrowser:\(navigationTriggersDefaultBrowser), initialMRAIDState: \(state), userSelectionEnabled: \(userSelectionEnabled), isBannerVideo: \(isVASTVideoAd)"
    }
}

// MARK: - Protocol definitions.
protocol AMAdWebViewControllerAMJAMDelegate: NSObjectProtocol {
    func handleAMJAMURL(_ url: URL?)
}

protocol AMAdWebViewControllerBrowserDelegate: NSObjectProtocol {
    func openDefaultBrowser(with url: URL?)
    func openInAppBrowser(with url: URL?)
}

// NB  This delegate is used unconventionally as a means to call back through two class compositions:
//     AMAdWebViewController calls AMMRAIDContainerView calls AMUniversalAdFetcher.
//
@objc protocol AMAdWebViewControllerLoadingDelegate: NSObjectProtocol {
    func didCompleteFirstLoad(from controller: AMAdWebViewController?)

    @objc optional func immediatelyRestartAutoRefreshTimer(from controller: AMAdWebViewController?)
    @objc optional func stopAutoRefreshTimer(from controller: AMAdWebViewController?)
}

@objc protocol AMAdWebViewControllerMRAIDDelegate: NSObjectProtocol {
    func defaultPosition() -> CGRect
    var currentPosition: CGRect { get }
    func isViewable() -> Bool
    var visibleRect: CGRect { get }
    func exposedPercent() -> CGFloat
    func adShouldExpand(with expandProperties: AMMRAIDExpandProperties?)
    func adShouldAttemptResize(with resizeProperties: AMMRAIDResizeProperties?)
    func adShouldSetOrientationProperties(_ orientationProperties: AMMRAIDOrientationProperties?)
    func adShouldSetUseCustomClose(_ useCustomClose: Bool)
    func adShouldClose()
    func adShouldOpenCalendar(withCalendarDict calendarDict: [AnyHashable : Any]?)
    func adShouldSavePicture(withUri uri: String?)
    func adShouldPlayVideo(withUri uri: String?)
}

@objc protocol AMAdWebViewControllerVideoDelegate: NSObjectProtocol {
    func videoAdReady()
    func videoAdLoadFailed(_ error: Error?, with adResponseInfo: AMAdResponseInfo?)
    func videoAdError(_ error: Error?)
    func videoAdPlayerFullScreenEntered(_ videoAd: AMAdWebViewController?)
    func videoAdPlayerFullScreenExited(_ videoAd: AMAdWebViewController?)
}
