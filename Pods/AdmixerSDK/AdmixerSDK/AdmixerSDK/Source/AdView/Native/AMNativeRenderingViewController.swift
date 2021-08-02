//
//  AMNativeRenderingViewController.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
import WebKit

private let kAMNativeResponseObject = "AM_NATIVE_RENDERING_OBJECT"
private let kAMNativeRenderingURL = "AM_NATIVE_RENDERING_URL"
private let kAMNativeRenderingInvalidURL = "invalidRenderingURL"
private let kAMNativeRenderingValidURL = "validRenderingURL"

class AMNativeRenderingViewController: UIView, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, AMBrowserViewControllerDelegate {
    private var webView: AMWebView?
    private var contentView: UIView?
    private var isAdLoaded = false
    private var completedFirstLoad = false
    private var browserViewController: AMBrowserViewController?
    private var clickOverlay: AMClickOverlayView?
    
    init(size: CGSize, baseObject: Any?) {
        let initialRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        super.init(frame: initialRect)
        backgroundColor = UIColor.clear

        if (baseObject is AMRTBNativeAdResponse) {
            setUpNativeRenderingContentWith(size, baseObject: baseObject)
        }
    }

    weak var loadingDelegate: AMNativeRenderingViewControllerLoadingDelegate?
    weak var adViewDelegate: AMAdViewInternalDelegate?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setUpNativeRenderingContentWith(_ size: CGSize, baseObject: Any?) {
        let baseAd = baseObject as? AMRTBNativeAdResponse
        let nativeRenderingUrl = AMSDKSettings.sharedInstance.baseUrlConfig.nativeRenderingUrl()
        var renderNativeAssetsHTML: String? = nil
        do {
            if let nativeRenderingUrl = nativeRenderingUrl {
                renderNativeAssetsHTML = try String(contentsOf: nativeRenderingUrl, encoding: .utf8)
            }
        } catch {}

        if let nativeRenderingObject = baseAd?.nativeAdResponse?.nativeRenderingObject {
                renderNativeAssetsHTML = renderNativeAssetsHTML?.replacingOccurrences(
                    of: kAMNativeResponseObject,
                    with: nativeRenderingObject)
            }

        if let nativeRenderingUrl1 = baseAd?.nativeAdResponse?.nativeRenderingUrl {
                renderNativeAssetsHTML = renderNativeAssetsHTML?.replacingOccurrences(
                    of: kAMNativeRenderingURL,
                    with: nativeRenderingUrl1)
            }

            renderNativeAssetsHTML = renderNativeAssetsHTML?.replacingOccurrences(of: kAMNativeRenderingValidURL, with: kAMNativeRenderingValidURL)

            renderNativeAssetsHTML = renderNativeAssetsHTML?.replacingOccurrences(of: kAMNativeRenderingInvalidURL, with: kAMNativeRenderingInvalidURL)

            initAMWebView(
                with: size,
                html: renderNativeAssetsHTML)
        }

        func initAMWebView(with size: CGSize,
            html: String?
        ) {
            var base: URL?

            if base == nil {
                base = URL(string:  AMSDKSettings.sharedInstance.baseUrlConfig.webViewBaseUrl())
            }

            webView = AMWebView(size: size, content: html, baseURL: base)


            configureWebView()
        }

        func configureWebView() {

            webView?.configuration.userContentController.add(self, name: "rendererOp")

            webView?.navigationDelegate = self
            webView?.uiDelegate = self

            contentView = webView

        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            processWebViewDidFinishLoad()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let anURL = navigationAction.request.url
            let mainDocumentURL = navigationAction.request.mainDocumentURL
            let urlScheme = anURL?.scheme

            let logStr = anURL?.absoluteString.removingPercentEncoding
            AMLogDebug("Loading URL: \(String(describing: logStr))")
            
            guard completedFirstLoad else {
                decisionHandler(.allow)
                return
            }

            guard let scheme = urlScheme, AMHasHttpPrefix(scheme) else {
                openDefaultBrowser(with: anURL)
                decisionHandler(.cancel)
                return
            }
            
            let sameURL = mainDocumentURL?.absoluteString == anURL?.absoluteString
            let navigationIsLinkActivated = navigationAction.navigationType == .linkActivated
            let emptyframe = navigationAction.targetFrame == nil
            
            if sameURL || navigationIsLinkActivated || emptyframe {
                openDefaultBrowser(with: anURL)
                decisionHandler(.cancel)
                return
            }
           
            decisionHandler(.allow)
        }

        func openDefaultBrowser(with anURL: URL?) {
            guard let adViewDelegate = self.adViewDelegate else {
                AMLogDebug("Ignoring attempt to trigger browser on ad while not attached to a view.")
                return
            }

            if adViewDelegate.clickThroughAction != .returnURL {
                adViewDelegate.adWasClicked()
            }

            switch adViewDelegate.clickThroughAction {
            case .returnURL:
                if let anURL = anURL {
                    adViewDelegate.adWasClicked?(withURL: anURL.absoluteString)
                    AMLogDebug("ClickThroughURL=\(anURL)")
                }
            case .openDeviceBrowser:
                    if let anURL = anURL {
                        if UIApplication.shared.canOpenURL(anURL) {
                            adViewDelegate.adWillLeaveApplication()
                            AMGlobal.openURL(anURL.absoluteString)
                        } else {
                            AMLogWarn("opening_url_failed %@", anURL)
                        }
                    }
            case .openSDKBrowser:
                    openInAppBrowser(with: anURL)
                default:
                    AMLogError("UNKNOWN AMClickThroughAction.  \(adViewDelegate.clickThroughAction)")
            }
        }

        func openInAppBrowser(with anURL: URL?) {
            guard browserViewController == nil else {
                browserViewController?.url = anURL
                return
            }

            let delayForLoad = adViewDelegate!.landingPageLoadsInBackground
            browserViewController = AMBrowserViewController(url: anURL, delegate: self, delayPresentationForLoad: delayForLoad)
            if browserViewController == nil {
                AMLogError("Browser controller did not instantiate correctly.")
            }
        }

        func setAdViewDelegate(_ adViewDelegate: AMAdViewInternalDelegate?) {
            self.adViewDelegate = adViewDelegate
        }

    // MARK: - AMAdWebViewControllerLoadingDelegate
        func processWebViewDidFinishLoad() {
            if !completedFirstLoad {
                completedFirstLoad = true
                if isAdLoaded {
                    DispatchQueue.main.asyncAfter(
                        deadline: DispatchTime.now() + Double(0.15 * Double(NSEC_PER_SEC)) / Double(NSEC_PER_SEC),
                        execute: {[weak self] in
                            guard let self = self else {return}

                            if let contentView = self.contentView {
                                contentView.translatesAutoresizingMaskIntoConstraints = false

                                self.addSubview(contentView)
                                self.contentView?.isHidden = false

                                contentView.anConstrainToSizeOfSuperview()
                                contentView.anAlignToSuperview(withXAttribute: .left, yAttribute: .top)
                            }
                            self.loadingDelegate?.didCompleteFirstLoad(fromNativeWebViewController: self)
                        })
                } else {
                    self.loadingDelegate?.didFailToLoadNativeWebViewController?()
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            var eventName = ""
            if (message.body is String) {
                eventName = message.body as? String ?? ""
            }
            if !(eventName == kAMNativeRenderingInvalidURL) {
                isAdLoaded = true
            } else {
                isAdLoaded = false
            }
        }

    // MARK: - AMBrowserViewControllerDelegate
        func rootViewController(forDisplaying controller: AMBrowserViewController?) -> UIViewController? {
            return display()
        }

        func didDismiss(_ controller: AMBrowserViewController?) {
            browserViewController = nil

        }

        func willLeaveApplication(from controller: AMBrowserViewController?) {
            adViewDelegate?.adWillLeaveApplication()
        }

    // MARK: - Helper methods.
        func display() -> UIViewController? {

            let presentingVC: UIViewController? = adViewDelegate?.displayController()

            if AMCanPresentFromViewController(presentingVC) {
                return presentingVC
            }
            return nil
        }

    override func willMove(toSuperview newSuperview: UIView?) {
            super.willMove(toSuperview: newSuperview)

            // UIView already added to superview.
            if newSuperview != nil {
                return
            }
            stopWebViewLoadForDealloc()
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
}

@objc protocol AMNativeRenderingViewControllerLoadingDelegate: NSObjectProtocol {
    func didCompleteFirstLoad(fromNativeWebViewController controller: AMNativeRenderingViewController?)

    @objc optional func didFailToLoadNativeWebViewController()
}
