//
//  AMWebView.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import WebKit

class AMWebView: WKWebView {
    convenience init(size: CGSize, url URL: URL?, baseURL: URL?) {
        self.init(size: size)

        guard let URL = URL  else { return }
        let req = AMBasicRequestWithURL(URL)
        let task = URLSession.shared.dataTask(with: req, completionHandler: {[weak self] data, response, error in
            if self == nil { return }

            DispatchQueue.main.async(execute: {
                guard let data = data else { return }
                guard let html = String(data: data, encoding: .utf8) else { return }
                if html.isEmpty { return }
                
                self?.loadHTMLString(html, baseURL: baseURL)
            })
        })
        task.resume()

    }

    convenience init(size: CGSize, content htmlContent: String?, baseURL: URL?) {
        self.init(size: size)
        self.loadHTMLString(htmlContent ?? "", baseURL: baseURL)
    }

    convenience init(size: CGSize, url URL: URL?) {
        self.init(size: size)
        guard let URL = URL  else { return }
        let request = URLRequest(url: URL)
        
        self.load(request)
        
    }

    func stringByEvaluatingJavaScript(from script: String?) -> String? {
        var resultString: String? = nil
        var finished = false

        evaluateJavaScript(script ?? "", completionHandler: { result, error in
            if error == nil {
                if result != nil {
                    if let result = result {
                        resultString = "\(result)"
                    }
                }
            } else {
                AMLogDebug("evaluateJavaScript error : \(error?.localizedDescription ?? "")")
            }
            finished = true
        })

        while !finished {
            RunLoop.current.run(mode: .default, before: Date.distantFuture)
        }

        return resultString
    }

    init(size: CGSize) {
        let configuration = AMWebView.setDefaultWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        let frame =  CGRect(origin: .zero, size: size)
        
        super.init(frame: frame, configuration: configuration)

        backgroundColor = UIColor.clear
        isOpaque = false

        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }


    }

    static var setDefaultWebViewConfigurationAnSdkProcessPool: WKProcessPool?

    class func setDefaultWebViewConfiguration() -> WKWebViewConfiguration {

        // `dispatch_once()` call was converted to a static variable initializer

        let configuration = WKWebViewConfiguration()

        if let setDefaultWebViewConfigurationAnSdkProcessPool = setDefaultWebViewConfigurationAnSdkProcessPool {
            configuration.processPool = setDefaultWebViewConfigurationAnSdkProcessPool
        }
        configuration.allowsInlineMediaPlayback = true

        // configuration.allowsInlineMediaPlayback = YES is not respected
        // on iPhone on WebKit versions shipped with iOS 9 and below, the
        // video always loads in full-screen.
        // See: https://bugs.webkit.org/show_bug.cgi?id=147512

        if UIDevice.current.userInterfaceIdiom == .pad {
            configuration.requiresUserActionForMediaPlayback = false
        } else {
            if ProcessInfo.processInfo.responds(to: #selector(ProcessInfo.isOperatingSystemAtLeast(_:))) && ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 10, minorVersion: 0, patchVersion: 0)) {
                configuration.requiresUserActionForMediaPlayback = false
            } else {
                configuration.requiresUserActionForMediaPlayback = true
            }
        }

        let controller = WKUserContentController()
        configuration.userContentController = controller

        let paddingJS = "document.body.style.margin='0';document.body.style.padding = '0'"

        let paddingScript = WKUserScript(source: paddingJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(paddingScript)

        if !AMSDKSettings.sharedInstance.locationEnabledForCreative {
            //The Geolocation method watchPosition() method is used to register a handler function that will be called automatically each time the position of the device changes.
            let execWatchPosition = String(format: "navigator.geolocation.watchPosition = function(success, error, options) {};")
            //The Geolocation.getCurrentPosition() method is used to get the current position of the device.
            let execCurrentPosition = String(format: "navigator.geolocation.getCurrentPosition('', function(){});")

            // Pass user denied the request for Geolocation to Creative
            // USER_DENIED_LOCATION_PERMISSION is 1 which shows, The acquisition of the geolocation information failed because the page didn't have the permission to do it.
            let execCurrentPositionDenied = String(format: "navigator.geolocation.getCurrentPosition = function(success, error){ error({ error: { code: %d } });};", AM_USER_DENIED_LOCATION_PERMISSION)



            let execWatchPositionScript = WKUserScript(
                source: execWatchPosition,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false)

            let execCurrentPositionScript = WKUserScript(
                source: execCurrentPosition,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false)
            let execCurrentPositionDeniedScript = WKUserScript(
                source: execCurrentPositionDenied,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false)
            controller.addUserScript(execCurrentPositionScript)
            controller.addUserScript(execWatchPositionScript)
            controller.addUserScript(execCurrentPositionDeniedScript)
        }
        return configuration
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

let AM_USER_DENIED_LOCATION_PERMISSION = 1
