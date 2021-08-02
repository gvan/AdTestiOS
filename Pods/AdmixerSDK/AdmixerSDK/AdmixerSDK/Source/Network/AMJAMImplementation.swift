//
//  AMJAMImplementation.swift
//  AdmixerSDK
//
//  Created by admin on 10/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
import WebKit

let kAMCallMayDeepLink = "MayDeepLink"
let kAMCallDeepLink = "DeepLink"
let kAMCallExternalBrowser = "ExternalBrowser"
let kAMCallInternalBrowser = "InternalBrowser"
let kAMCallRecordEvent = "RecordEvent"
let kAMCallDispatchAppEvent = "DispatchAppEvent"
let kAMCallGetDeviceID = "GetDeviceID"
let kAMCallSetMraidRefreshFrequency = "SetMRAIDRefreshFrequency"
let kAMKeyCaller = "caller"

class AMJAMImplementation: NSObject {
    class func handle(_ URL: URL?, with controller: AMAdWebViewController?) {
        guard let url = URL else { return }
        guard let call = url.host else { return }
        let queryComponents = URL?.query?.anQueryComponents()
        if (call == kAMCallMayDeepLink) {
            AMJAMImplementation.callMayDeepLink(controller, query: queryComponents)
        } else if (call == kAMCallDeepLink) {
            AMJAMImplementation.callDeepLink(controller, query: queryComponents)
        } else if (call == kAMCallExternalBrowser) {
            AMJAMImplementation.callExternalBrowser(controller, query: queryComponents)
        } else if (call == kAMCallInternalBrowser) {
            AMJAMImplementation.callInternalBrowser(controller, query: queryComponents)
        } else if (call == kAMCallRecordEvent) {
            AMJAMImplementation.callRecordEvent(controller, query: queryComponents)
        } else if (call == kAMCallDispatchAppEvent) {
            AMJAMImplementation.callDispatchAppEvent(controller, query: queryComponents)
        } else if (call == kAMCallGetDeviceID) {
            AMJAMImplementation.callGetDeviceID(controller, query: queryComponents)
        } else if (call == kAMCallSetMraidRefreshFrequency) {
            AMJAMImplementation.callSetMraidRefreshFrequency(controller, query: queryComponents)
        } else {
            AMLogWarn("AMJAM called with unsupported function: \(call)")
        }
    }

    // Deep Link
    class func callMayDeepLink(_ controller: AMAdWebViewController?, query: [AnyHashable : Any]?) {
        let cb = query?["cb"] as? String
        let urlParam = query?["url"] as? String
        var mayDeepLink: Bool = false

        if (urlParam?.count ?? 0) < 1 {
            mayDeepLink = false
        } else {
            let url = URL(string: urlParam ?? "")
            if let url = url {
                mayDeepLink = UIApplication.shared.canOpenURL(url)
            }
        }

        let paramsList = [
            kAMKeyCaller: kAMCallMayDeepLink,
            "mayDeepLink": mayDeepLink ? "true" : "false"
        ]
        AMJAMImplementation.loadResult(controller, cb: cb, paramsList: paramsList)
    }

    class func callDeepLink(_ controller: AMAdWebViewController?, query: [AnyHashable : Any]?) {
        let cb = query?["cb"] as? String
        let urlParam = query?["url"] as? String

        let url = URL(string: urlParam ?? "")
        if let url = url {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            } else {
                let paramsList = [
                    kAMKeyCaller: kAMCallDeepLink
                ]
                AMJAMImplementation.loadResult(controller, cb: cb, paramsList: paramsList)
            }
        }
    }

    // Launch Browser
    class func callExternalBrowser(_ controller: AMAdWebViewController?, query: [AnyHashable : Any]?) {
        let urlParam = query?["url"] as? String

        let url = URL(string: urlParam ?? "")
        if let url = url {
            if AMHasHttpPrefix(url.scheme ?? "") && UIApplication.shared.canOpenURL(url) {
                //added as the test case was failing due to unavailability of a delegate.
                controller?.adViewAMJAMDelegate?.adWillLeaveApplication()
                AMGlobal.openURL(url.absoluteString)
            }
        }
    }

    class func callInternalBrowser(
        _ controller: AMAdWebViewController?,
        query: [AnyHashable : Any]?
    ) {
        let urlParam = query?["url"] as? String
        let url = URL(string: urlParam ?? "")
        controller?.browserDelegate?.openInAppBrowser(with: url)
    }

    // Record Event
    class func callRecordEvent(_ controller: AMAdWebViewController?, query: [AnyHashable : Any]?) {
        let urlParam = query?["url"] as? String

        let url = URL(string: urlParam ?? "")
        let recordEventWebView = WKWebView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let recordEventDelegate = AMRecordEventDelegate()
        recordEventWebView.recordEventDelegate = recordEventDelegate
        recordEventWebView.navigationDelegate = recordEventDelegate
        recordEventWebView.isHidden = true
        if let url = url {
            recordEventWebView.load(URLRequest(url: url))
        }
        controller?.contentView?.addSubview(recordEventWebView)
    }

    // Dispatch App Event
    class func callDispatchAppEvent(_ controller: AMAdWebViewController?, query: [AnyHashable : Any]?) {
        let event = query?["event"] as? String
        let data = query?["data"] as? String

        controller?.adViewAMJAMDelegate?.adDidReceiveAppEvent(event, withData: data)
    }

    // Get Device ID
    class func callGetDeviceID(_ controller: AMAdWebViewController?, query: [AnyHashable : Any]?) {
        let cb = query?["cb"] as? String

        // send idName:idfa, id: idfa value
        let paramsList = [
            kAMKeyCaller: kAMCallGetDeviceID,
            "idname": "idfa",
            "id": AMAdvertisingIdentifier()
        ]
        AMJAMImplementation.loadResult(controller, cb: cb, paramsList: paramsList)
    }

    class func callSetMraidRefreshFrequency(_ controller: AMAdWebViewController?, query: [AnyHashable : Any]?) {
        let milliseconds = query?["ms"] as? String
        controller?.checkViewableTimeInterval = TimeInterval(Double(milliseconds ?? "") ?? 0.0 / 1000)
    }

    // Send the result back to JS
    class func loadResult(_ controller: AMAdWebViewController?, cb: String?, paramsList: [AnyHashable : Any]?) {
        var params = "cb=\(cb ?? "-1" )"
        if let list = paramsList {
            for (key, value) in list {
                let keyStr = "\(key)"
                let valueStr = "\(value)"
                params = params + ("&\(keyStr)=\(valueStr.anEncodeAsURIComponent() ?? "")")
            }
        }
        let url = "javascript:window.sdkjs.client.result(\"\(params)\")"
        controller?.fireJavaScript(url)
    }
}

class AMRecordEventDelegate: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        AMLogDebug("RecordEvent completed succesfully")
    }
}

var _recordEventDelegate: AMRecordEventDelegate?

extension WKWebView {
    var recordEventDelegate: AMRecordEventDelegate? {
        get {
            return _recordEventDelegate
        }
        set(recordEventDelegate) {
            _recordEventDelegate = recordEventDelegate
        }
    }
}
