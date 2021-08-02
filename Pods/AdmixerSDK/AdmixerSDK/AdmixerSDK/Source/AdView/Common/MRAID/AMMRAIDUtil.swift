//
//  AMMRAIDUtil.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import AVKit
import MessageUI
import UIKit

enum AMMRAIDOrientation : Int {
    case portrait
    case landscape
    case none
}

enum AMMRAIDCustomClosePosition : Int {
    case unknown
    case topLeft
    case topCenter
    case topRight
    case center
    case bottomLeft
    case bottomCenter
    case bottomRight
}

enum AMMRAIDState : Int {
    case unknown
    case loading
    case `default`
    case expanded
    case hidden
    case resized
}

enum AMMRAIDAction : Int {
    case unknown
    case expand
    case close
    case resize
    case createCalendarEvent
    case playVideo
    case storePicture
    case setOrientationProperties
    case setUseCustomClose
    case openURI
    case enable
}

class AMMRAIDUtil: NSObject {
    class func supportsSMS() -> Bool {
        return MFMessageComposeViewController.canSendText()
    }

    class func supportsTel() -> Bool {
        if let url1 = URL(string: "tel://") {
            return UIApplication.shared.canOpenURL(url1)
        }
        return false
    }

    class func supportsCalendar() -> Bool {
        return false
    }

    class func supportsInlineVideo() -> Bool {
        return true
    }

    class func supportsStorePicture() -> Bool {
        return false
    }

    class func screenSize() -> CGSize {
        let orientationIsPortrait = UIApplication.shared.statusBarOrientation.isPortrait
        let screenSize = AMPortraitScreenBounds().size
        let orientedWidth = Int(orientationIsPortrait ? screenSize.width : screenSize.height)
        let orientedHeight = Int(orientationIsPortrait ? screenSize.height : screenSize.width)
        return CGSize(width: CGFloat(orientedWidth), height: CGFloat(orientedHeight))
    }

    class func maxSizeSafeArea() -> CGSize {
        let orientationIsPortrait = UIApplication.shared.statusBarOrientation.isPortrait
        let screenSize = AMPortraitScreenBoundsApplyingSafeAreaInsets().size
        let orientedWidth = Int(orientationIsPortrait ? screenSize.width : screenSize.height)
        let orientedHeight = Int(orientationIsPortrait ? screenSize.height : screenSize.width)
        return CGSize(width: CGFloat(orientedWidth), height: CGFloat(orientedHeight))
    }

    class func playVideo(
        withUri uri: String?,
        fromRootViewController rootViewController: UIViewController?,
        withCompletionTarget target: Any?,
        completionSelector selector: Selector
    ) {
        let url = URL(string: uri ?? "")

        let moviePlayerViewController = AVPlayerViewController()
        if let url = url {
            moviePlayerViewController.player = AVPlayer(url: url)
        }
        moviePlayerViewController.modalPresentationStyle = .overFullScreen
        moviePlayerViewController.view.frame = rootViewController?.view.frame ?? CGRect.zero
        rootViewController?.present(moviePlayerViewController, animated: true)
        moviePlayerViewController.player?.play()

        if let target = target {
            NotificationCenter.default.addObserver(
                target,
                selector: selector,
                name: .AVPlayerItemDidPlayToEndTime,
                object: moviePlayerViewController.player)
        }
    }

    class func storePicture(withUri uri: String?, withCompletionTarget target: Any?, completionSelector selector: Selector) {
        guard let completionTarget = target as? AMStorePictureCallbackProtocol else { return }
        let usrInfo = [NSLocalizedDescriptionKey: "storePicture not supported"]
        let err = NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: usrInfo)
        completionTarget.image(nil, didFinishSavingWithError: err, contextInfo: nil)
    }

    class func action(forCommand command: String?) -> AMMRAIDAction {
        if (command == "expand") {
            return .expand
        } else if (command == "close") {
            return .close
        } else if (command == "resize") {
            return .resize
        } else if (command == "createCalendarEvent") {
            return .createCalendarEvent
        } else if (command == "playVideo") {
            return .playVideo
        } else if (command == "storePicture") {
            return .storePicture
        } else if (command == "setOrientationProperties") {
            return .setOrientationProperties
        } else if (command == "setUseCustomClose") {
            return .setUseCustomClose
        } else if (command == "open") {
            return .openURI
        } else if (command == "enable") {
            return .enable
        }
        return .unknown
    }

    class func customClosePosition(fromCustomClosePositionString customClosePositionString: String?) -> AMMRAIDCustomClosePosition {
        if (customClosePositionString == "top-left") {
            return .topLeft
        } else if (customClosePositionString == "top-center") {
            return .topCenter
        } else if (customClosePositionString == "top-right") {
            return .topRight
        } else if (customClosePositionString == "center") {
            return .center
        } else if (customClosePositionString == "bottom-left") {
            return .bottomLeft
        } else if (customClosePositionString == "bottom-center") {
            return .bottomCenter
        } else if (customClosePositionString == "bottom-right") {
            return .bottomRight
        }
        return .unknown
    }

    class func orientation(fromForceOrientationString orientationString: String?) -> AMMRAIDOrientation {
        if (orientationString == "portrait") {
            return .portrait
        } else if (orientationString == "landscape") {
            return .landscape
        }
        return .none
    }

    class func state(from stateString: String?) -> AMMRAIDState {
        if (stateString == "loading") {
            return .loading
        } else if (stateString == "default") {
            return .`default`
        } else if (stateString == "expanded") {
            return .expanded
        } else if (stateString == "hidden") {
            return .hidden
        } else if (stateString == "resized") {
            return .resized
        }
        return .unknown
    }

    class func stateString(from state: AMMRAIDState) -> String? {
        switch state {
            case .loading:
                return "loading"
            case .`default`:
                return "default"
            case .expanded:
                return "expanded"
            case .hidden:
                return "hidden"
            case .resized:
                return "resized"
            default:
                return nil
        }
    }
}

@objc protocol AMStorePictureCallbackProtocol: AnyObject {
    func image(_ image: UIImage?, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?)
}
