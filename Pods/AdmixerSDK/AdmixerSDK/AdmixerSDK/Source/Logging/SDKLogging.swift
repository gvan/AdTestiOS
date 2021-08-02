//
//  SDKLogging.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
public enum AMLogLevel : Int {
    case all = 0
    case mark = 9
    case trace = 10
    case debug = 20
    case info = 30
    case warn = 40
    case error = 50
    case off = 60
    
    public static var currentLevel: AMLogLevel = .warn
}

func AMLog(_ level: AMLogLevel, _ levelString: String?, _ format: String?, args: [CustomStringConvertible] = []) {
    var newFormat: String = format ?? ""
    let isEmpty = newFormat.isEmpty
    let curLvl = AMLogLevel.currentLevel
    guard curLvl.rawValue <= level.rawValue else { return }
    
    newFormat = AMErrorString(newFormat) // returns the format string if error string not found
    newFormat = "ADMIXER \(levelString ?? "") -> \(newFormat)"
    
    var fullString = String(format: newFormat, args)
    if isEmpty {
        let argsStr = args.reduce("", {str, arg in return str.appending(" \(arg)")})
        fullString.append(argsStr)
    }
    notifyListener(fullString, level.rawValue)
    print(fullString)
}

//MARK: - Logging
let kAMLoggingNotification = "kAMLoggingNotification"
let kAMLogMessageKey = "kAMLogMessageKey"
let kAMLogMessageLevelKey = "kAMLogMessageLevelKey"

func notifyListener(_ message: String?, _ messageLevel: Int) {
    let msg = message ?? ""
    AMPostNotifications(
        kAMLoggingNotification,
        nil,
        [
            kAMLogMessageKey: msg,
            kAMLogMessageLevelKey: NSNumber(value: messageLevel)
        ]
    )
}

public func AMLogMark(_ args:  String...){ AMLog(.trace, "MARK", "", args: args)}
public func AMLogMarkMessage(_ args:  String...){ AMLog(.trace, "MARK", "", args: args)}
public func AMLogTrace(_ args:  String...){ AMLog(.trace, "TRACE", "", args: args)}
public func AMLogDebug(_ args:  String...){ AMLog(.debug, "DEBUG", "", args: args)}
public func AMLogInfo(_ args:  String...){ AMLog(.info,  "INFO", "", args: args)}
public func AMLogWarn(_ args:  CustomStringConvertible...){ AMLog(.warn,  "WARNING", "", args: args)}
public func AMLogError(_ args:  String...){ AMLog(.error, "ERROR", "", args: args) }
