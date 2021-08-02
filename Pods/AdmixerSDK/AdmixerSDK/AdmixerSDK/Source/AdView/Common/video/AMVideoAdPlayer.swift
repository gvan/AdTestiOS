//
//  AMVideoAdPlayer.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import AVFoundation
import UIKit
import WebKit

//#import <OMSDK_Admixer/OMIDImports.h>



@objc enum AMVideoAdPlayerTracker : Int {
    case firstQuartile
    case midQuartile
    case thirdQuartile
    case fourthQuartile
}

@objc enum AMVideoAdPlayerEvent : Int {
    case play
    case skip
    case muteOff
    case muteOn
}

//#import "AMOMIDImplementation.h"
private let kAMWebviewNilDelayInSeconds: TimeInterval = 0.5

@objc protocol AMVideoAdPlayerDelegate: NSObjectProtocol {
    func videoAdReady()
    func videoAdLoadFailed(_ error: Error, with adResponseInfo: AMAdResponseInfo?)

    @objc optional func videoAdError(_ error: Error)
    @objc optional func videoAdWillPresent(_ videoAd: AMVideoAdPlayer)
    @objc optional func videoAdDidPresent(_ videoAd: AMVideoAdPlayer)
    @objc optional func videoAdWillClose(_ videoAd: AMVideoAdPlayer)
    @objc optional func videoAdDidClose(_ videoAd: AMVideoAdPlayer)
    @objc optional func videoAdWillLeaveApplication(_ videoAd: AMVideoAdPlayer)
    @objc optional func videoAdImpressionListeners(_ tracker: AMVideoAdPlayerTracker)
    @objc optional func videoAdEventListeners(_ eventTrackers: AMVideoAdPlayerEvent)
    @objc optional func videoAdWasClicked()
    @objc optional func videoAdWasClicked(withURL urlString: String)
    @objc optional func videoAdPlayerClickThroughAction() -> AMClickThroughAction
    @objc optional func videoAdPlayerLandingPageLoadsInBackground() -> Bool
    @objc optional func videoAdPlayerFullScreenEntered(_ videoAd: AMVideoAdPlayer)
    @objc optional func videoAdPlayerFullScreenExited(_ videoAd: AMVideoAdPlayer)
}

class AMVideoAdPlayer: UIView, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, AMBrowserViewControllerDelegate {
    
    //@property (nonatomic, readwrite, strong) OMIDAdmixerAdSession * omidAdSession;
    private weak var webView: WKWebView?
    private var browserViewController: AMBrowserViewController?
    private var vastContent: String?
    private var vastURL: String?
    private var jsonContent: String?
    private var creativeURL: String? = ""
    private var videoDuration = 0
    private var vastURLContent: String? = ""
    private var vastXMLContent: String? = ""
    private var videoAdOrientation: AMVideoOrientation! = .anUnknown
    var creativeWidth: Int?
    var creativeHeight: Int?
    
    var delegate: AMVideoAdPlayerDelegate?

    private var clickThroughAction: AMClickThroughAction! {
        var returnVal: AMClickThroughAction = .openSDKBrowser
        if let video = delegate?.videoAdPlayerClickThroughAction?() {
            returnVal = video
        }

        return returnVal
    }

    private var landingPageLoadsInBackground: Bool {
        var returnVal = true

        if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdPlayerLandingPageLoadsInBackground)) ?? false {
            returnVal = delegate?.videoAdPlayerLandingPageLoadsInBackground?() ?? false
        }

        return returnVal
    }

    func loadAd(withVastContent vastContent: String) {
        self.vastContent = vastContent
        createVideoPlayer()
    }

    func loadAd(withVastUrl vastUrl: String) {
        vastURL = vastUrl
        createVideoPlayer()
    }

    func loadAd(withJSONContent jsonContent: String) {
        self.jsonContent = jsonContent
        createVideoPlayer()
    }

    func playAd(withContainer containerView: UIView) {
        webView?.removeFromSuperview()

        webView?.isHidden = false
        if let webView = webView {
            containerView.addSubview(webView)
        }

        webView?.translatesAutoresizingMaskIntoConstraints = false
        webView?.anConstrainToSizeOfSuperview()
        webView?.anAlignToSuperview(withXAttribute: .left, yAttribute: .top)

        let exec = "adPlay();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }

    @objc func pauseAdVideo() {
        let exec = "adPause();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }

    @objc func resumeAdVideo() {
        let exec = "adPlay();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }
    
    func hideClickThruControl() {
        let exec = "hideLearnMore();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }
    
    func showClickTruControl() {
        let exec = "showLearnMore();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }
    
    func hideVolumeControl() {
        let exec = "hideMute();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }
    
    func showVolumeControl() {
        let exec = "showMute();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }
    
    func hideSkip() {
        let exec = "hideSkip();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }
    
    func showSkip() {
        let exec = "showSkip();"
        webView?.evaluateJavaScript(exec, completionHandler: nil)
    }

    func remove() {
        if webView != nil {
            let controller = webView?.configuration.userContentController
            controller?.removeScriptMessageHandler(forName: "observe")
            controller?.removeScriptMessageHandler(forName: "interOp")
            webView?.navigationDelegate = nil
            webView?.uiDelegate = nil
            webView?.removeFromSuperview()
            stopOMIDAdSession()

            // Delay is added to allow completion tracker to be fired successfully.
            // Setting up webView to nil immediately without adding any delay can cause failure of tracker
            let popTime = DispatchTime.now() + Double(Int64(kAMWebviewNilDelayInSeconds * Double(NSEC_PER_SEC)))
            DispatchQueue.main.asyncAfter(deadline: popTime, execute: {
                if self.webView != nil {
                    self.webView = nil
                }
            })
        }
    }

    func getAdDuration() -> Int {
        return videoDuration
    }

    func getCreativeURL() -> String? {
        return creativeURL
    }

    func getVASTURL() -> String? {
        return vastURLContent
    }

    func getVASTXML() -> String? {
        return vastXMLContent
    }
    
    func getCreativeWidth() -> Int? {
        return creativeWidth
    }
    
    func getCreativeHeight() -> Int? {
        return creativeHeight
    }

    func getAdPlayElapsedTime() -> Int {
        let exec_template = "getCurrentPlayHeadTime();"
        var result: Int = 0
        DispatchQueue.global().sync {
            webView?.evaluateJavaScript(exec_template){(res, err) in
                guard let str = res as? String else { return}
                if let intRes = Int(str) { result = intRes }
                
            }
        }
        return result
    }

    /// Get the Orientation of the Video rendered using the BannerAdView
    ///
    /// - Returns: Default VideoOrientation value AMUnknown, which indicates that aspectRatio can't be retrieved for the video.
    func getVideoAdOrientation() -> AMVideoOrientation {
        return videoAdOrientation
    }

// MARK: - Lifecycle.
    deinit {
        deregisterObserver()
    }

    func registerObserver() {
        deregisterObserver()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resumeAdVideo),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseAdVideo),
            name: UIApplication.willResignActiveNotification,
            object: nil)
    }

    func deregisterObserver() {
        NotificationCenter.default.removeObserver(self)
    }

    func stopOMIDAdSession() {
        //    if(self.omidAdSession != nil){
        //        [[AMOMIDImplementation sharedInstance] stopOMIDAdSession:self.omidAdSession];
        //        self.omidAdSession = nil;
        //    }
    }

// MARK: - Getters/Setters.

// MARK: - Public methods.

// MARK: - Helper methods.
    func createVideoPlayer() {
        let url = AMSDKSettings.sharedInstance.baseUrlConfig.videoWebViewUrl()
        var request: URLRequest? = nil
        if let url = url {
            request = URLRequest(url: url)
        }
        let configuration = WKWebViewConfiguration() //Creating a WKWebViewConfiguration object so a controller can be added to it.

        let controller = WKUserContentController() //Creating the WKUserContentController.
        controller.add(self, name: "observe") //Adding a script handler to the controller and setting the userContentController property on the configuration.
        configuration.userContentController = controller
        configuration.allowsInlineMediaPlayback = true

        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(self, name: "interOp")


        let currentWindow = UIApplication.shared.keyWindow
        //provide the width & height of the webview else the video wont be displayed ********
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 325, height: 275), configuration: configuration)
        webView?.scrollView.isScrollEnabled = false
        let w = webView?.frame.size.width ?? -1
        let h = webView?.frame.size.height ?? -1
        AMLogInfo("width = \(w), height = \(h)")

        webView?.navigationDelegate = self
        webView?.uiDelegate = self
        webView?.isOpaque = false
        webView?.backgroundColor = UIColor.black

        if let webView = webView {
            currentWindow?.addSubview(webView)
        }

        if let request = request {
            webView?.load(request)
        } //Load up webView with the url and add it to the view.

        webView?.isHidden = true

    }

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
                } else if (messageDictionary?["event"] is Int) {
                    eventName = String(messageDictionary?["event"] as? Int ?? -1)
                }
                if let object = messageDictionary?["params"] as? [AnyHashable : Any] {
                    paramsDictionary = object
                }
            }
        }

        AMLogDebug("Event: \(eventName)")

        if (eventName == "video-complete") {
            AMLogInfo("video-complete")
            stopOMIDAdSession()
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdImpressionListeners(_:))) ?? false {
                delegate?.videoAdImpressionListeners?(.fourthQuartile)
            }
        } else if (eventName == "adReady") {
            AMLogInfo("adReady")
            //        self.omidAdSession = [[AMOMIDImplementation sharedInstance] createOMIDAdSessionforWebView:self.webView isVideoAd:true];
            if paramsDictionary.count > 0 {
                creativeURL = paramsDictionary["creativeUrl"] as? String
                let duration = paramsDictionary["duration"] as? NSNumber
                vastURLContent = paramsDictionary["vastCreativeUrl"] as? String
                vastXMLContent = paramsDictionary["vastXML"] as? String
                videoAdOrientation = AMGlobal.parseVideoOrientation(paramsDictionary[kAMAspectRatio] as? String)
                if Int(truncating: duration ?? 0) > 0 {
                    videoDuration = duration?.intValue ?? 0
                }
            }
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdReady)) ?? false {
                delegate?.videoAdReady()
            }
        } else if (eventName == "videoStart") {
            AMLogInfo("%@", eventName)
            registerObserver()
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdEventListeners(_:))) ?? false {
                delegate?.videoAdEventListeners?(.play)
            }
        } else if (eventName == "video-first-quartile") {
            AMLogInfo("video-first-quartile")
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdImpressionListeners(_:))) ?? false {
                delegate?.videoAdImpressionListeners?(.firstQuartile)
            }
        } else if (eventName == "video-mid") {
            AMLogInfo("video-mid")
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdImpressionListeners(_:))) ?? false {
                delegate?.videoAdImpressionListeners?(.midQuartile)
            }
        } else if (eventName == "video-third-quartile") {
            AMLogInfo("video-third-quartile")
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdImpressionListeners(_:))) ?? false {
                delegate?.videoAdImpressionListeners?(.thirdQuartile)
            }
        } else if (eventName == "video-skip") {
            AMLogInfo("video-skip")
            stopOMIDAdSession()
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdEventListeners(_:))) ?? false {
                webView?.removeFromSuperview()
                delegate?.videoAdEventListeners?(.skip)
            }
        } else if (eventName == "video-fullscreen") || (eventName == "video-fullscreen-enter") {
            AMLogInfo("video-fullscreen")
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdPlayerFullScreenEntered(_:))) ?? false {
                delegate?.videoAdPlayerFullScreenEntered?(self)
            }
        } else if (eventName == "video-fullscreen-exit") {
            AMLogInfo("video-fullscreen-exit")
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdPlayerFullScreenExited(_:))) ?? false {
                delegate?.videoAdPlayerFullScreenExited?(self)
            }
        } else if (eventName == "video-error") || (eventName == "Timed-out") {

            //we need to remove the webview to makesure we dont get any other response from the loaded index.html page
            remove()
            AMLogInfo("video player error")
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdLoadFailed(_:with:))) ?? false {
                let error = AMError("Timeout reached while parsing VAST", AMAdResponseCode.amAdResponseInternalError.rawValue)
                delegate?.videoAdLoadFailed(error, with: nil)
            }
        } else if (eventName == "audio-mute") {
            AMLogInfo("video player mute")
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdEventListeners(_:))) ?? false {
                delegate?.videoAdEventListeners?(.muteOn)
            }
        } else if (eventName == "audio-unmute") {
            AMLogInfo("video player unmute")
            if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdEventListeners(_:))) ?? false {
                delegate?.videoAdEventListeners?(.muteOff)
            }
        }
    }

// MARK: - WKNavigationDelegate.

    func webView(_ webView: WKWebView, createWebViewWith inConfig: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame?.isMainFrame == nil else{ return nil }

        //
        let urlString = navigationAction.request.url?.absoluteString


        if .returnURL != clickThroughAction {
            delegate?.videoAdWasClicked?()
        }

        switch clickThroughAction {
            case .returnURL:
                resumeAdVideo()
                let url = urlString ?? ""
                delegate?.videoAdWasClicked?(withURL: url)
                AMLogDebug("ClickThroughURL=\(url)")
            case .openDeviceBrowser:
                if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdWillLeaveApplication(_:))) ?? false {
                    delegate?.videoAdWillLeaveApplication?(self)
                }
                AMGlobal.openURL(urlString ?? "")
            case .openSDKBrowser:
                if browserViewController == nil {
                    browserViewController = AMBrowserViewController(
                        url: URL(string: urlString ?? ""),
                        delegate: self,
                        delayPresentationForLoad: landingPageLoadsInBackground)

                    if browserViewController == nil {
                        if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdError(_:))) ?? false {
                            let error = AMError("AMBrowserViewController initialization FAILED.", AMAdResponseCode.amAdResponseInternalError.rawValue)
                            delegate?.videoAdError?(error)
                        }
                    }
                } else {
                    browserViewController?.url = URL(string: urlString ?? "")
                }
            default:
                AMLogError("UNKNOWN AMClickThroughAction.  \(clickThroughAction.rawValue)")
        }

        //
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        AMLogInfo("web page loading started")

    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if (vastContent?.count ?? 0) > 0 {

            let videoOptions = AMVideoPlayerSettings.sharedInstance.fetchInStreamVideoSettings() ?? ""
            let videoXML = self.vastContent ?? ""
            let injectXML = videoXML
                .replacingOccurrences(of: "'", with: "\"")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n\r", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            
            let exec = "createVastPlayerWithContent('\(injectXML)','\(videoOptions)');"

            self.webView?.evaluateJavaScript(exec, completionHandler: nil)
        } else if (vastURL?.count ?? 0) > 0 {
            AMLogInfo("Not implemented")
        } else if let content = jsonContent, !content.isEmpty {
            let mediationJsonString = "processMediationAd('\(content)')"
            self.webView?.evaluateJavaScript(mediationJsonString, completionHandler: nil)
        }
        AMLogInfo("web page loading completed")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let anURL = navigationAction.request.url
        let URLScheme = anURL?.scheme

        if (URLScheme == "anwebconsole") {
            printConsoleLog(with: anURL)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

// MARK: - AMBrowserViewControllerDelegate.
    func rootViewController(forDisplaying controller: AMBrowserViewController?) -> UIViewController? {
        return webView?.anParentViewController
    }

    @objc func browserViewController(
        _ controller: AMBrowserViewController?,
        couldNotHandleInitialURL url: URL?
    ) {
        AMLogTrace("UNUSED.")
    }

    @objc func browserViewController(
        _ controller: AMBrowserViewController?,
        browserIsLoading isLoading: Bool
    ) {
        AMLogTrace("UNUSED.")
    }

    @objc func willPresent(_ controller: AMBrowserViewController?) {
        if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdWillPresent(_:))) ?? false {
            delegate?.videoAdWillPresent?(self)
        }
    }

    @objc func didPresent(_ controller: AMBrowserViewController?) {
        if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdDidPresent(_:))) ?? false {
            delegate?.videoAdDidPresent?(self)
        }
    }

    @objc func willDismiss(_ controller: AMBrowserViewController?) {
        if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdWillClose(_:))) ?? false {
            delegate?.videoAdWillClose?(self)
        }
    }

    @objc func didDismiss(_ controller: AMBrowserViewController?) {
        browserViewController = nil
        resumeAdVideo()
        if delegate?.responds(to: #selector(AMVideoAdPlayerDelegate.videoAdDidClose(_:))) ?? false {
            delegate?.videoAdDidClose?(self)
        }
    }

    @objc func willLeaveApplication(from controller: AMBrowserViewController?) {
        AMLogTrace("UNUSED.")
    }

// MARK: - AMWebConsole
    func printConsoleLog(with anURL: URL?) {
        if let decodedString = anURL?.absoluteString.removingPercentEncoding {
            AMLogDebug(decodedString)
        }
    }

    init() {
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
