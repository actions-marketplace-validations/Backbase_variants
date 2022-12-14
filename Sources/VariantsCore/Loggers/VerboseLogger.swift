//
//  Variants
//
//  Copyright (c) Backbase B.V. - https://www.backbase.com
//  Created by Arthur Alves
//

import Foundation
import ArgumentParser

public enum ShellColor: String {
    case blue = "\u{001B}[0;34m"
    case red = "\u{001B}[0;31m"
    case green = "\u{001B}[0;32m"
    case cyan = "\u{001B}[0;36m"
    case purple = "\u{001B}[0;35m"
    case yellow = "\u{001B}[0;33m"
    case ios = "\u{001B}[0;49;36m"
    case android = "\u{001B}[0;49;33m"
    case neutral = "\u{001B}[0;0m"
    
    func bold() -> String {
        return self.rawValue.replacingOccurrences(of: "[0", with: "[1")
    }
}

public enum LogLevel: String {
    case info = "INFO  "
    case warning = "WARN  "
    case verbose = "DEBUG "
    case error = "ERROR "
    case none = "     "
}

public protocol VerboseLogger {
    var verbose: Bool { get }
    var showTimestamp: Bool { get }
    func log(_ data: LogData)
}

extension VerboseLogger {
    public func log(_ data: LogData) {
        if data.logLevel != .verbose || verbose {
            let logString = createLog(data)
            var outputStream = StandardOutputStream(fileHandler: .standardError)
            Swift.print(logString, to: &outputStream)
        }
    }
    
    func createLog(_ data: LogData) -> String {
        if data.logLevel == .verbose {
            guard verbose else { return ""}
        }
        let indentation = String(repeating: "   ", count: data.indentationLevel)
        var command = ""
        var arguments: [String] = []
        
        if showTimestamp {
            arguments.append(contentsOf: [
                "\(data.logLevel.rawValue)",
                "[\(data.date.logTimestamp())]: ▸ "
            ])
        }
        
        arguments.append(contentsOf: [
            "\(indentation)",
            "\(data.color.bold())\(data.prefix)",
            "\(data.color.rawValue)\(data.item)\(ShellColor.neutral.rawValue)"
        ])
        
        arguments.forEach { command.append($0) }
        return command
    }
}
